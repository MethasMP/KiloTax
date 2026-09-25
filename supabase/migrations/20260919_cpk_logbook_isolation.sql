-- ==============================================================================
-- KiloTax Database Migration: CPK & Logbook Isolation & Telemetry Evidence Source
-- Adds explicit tax_method and evidence_source columns to trips table.
-- Ensures zero cross-contamination between CPK (Subdiv 28-C) & Logbook (Subdiv 28-F).
-- ==============================================================================

-- 1. Add tax_method and evidence_source to public.trips
ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS tax_method text NOT NULL DEFAULT 'centsPerKm' 
CHECK (tax_method IN ('centsPerKm', 'logbook'));

ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS evidence_source text NOT NULL DEFAULT 'auto_telemetry' 
CHECK (evidence_source IN ('auto_telemetry', 'bluetooth_auto', 'manual_retroactive'));

-- 2. Indexes for accelerated tax reporting & audit extraction
CREATE INDEX IF NOT EXISTS idx_trips_tax_method ON public.trips(tax_method);
CREATE INDEX IF NOT EXISTS idx_trips_evidence_source ON public.trips(evidence_source);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle_tax_method ON public.trips(vehicle_id, tax_method);

-- 3. Update or create view for CPK statutory audit logs (Excludes non-CPK trips)
CREATE OR REPLACE VIEW public.v_cpk_statutory_trips AS
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

-- 4. Comment on columns for accountant audit trail
COMMENT ON COLUMN public.trips.tax_method IS 'Tax calculation regime (centsPerKm per ITAA 1997 s.28-25 vs logbook per s.28-90)';
COMMENT ON COLUMN public.trips.evidence_source IS 'Origin of trip telemetry: auto_telemetry (background GPS), bluetooth_auto, or manual_retroactive';
