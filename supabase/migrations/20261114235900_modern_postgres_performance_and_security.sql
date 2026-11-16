-- ==============================================================================
-- KiloTax Migration: Modern Postgres 15+ Performance & Security Optimization
-- Standards Applied:
--   - supabase-postgres-best-practices/references/advanced-jsonb-indexing.md
--   - supabase-postgres-best-practices/references/security-rls-performance.md
--   - supabase-postgres-best-practices/references/query-covering-indexes.md
-- File: 20261114235900_modern_postgres_performance_and_security.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ADVANCED JSONB GIN INDEXING (High Performance Containment & Filtering)
-- ------------------------------------------------------------------------------
-- jsonb_path_ops is 2-3x smaller in index footprint and orders of magnitude faster
-- for containment operators (@>, ?, etc.) when querying split expense allocations and audit.
CREATE INDEX IF NOT EXISTS idx_expenses_allocations_path_ops
ON public.expenses USING GIN (allocations jsonb_path_ops)
WHERE NOT is_vault_only AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_trips_review_gin
ON public.trips USING GIN (review jsonb_path_ops)
WHERE deleted_at IS NULL;

-- ------------------------------------------------------------------------------
-- 2. COVERING & COMPOSITE INDEXES FOR ZERO-DISK INDEX-ONLY SCANS
-- ------------------------------------------------------------------------------
-- Eliminates table heap lookups when calculating accountant deductions and tax basis
CREATE INDEX IF NOT EXISTS idx_trips_financial_calc_cov
ON public.trips (vehicle_id, date)
INCLUDE (distance_km, classification, tax_method, job_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_financial_calc_cov
ON public.expenses (vehicle_id, date)
INCLUDE (amount, category, business_percentage, gst_amount)
WHERE NOT is_vault_only AND deleted_at IS NULL;

-- ------------------------------------------------------------------------------
-- 3. REFACTOR v_accountant_deductions WITH MODERN JSON PATH / FILTER CLAUSES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_accountant_deductions WITH (security_invoker = true) AS
WITH effective_expenses AS (
    SELECT 
        e.id, 
        e.vehicle_id, 
        e.date, 
        e.supplier,
        CASE 
            WHEN jsonb_array_length(e.allocations) > 0 THEN 100.0 
            ELSE e.business_percentage 
        END AS business_percentage,
        e.receipt_storage_path, 
        e.linked_trip_id, 
        e.client_dedup_id, 
        e.deleted_at,
        coalesce(line.value->>'category', e.category) AS category,
        (CASE WHEN line.value IS NULL THEN e.amount ELSE (line.value->>'amount')::numeric END)::numeric(10,2) AS amount
    FROM public.expenses e
    LEFT JOIN LATERAL jsonb_array_elements(e.allocations) line(value) ON true
    WHERE NOT e.is_vault_only AND e.deleted_at IS NULL
      AND (line.value IS NULL OR line.value->>'purpose' = 'work')
), 
vehicle_logbook_rates AS (
    SELECT 
        v.id AS vehicle_id, 
        public.get_financial_year(t.date) AS financial_year,
        CASE 
            WHEN coalesce(sum(t.distance_km), 0) > 0 THEN
                round(
                    sum(public.trip_business_km(t.distance_km, t.classification, t.review)) / sum(t.distance_km) * 100, 
                    2
                )
            ELSE 0::numeric 
        END AS logbook_percentage
    FROM public.vehicles v 
    LEFT JOIN public.trips t ON t.vehicle_id = v.id AND t.deleted_at IS NULL
    WHERE v.deleted_at IS NULL 
    GROUP BY v.id, public.get_financial_year(t.date)
)
SELECT 
    e.id AS expense_id, 
    e.vehicle_id, 
    v.user_id, 
    v.rego_plate,
    v.display_name AS vehicle_name, 
    v.tax_method, 
    e.date,
    public.get_financial_year(e.date) AS financial_year, 
    e.category, 
    e.supplier, 
    e.amount,
    coalesce(e.business_percentage, 100.0) AS business_percentage,
    e.receipt_storage_path, 
    e.linked_trip_id, 
    e.client_dedup_id, 
    e.deleted_at,
    CASE 
        WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_work_deduction' 
        ELSE 'car_running_cost' 
    END AS claim_type,
    CASE 
        WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_percent' 
        ELSE 'logbook_apportioned' 
    END AS deduction_method,
    e.category IN ('toolsMaterials','tollsParking','otherBusiness') AS is_direct_claim,
    CASE 
        WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN round(e.amount * coalesce(e.business_percentage, 100.0) / 100, 2)
        WHEN v.tax_method = 'centsPerKm' THEN 0.00
        ELSE round(e.amount * coalesce(vlr.logbook_percentage, 0) / 100, 2) 
    END AS safe_deductible_amount,
    CASE 
        WHEN v.tax_method = 'centsPerKm' AND e.category NOT IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'substantiation_only'
        WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_claim'
        ELSE 'logbook_claimable' 
    END AS ato_status
FROM effective_expenses e 
JOIN public.vehicles v ON v.id = e.vehicle_id
LEFT JOIN vehicle_logbook_rates vlr ON vlr.vehicle_id = v.id AND vlr.financial_year = public.get_financial_year(e.date)
WHERE v.deleted_at IS NULL;

-- ------------------------------------------------------------------------------
-- 4. HARDEN LEGACY RLS POLICIES (Enforce O(1) SubPlan Cached User ID)
-- ------------------------------------------------------------------------------
-- Replaces any lingering per-row auth.uid() function evaluations on core tables.
DROP POLICY IF EXISTS "Users can manage their own vehicles" ON public.vehicles;
CREATE POLICY "Users can manage their own vehicles"
ON public.vehicles
FOR ALL
TO authenticated
USING (
    user_id = (SELECT auth.uid())
)
WITH CHECK (
    user_id = (SELECT auth.uid())
);

DROP POLICY IF EXISTS "Users can manage their own trips" ON public.trips;
CREATE POLICY "Users can manage their own trips"
ON public.trips
FOR ALL
TO authenticated
USING (
    user_id = (SELECT auth.uid())
)
WITH CHECK (
    user_id = (SELECT auth.uid())
);

DROP POLICY IF EXISTS "Users can manage their own expenses" ON public.expenses;
CREATE POLICY "Users can manage their own expenses"
ON public.expenses
FOR ALL
TO authenticated
USING (
    user_id = (SELECT auth.uid())
)
WITH CHECK (
    user_id = (SELECT auth.uid())
);

-- Notify PostgREST to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
