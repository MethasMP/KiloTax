-- ==============================================================================
-- KiloTax Database Migration: Security Invoker Views & Safe Search Path
-- Hardens PostgreSQL database against security definer privilege escalation
-- and enforces RLS context propagation by setting (security_invoker = true) on views.
-- References: Supabase Database Security Advisors & PostgreSQL Best Practices
-- ==============================================================================

-- 1. Drop and Recreate v_cpk_statutory_trips WITH (security_invoker = true)
DROP VIEW IF EXISTS public.v_cpk_statutory_trips CASCADE;

CREATE VIEW public.v_cpk_statutory_trips
WITH (security_invoker = true)
AS
SELECT 
    t.id AS trip_id,
    t.vehicle_id,
    v.user_id,
    v.rego_plate,
    t.date,
    t.distance_km,
    t.purpose,
    t.origin_address,
    t.destination_address,
    t.evidence_source,
    t.client_dedup_id,
    t.deleted_at
FROM public.trips t
JOIN public.vehicles v ON t.vehicle_id = v.id
WHERE t.tax_method = 'centsPerKm' 
  AND t.classification = 'business' 
  AND t.deleted_at IS NULL;

COMMENT ON VIEW public.v_cpk_statutory_trips IS 'Statutory CPK audit log view executing under querying user RLS context (security_invoker = true)';

-- 2. Drop and Recreate v_accountant_deductions WITH (security_invoker = true)
DROP VIEW IF EXISTS public.v_accountant_deductions CASCADE;

CREATE VIEW public.v_accountant_deductions
WITH (security_invoker = true)
AS
SELECT 
    e.id AS expense_id,
    e.vehicle_id,
    v.user_id,
    v.rego_plate,
    v.display_name AS vehicle_name,
    v.tax_method,
    e.date,
    get_financial_year(e.date) AS financial_year,
    e.category,
    e.supplier,
    e.amount,
    COALESCE(e.business_percentage, 100.0) AS business_percentage,
    e.receipt_storage_path,
    e.linked_trip_id,
    e.client_dedup_id,
    e.deleted_at,
    -- Intention-revealing claim classification (Clean Code N1, snake_case)
    CASE 
        WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
            THEN 'direct_work_deduction'::text
        ELSE 'car_running_cost'::text
    END AS claim_type,
    CASE 
        WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
            THEN 'direct_100_percent'::text
        ELSE 'logbook_apportioned'::text
    END AS deduction_method,
    (e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text])) AS is_direct_claim,
    CASE 
        WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
            THEN round(e.amount * (COALESCE(e.business_percentage, 100.0) / 100.0), 2)
        WHEN v.tax_method = 'centsPerKm'::text AND (e.category = ANY (ARRAY['fuel'::text, 'maintenanceTyres'::text, 'rego'::text, 'insurance'::text, 'interest'::text])) 
            THEN 0.00 
        ELSE round(e.amount * (COALESCE(e.business_percentage, 100.0) / 100.0), 2) 
    END AS safe_deductible_amount,
    CASE 
        WHEN v.tax_method = 'centsPerKm'::text AND (e.category = ANY (ARRAY['fuel'::text, 'maintenanceTyres'::text, 'rego'::text, 'insurance'::text, 'interest'::text])) 
            THEN 'substantiation_only'::text 
        WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text])
            THEN 'direct_100_claim'::text
        ELSE 'logbook_claimable'::text 
    END AS ato_status 
FROM public.expenses e 
JOIN public.vehicles v ON e.vehicle_id = v.id 
WHERE e.deleted_at IS NULL AND v.deleted_at IS NULL;

COMMENT ON VIEW public.v_accountant_deductions IS 'Accountant two-basket deductions view executing under querying user RLS context (security_invoker = true)';

-- 3. Hardened check_ato_rules_freshness function with explicit search_path
CREATE OR REPLACE FUNCTION public.check_ato_rules_freshness(check_date timestamptz DEFAULT now())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_month integer;
    v_year integer;
    v_target_start_year integer;
    v_found_rule record;
    v_result jsonb;
BEGIN
    v_month := EXTRACT(MONTH FROM check_date);
    v_year := EXTRACT(YEAR FROM check_date);
    
    -- In Australia, FY starts 1 July
    IF v_month >= 7 THEN
        v_target_start_year := v_year;
    ELSE
        v_target_start_year := v_year - 1;
    END IF;

    -- Lookup rule for active target year
    SELECT * INTO v_found_rule
    FROM public.ato_tax_rules
    WHERE start_year = v_target_start_year;

    IF FOUND THEN
        v_result := jsonb_build_object(
            'status', 'healthy',
            'financial_year', v_found_rule.financial_year,
            'cents_per_km_rate', v_found_rule.cents_per_km_rate,
            'is_stale', false,
            'target_start_year', v_target_start_year,
            'checked_at', now()
        );
    ELSE
        -- CRITICAL: Post-1-July rollover missing verified rate -> Triggers Developer Alert
        v_result := jsonb_build_object(
            'status', 'developer_alert_required',
            'error', 'Financial year rollover occurred but no verified rate exists for start_year ' || v_target_start_year,
            'is_stale', true,
            'target_start_year', v_target_start_year,
            'checked_at', now()
        );
    END IF;

    RETURN v_result;
END;
$$;
