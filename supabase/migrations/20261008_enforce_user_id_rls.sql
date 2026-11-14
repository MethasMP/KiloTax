-- Migration: 20261008_enforce_user_id_rls.sql
-- Harden Row Level Security policies on trips and expenses tables
-- Explicitly enforces user_id = auth.uid() in USING and WITH CHECK clauses
-- preventing cross-tenant access even if vehicle_id ownership checks pass or are bypassed.

-- 1. trips RLS policy hardening
DROP POLICY IF EXISTS "Users can manage their own trips" ON public.trips;

CREATE POLICY "Users can manage their own trips"
    ON public.trips
    FOR ALL
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.vehicles v 
            WHERE v.id = trips.vehicle_id 
              AND v.user_id = auth.uid()
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.vehicles v 
            WHERE v.id = trips.vehicle_id 
              AND v.user_id = auth.uid()
        )
    );

-- 2. expenses RLS policy hardening
DROP POLICY IF EXISTS "Users can manage their own expenses" ON public.expenses;

CREATE POLICY "Users can manage their own expenses"
    ON public.expenses
    FOR ALL
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.vehicles v 
            WHERE v.id = expenses.vehicle_id 
              AND v.user_id = auth.uid()
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.vehicles v 
            WHERE v.id = expenses.vehicle_id 
              AND v.user_id = auth.uid()
        )
    );
