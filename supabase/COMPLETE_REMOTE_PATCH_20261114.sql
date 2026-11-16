-- ==============================================================================
-- KILOTAX: COMBINED CLOUD SYNC PATCH (November 2026)
-- Run this in Supabase Dashboard -> SQL Editor -> Run
-- ==============================================================================

-- ==============================================================================
-- KiloTax Migration: Evidence Graph Core (JobSite POI & Cryptographic Vault)
-- Statutory Reference: ATO ITAA 1997 s 900-165, TR 97/11 & TR 95/34
-- File: 20261108_evidence_graph_contract.sql
-- ==============================================================================

-- 1. JOBSITE POI ENTITY TABLE
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

-- 2. SECURE EVIDENCE AUDIT VAULT TABLE (HARDENED 5-YEAR COMPLIANCE)
CREATE TABLE IF NOT EXISTS public.audit_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    evidence_type TEXT NOT NULL, -- 'odometer_start', 'odometer_end', 'heavy_tools_setup', 'expense_receipt', 'job_arrival_proof'
    entity_id TEXT,             -- Trip ID, Expense ID, or JobSite ID
    storage_path TEXT NOT NULL,
    image_sha256 TEXT NOT NULL, -- 64-char Hex SHA-256
    file_size_bytes BIGINT NOT NULL,
    mime_type TEXT NOT NULL DEFAULT 'image/webp',
    captured_at TIMESTAMPTZ NOT NULL,
    capture_source TEXT NOT NULL DEFAULT 'camera_live', -- 'camera_live', 'upload_manual', 'fleet_telemetry'
    watermark_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    statutory_retention_until TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '5 years'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_audit_evidence_sha256 CHECK (length(image_sha256) = 64)
);

-- Add statutory_retention_until if table already existed without it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_evidence' AND column_name = 'statutory_retention_until'
    ) THEN
        ALTER TABLE public.audit_evidence 
        ADD COLUMN statutory_retention_until TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '5 years');
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS unq_audit_evidence_user_sha256
ON public.audit_evidence (user_id, image_sha256);

CREATE INDEX IF NOT EXISTS idx_audit_evidence_user_id ON public.audit_evidence (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_evidence_entity ON public.audit_evidence (user_id, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_evidence_type ON public.audit_evidence (evidence_type);

-- 3. EVIDENCE GRAPH INTERMEDIATE LINKING TABLE (Edges)
CREATE TABLE IF NOT EXISTS public.trip_evidence_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    job_site_id UUID REFERENCES public.job_sites(id) ON DELETE SET NULL,
    expense_id UUID REFERENCES public.expenses(id) ON DELETE CASCADE,
    evidence_id UUID REFERENCES public.audit_evidence(id) ON DELETE RESTRICT,
    confidence_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    association_method TEXT NOT NULL, -- 'manual_user', 'spatial_geofence', 'temporal_proximity', 'ocr_abn_match'
    linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_confidence_score CHECK (confidence_score >= 0.0 AND confidence_score <= 1.0),
    CONSTRAINT unq_trip_evidence_link UNIQUE (trip_id, expense_id, evidence_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_evidence_trip ON public.trip_evidence_links (trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_evidence_job ON public.trip_evidence_links (job_site_id);
CREATE INDEX IF NOT EXISTS idx_trip_evidence_expense ON public.trip_evidence_links (expense_id);
CREATE INDEX IF NOT EXISTS idx_trip_evidence_evidence ON public.trip_evidence_links (evidence_id);

-- 4. ROW LEVEL SECURITY (RLS) & PRIVILEGE HARDENING
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

ALTER TABLE public.trip_evidence_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_evidence_links FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trip_evidence_select_own" ON public.trip_evidence_links;
CREATE POLICY "trip_evidence_select_own" ON public.trip_evidence_links
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "trip_evidence_insert_own" ON public.trip_evidence_links;
CREATE POLICY "trip_evidence_insert_own" ON public.trip_evidence_links
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "trip_evidence_update_own" ON public.trip_evidence_links;
CREATE POLICY "trip_evidence_update_own" ON public.trip_evidence_links
    FOR UPDATE TO authenticated 
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "trip_evidence_delete_own" ON public.trip_evidence_links;
CREATE POLICY "trip_evidence_delete_own" ON public.trip_evidence_links
    FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

-- 5. TAMPER-PROOF TRIGGER FOR AUDIT EVIDENCE (ITAA 1997 s 900-165)
CREATE OR REPLACE FUNCTION public.enforce_audit_evidence_tamper_proof()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'Tamper-Proof Audit Vault: % operations are prohibited on audit_evidence (ATO ITAA 1997 s 900-165).', TG_OP
        USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_evidence_tamper_proof ON public.audit_evidence;
CREATE TRIGGER trg_audit_evidence_tamper_proof
BEFORE UPDATE OR DELETE ON public.audit_evidence
FOR EACH ROW
EXECUTE FUNCTION public.enforce_audit_evidence_tamper_proof();


-- ==============================================================================
-- KiloTax Migration: Statutory Annual Odometers & Logbook Periods Synchronization Contract
-- Statutory References:
--   - ITAA 1997 s 28-J (Annual Opening/Closing Odometer Requirement)
--   - ITAA 1997 s 28-G (Continuous 12-Week Representative Logbook Period)
-- File: 20261114220000_annual_odometer_and_logbook_periods.sql
-- ==============================================================================

-- 1. ANNUAL VEHICLE ODOMETER TABLE (ITAA 1997 s 28-J)
CREATE TABLE IF NOT EXISTS public.annual_odometers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_id TEXT,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    financial_year TEXT NOT NULL, -- e.g. '2024-2025' or 'FY25'
    opening_date DATE NOT NULL,
    opening_odometer NUMERIC(10, 2) NOT NULL,
    closing_date DATE,
    closing_odometer NUMERIC(10, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_opening_odo CHECK (opening_odometer >= 0),
    CONSTRAINT chk_closing_odo CHECK (closing_odometer IS NULL OR closing_odometer >= opening_odometer)
);

CREATE INDEX IF NOT EXISTS idx_annual_odometers_user ON public.annual_odometers (user_id);
CREATE INDEX IF NOT EXISTS idx_annual_odometers_vehicle ON public.annual_odometers (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_annual_odometers_fy ON public.annual_odometers (user_id, financial_year);
CREATE INDEX IF NOT EXISTS idx_annual_odometers_local_id ON public.annual_odometers (user_id, local_id);

-- 2. LOGBOOK PERIODS TABLE (ITAA 1997 s 28-G)
CREATE TABLE IF NOT EXISTS public.logbook_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_id TEXT,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    start_odometer NUMERIC(10, 2) NOT NULL,
    end_odometer NUMERIC(10, 2),
    status TEXT NOT NULL DEFAULT 'notStarted',
    certified_business_percentage NUMERIC(5, 2),
    established_financial_year TEXT NOT NULL,
    valid_until_financial_year TEXT NOT NULL,
    digital_signature_hash TEXT,
    certified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_logbook_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_logbook_odo CHECK (end_odometer IS NULL OR end_odometer >= start_odometer),
    CONSTRAINT chk_logbook_business_pct CHECK (certified_business_percentage IS NULL OR (certified_business_percentage >= 0 AND certified_business_percentage <= 100))
);

CREATE INDEX IF NOT EXISTS idx_logbook_periods_user ON public.logbook_periods (user_id);
CREATE INDEX IF NOT EXISTS idx_logbook_periods_vehicle ON public.logbook_periods (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_logbook_periods_status ON public.logbook_periods (user_id, status);
CREATE INDEX IF NOT EXISTS idx_logbook_periods_local_id ON public.logbook_periods (user_id, local_id);

-- 3. COMPOSITE INDEXES FOR JOB SITE FILTERING (Trips & Expenses)
CREATE INDEX IF NOT EXISTS idx_trips_user_job ON public.trips (user_id, job_id) WHERE job_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_expenses_user_job ON public.expenses (user_id, job_id) WHERE job_id IS NOT NULL;

-- 4. ROW LEVEL SECURITY (RLS) FOR NEW TABLES
ALTER TABLE public.annual_odometers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.annual_odometers FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "annual_odometers_select_own" ON public.annual_odometers;
CREATE POLICY "annual_odometers_select_own" ON public.annual_odometers
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "annual_odometers_insert_own" ON public.annual_odometers;
CREATE POLICY "annual_odometers_insert_own" ON public.annual_odometers
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "annual_odometers_update_own" ON public.annual_odometers;
CREATE POLICY "annual_odometers_update_own" ON public.annual_odometers
    FOR UPDATE TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "annual_odometers_delete_own" ON public.annual_odometers;
CREATE POLICY "annual_odometers_delete_own" ON public.annual_odometers
    FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

ALTER TABLE public.logbook_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logbook_periods FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "logbook_periods_select_own" ON public.logbook_periods;
CREATE POLICY "logbook_periods_select_own" ON public.logbook_periods
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "logbook_periods_insert_own" ON public.logbook_periods;
CREATE POLICY "logbook_periods_insert_own" ON public.logbook_periods
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "logbook_periods_update_own" ON public.logbook_periods;
CREATE POLICY "logbook_periods_update_own" ON public.logbook_periods
    FOR UPDATE TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "logbook_periods_delete_own" ON public.logbook_periods;
CREATE POLICY "logbook_periods_delete_own" ON public.logbook_periods
    FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

-- 5. PERMISSIONS GRANT
GRANT SELECT, INSERT, UPDATE, DELETE ON public.annual_odometers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.logbook_periods TO authenticated;
REVOKE ALL ON public.annual_odometers FROM anon;
REVOKE ALL ON public.logbook_periods FROM anon;

NOTIFY pgrst, 'reload schema';
