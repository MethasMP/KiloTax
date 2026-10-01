-- ==============================================================================
-- KiloTax Database Migration: Base Schema & Multi-Tenant Core (ITAA 1997 Compliant)
-- Sets up initial tables (vehicles, trips, expenses), RLS policies, helper functions,
-- and secure account deletion RPC (Apple Guideline 5.1.1(v)).
-- ==============================================================================

-- 1. Helper function to compute Australian Financial Year (July 1 to June 30)
CREATE OR REPLACE FUNCTION get_financial_year(ts timestamptz)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_year integer := EXTRACT(YEAR FROM ts);
    v_month integer := EXTRACT(MONTH FROM ts);
    v_start_year integer;
    v_end_year integer;
BEGIN
    IF v_month >= 7 THEN
        v_start_year := v_year;
    ELSE
        v_start_year := v_year - 1;
    END IF;
    v_end_year := (v_start_year + 1) % 100;
    RETURN v_start_year::text || '-' || lpad(v_end_year::text, 2, '0');
END;
$$;

-- 2. Vehicles Table
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    rego_plate TEXT NOT NULL,
    initial_odometer NUMERIC NOT NULL DEFAULT 0.0,
    engine_capacity TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'car',
    bluetooth_device_name TEXT,
    is_primary BOOLEAN NOT NULL DEFAULT true,
    tax_method TEXT NOT NULL DEFAULT 'centsPerKm' CHECK (tax_method IN ('centsPerKm', 'logbook')),
    logbook_start_date TIMESTAMPTZ,
    client_dedup_id TEXT UNIQUE,
    display_name TEXT GENERATED ALWAYS AS (make || ' ' || model) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON public.vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_rego ON public.vehicles(rego_plate);

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own vehicles" ON public.vehicles;
CREATE POLICY "Users can manage their own vehicles"
    ON public.vehicles
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Trips Table
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    date TIMESTAMPTZ NOT NULL,
    distance_km NUMERIC NOT NULL CHECK (distance_km >= 0),
    purpose TEXT NOT NULL,
    start_odometer NUMERIC NOT NULL DEFAULT 0.0,
    end_odometer NUMERIC NOT NULL DEFAULT 0.0,
    classification TEXT NOT NULL DEFAULT 'business' CHECK (classification IN ('business', 'personal')),
    origin_address TEXT,
    destination_address TEXT,
    tax_method TEXT NOT NULL DEFAULT 'centsPerKm',
    evidence_source TEXT NOT NULL DEFAULT 'auto_telemetry',
    client_dedup_id TEXT UNIQUE,
    job_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle_date ON public.trips(vehicle_id, date);

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own trips" ON public.trips;
CREATE POLICY "Users can manage their own trips"
    ON public.trips
    FOR ALL
    USING (EXISTS (SELECT 1 FROM public.vehicles v WHERE v.id = trips.vehicle_id AND v.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.vehicles v WHERE v.id = trips.vehicle_id AND v.user_id = auth.uid()));

-- 4. Expenses Table
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    linked_trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    category TEXT NOT NULL,
    supplier TEXT,
    notes TEXT,
    receipt_storage_path TEXT,
    business_percentage NUMERIC(5, 2) NOT NULL DEFAULT 100.0,
    client_dedup_id TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON public.expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_vehicle_date ON public.expenses(vehicle_id, date);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own expenses" ON public.expenses;
CREATE POLICY "Users can manage their own expenses"
    ON public.expenses
    FOR ALL
    USING (EXISTS (SELECT 1 FROM public.vehicles v WHERE v.id = expenses.vehicle_id AND v.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.vehicles v WHERE v.id = expenses.vehicle_id AND v.user_id = auth.uid()));

-- 5. In-App Account Deletion RPC (Apple Guideline 5.1.1(v))
-- Purges all taxpayer records across all tables and removes the user from auth.users.
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Purge dependent records in reverse foreign key order
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_evidence') THEN
        DELETE FROM public.audit_evidence WHERE user_id = v_uid;
    END IF;
    DELETE FROM public.expenses WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE user_id = v_uid);
    DELETE FROM public.trips WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE user_id = v_uid);
    DELETE FROM public.vehicles WHERE user_id = v_uid;

    -- Delete user authentication record
    DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
