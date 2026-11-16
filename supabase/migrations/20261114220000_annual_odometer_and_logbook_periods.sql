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
