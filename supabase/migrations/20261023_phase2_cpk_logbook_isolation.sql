-- ==============================================================================
-- KiloTax Database Migration: Phase 2 - CPK & Logbook Isolation Engine (ITAA 1997 Compliant)
-- Migration: 20261023_phase2_cpk_logbook_isolation.sql
--
-- 1. Partial Index for CPK Trips (5,000 km statutory cap extraction):
--    Accelerates filtering of active business CPK trips ordered by date DESC.
-- 2. Partial Index for Logbook Calculation:
--    Covering/accelerating aggregation of business vs total distance per vehicle.
-- 3. Recreates `public.v_cpk_statutory_trips` with security_invoker = true.
-- 4. Recreates `public.v_accountant_deductions` with security_invoker = true:
--    - Enforces strict isolation: CPK vehicle running costs (fuel, repairs, rego,
--      insurance, interest) have safe_deductible_amount = 0.00 & ato_status = 'substantiation_only'.
--    - Logbook vehicle running costs scaled strictly by actual logbook_percentage.
--    - Direct work deductions (tools, tolls, parking) 100% claimable scaled by business_percentage.
-- ==============================================================================

-- 1. Partial Index: Fast retrieval of CPK trips for statutory cap monitoring
CREATE INDEX IF NOT EXISTS idx_trips_cpk_statutory 
ON public.trips(vehicle_id, date DESC) 
WHERE tax_method = 'centsPerKm' 
  AND classification = 'business' 
  AND deleted_at IS NULL;

-- 2. Partial Index: Accelerated aggregation for Logbook Business % calculation
CREATE INDEX IF NOT EXISTS idx_trips_logbook_calc 
ON public.trips(vehicle_id, distance_km, classification) 
WHERE deleted_at IS NULL;

-- 3. Recreate View: public.v_cpk_statutory_trips WITH (security_invoker = true)
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

COMMENT ON VIEW public.v_cpk_statutory_trips IS 'Statutory Cents-per-KM business trips audit view (security_invoker = true, strictly isolated from logbook method)';

-- 4. Recreate View: public.v_accountant_deductions WITH (security_invoker = true)
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

COMMENT ON VIEW public.v_accountant_deductions IS 'Accountant two-basket deductions view scaling running costs by logbook business percentage with strict CPK zero-deduction isolation under security_invoker = true';
