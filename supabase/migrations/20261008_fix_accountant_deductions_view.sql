-- Migration: 20261008_fix_accountant_deductions_view.sql
-- Correct v_accountant_deductions so running costs (fuel, repairs, rego, insurance)
-- are scaled by the vehicle's logbook percentage instead of 100%.

DROP VIEW IF EXISTS public.v_accountant_deductions CASCADE;

CREATE VIEW public.v_accountant_deductions
WITH (security_invoker = true)
AS
WITH vehicle_logbook_rates AS (
    SELECT 
        v.id AS vehicle_id,
        CASE 
            WHEN COALESCE(SUM(t.distance_km), 0) > 0 THEN
                ROUND(
                    (SUM(CASE WHEN t.classification = 'business' THEN t.distance_km ELSE 0 END)::numeric / 
                     SUM(t.distance_km)::numeric) * 100.0,
                    2
                )
            ELSE 0.00
        END AS logbook_percentage
    FROM public.vehicles v
    LEFT JOIN public.trips t 
        ON t.vehicle_id = v.id 
        AND t.deleted_at IS NULL
    WHERE v.deleted_at IS NULL
    GROUP BY v.id
)
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
        ELSE round(e.amount * (COALESCE(vlr.logbook_percentage, 0.00) / 100.0), 2) 
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
LEFT JOIN vehicle_logbook_rates vlr ON vlr.vehicle_id = v.id
WHERE e.deleted_at IS NULL AND v.deleted_at IS NULL;

COMMENT ON VIEW public.v_accountant_deductions IS 'Accountant two-basket deductions view scaling running costs by logbook business percentage under security_invoker = true';
