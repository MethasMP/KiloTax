-- ==============================================================================
-- KiloTax Database Migration: Trip Job & Client Reference Linking
-- Adds job_reference column to trips table for ATO audit evidence linking.
-- ==============================================================================

ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS job_reference text;

CREATE INDEX IF NOT EXISTS idx_trips_job_reference ON public.trips(job_reference);

COMMENT ON COLUMN public.trips.job_reference IS 'Optional job, project, or client billing reference for audit cross-verification (ITAA 1997 TR 95/34)';
