CREATE TABLE IF NOT EXISTS public.job_sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    client_name TEXT NOT NULL,
    project_code TEXT,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters DOUBLE PRECISION NOT NULL DEFAULT 150.0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Constraints
    CONSTRAINT chk_job_site_lat CHECK (latitude BETWEEN -90.0 AND 90.0),
    CONSTRAINT chk_job_site_lng CHECK (longitude BETWEEN -180.0 AND 180.0),
    CONSTRAINT chk_job_site_radius CHECK (radius_meters >= 10.0 AND radius_meters <= 5000.0)
);

CREATE INDEX IF NOT EXISTS idx_job_sites_user ON public.job_sites (user_id);
CREATE INDEX IF NOT EXISTS idx_job_sites_coords ON public.job_sites (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_job_sites_project ON public.job_sites (user_id, project_code);


ALTER TABLE public.job_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_sites FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "job_sites_select_own" ON public.job_sites;
CREATE POLICY "job_sites_select_own" ON public.job_sites
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "job_sites_insert_own" ON public.job_sites;
CREATE POLICY "job_sites_insert_own" ON public.job_sites
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "job_sites_update_own" ON public.job_sites;
CREATE POLICY "job_sites_update_own" ON public.job_sites
    FOR UPDATE TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "job_sites_delete_own" ON public.job_sites;
CREATE POLICY "job_sites_delete_own" ON public.job_sites
    FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));


GRANT SELECT, INSERT, UPDATE, DELETE ON public.job_sites TO authenticated;
REVOKE ALL ON public.job_sites FROM anon;
-- Evidence metadata is additive; existing classifications are not promoted to confirmed.
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS job_id text;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS job_reference text;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS review jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS job_id text;
ALTER TABLE public.job_sites ADD COLUMN IF NOT EXISTS tracking_enabled boolean NOT NULL DEFAULT true;

ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_classification_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_classification_check CHECK (classification IN ('business', 'personal', 'unclassified'));
ALTER TABLE public.trips ADD CONSTRAINT trips_review_object CHECK (jsonb_typeof(review) = 'object');

CREATE OR REPLACE FUNCTION public.trip_business_km(distance numeric, classification text, review jsonb)
RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
 SELECT CASE WHEN classification <> 'business' THEN 0::numeric
 WHEN jsonb_typeof(review->'businessKm') = 'number'
 THEN greatest(0::numeric, least(distance, (review->>'businessKm')::numeric))
 ELSE distance END;
$$;
CREATE OR REPLACE VIEW public.v_accountant_deductions WITH (security_invoker = true) AS
WITH effective_expenses AS (
 SELECT e.id, e.vehicle_id, e.date, e.supplier,
        CASE WHEN jsonb_array_length(e.allocations) > 0 THEN 100.0 ELSE e.business_percentage END AS business_percentage,
        e.receipt_storage_path, e.linked_trip_id, e.client_dedup_id, e.deleted_at,
        coalesce(line.value->>'category', e.category) AS category,
        (CASE WHEN line.value IS NULL THEN e.amount ELSE (line.value->>'amount')::numeric END)::numeric(10,2) AS amount
 FROM public.expenses e
 LEFT JOIN LATERAL jsonb_array_elements(e.allocations) line(value) ON true
 WHERE NOT e.is_vault_only AND e.deleted_at IS NULL
   AND (line.value IS NULL OR line.value->>'purpose' = 'work')
), vehicle_logbook_rates AS (
 SELECT v.id AS vehicle_id, public.get_financial_year(t.date) AS financial_year,
   CASE WHEN coalesce(sum(t.distance_km), 0) > 0
        THEN round(sum(public.trip_business_km(t.distance_km, t.classification, t.review)) / sum(t.distance_km) * 100, 2)
        ELSE 0::numeric END AS logbook_percentage
 FROM public.vehicles v LEFT JOIN public.trips t ON t.vehicle_id = v.id AND t.deleted_at IS NULL
 WHERE v.deleted_at IS NULL GROUP BY v.id, public.get_financial_year(t.date)
)
SELECT e.id AS expense_id, e.vehicle_id, v.user_id, v.rego_plate,
 v.display_name AS vehicle_name, v.tax_method, e.date,
 public.get_financial_year(e.date) AS financial_year, e.category, e.supplier, e.amount,
 coalesce(e.business_percentage, 100.0) AS business_percentage,
 e.receipt_storage_path, e.linked_trip_id, e.client_dedup_id, e.deleted_at,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_work_deduction' ELSE 'car_running_cost' END AS claim_type,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_percent' ELSE 'logbook_apportioned' END AS deduction_method,
 e.category IN ('toolsMaterials','tollsParking','otherBusiness') AS is_direct_claim,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN round(e.amount * coalesce(e.business_percentage, 100.0) / 100, 2)
      WHEN v.tax_method = 'centsPerKm' THEN 0.00
      ELSE round(e.amount * coalesce(vlr.logbook_percentage, 0) / 100, 2) END AS safe_deductible_amount,
 CASE WHEN v.tax_method = 'centsPerKm' AND e.category NOT IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'substantiation_only'
      WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_claim'
      ELSE 'logbook_claimable' END AS ato_status
FROM effective_expenses e JOIN public.vehicles v ON v.id = e.vehicle_id
LEFT JOIN vehicle_logbook_rates vlr ON vlr.vehicle_id = v.id AND vlr.financial_year = public.get_financial_year(e.date)
WHERE v.deleted_at IS NULL;
NOTIFY pgrst, 'reload schema';

CREATE OR REPLACE VIEW public.v_cpk_statutory_trips WITH (security_invoker = true) AS
SELECT t.id AS trip_id, t.vehicle_id, v.user_id, v.rego_plate, t.date,
 public.trip_business_km(t.distance_km, t.classification, t.review) AS distance_km,
 t.purpose,
 CASE WHEN public.trip_business_km(t.distance_km, t.classification, t.review) < t.distance_km THEN '[Mixed journey]' ELSE t.origin_address END AS origin_address,
 CASE WHEN public.trip_business_km(t.distance_km, t.classification, t.review) < t.distance_km THEN '[Mixed journey]' ELSE t.destination_address END AS destination_address,
 t.evidence_source, t.client_dedup_id, t.deleted_at
FROM public.trips t JOIN public.vehicles v ON v.id = t.vehicle_id
WHERE t.tax_method = 'centsPerKm' AND t.classification = 'business' AND t.deleted_at IS NULL;
NOTIFY pgrst, 'reload schema';

-- The app records these sources truthfully; do not reject captured trips on sync.
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_evidence_source_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_evidence_source_check CHECK (evidence_source IN (
 'auto_telemetry','bluetooth_auto','manual_retroactive','gps_recorded',
 'rescued_crash_continuity','native_bluetooth_auto','manual_gap_resolution',
 'user_confirmed_auto_gap','auto_reconciled_odometer_gap'
)) NOT VALID;
ALTER TABLE public.trips ADD CONSTRAINT trips_review_distance_check CHECK (
 CASE WHEN review ? 'businessKm' THEN
  CASE WHEN jsonb_typeof(review->'businessKm') = 'number'
       THEN (review->>'businessKm')::numeric BETWEEN 0 AND distance_km
       ELSE false END
 ELSE true END
);
