-- ==============================================================================
-- KiloClaim Database Migration: Phase 1 - Security & Core RLS Optimization
-- Migration: 20261023_phase1_security_rls_optimization.sql
--
-- References:
--  - supabase-postgres-best-practices/references/security-rls-performance.md
--  - supabase-postgres-best-practices/references/security-rls-basics.md
--  - supabase-postgres-best-practices/references/schema-foreign-key-indexes.md
--
-- Objectives:
-- 1. Foreign Key Indexes:
--    - Create indexes on trips(user_id) and expenses(user_id) to eliminate table scans
--      during JOINs, cascade deletes, and RLS policy evaluation.
-- 2. Optimize RLS Policies on public.vehicles:
--    - Replace per-row auth.uid() function evaluations with cached `(select auth.uid())`.
--    - Provide explicit USING and WITH CHECK clauses for authenticated users.
-- 3. Optimize RLS Policies on public.trips and public.expenses:
--    - Enforce direct `user_id = (select auth.uid())` for O(1) indexed RLS filtering.
--    - Retain multi-tenant vehicle ownership verification `EXISTS (SELECT 1 FROM public.vehicles ...)`.
--    - Provide explicit USING and WITH CHECK clauses.
-- 4. Optimize RLS Policies on public.audit_evidence:
--    - Ensure SELECT and INSERT policies use `(select auth.uid())`.
--    - Enforce append-only semantics by dropping any legacy permissive ALL policies.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FOREIGN KEY INDEXES
-- ------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_trips_user_id
ON public.trips(user_id);

CREATE INDEX IF NOT EXISTS idx_expenses_user_id
ON public.expenses(user_id);

-- ------------------------------------------------------------------------------
-- 2. VEHICLES TABLE RLS OPTIMIZATION
-- ------------------------------------------------------------------------------

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can view own vehicles" ON public.vehicles;

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

-- ------------------------------------------------------------------------------
-- 3. TRIPS TABLE RLS OPTIMIZATION
-- ------------------------------------------------------------------------------

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own trips" ON public.trips;
DROP POLICY IF EXISTS "Users can view own trips" ON public.trips;

CREATE POLICY "Users can manage their own trips"
ON public.trips
FOR ALL
TO authenticated
USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.vehicles v
        WHERE v.id = trips.vehicle_id
          AND v.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.vehicles v
        WHERE v.id = trips.vehicle_id
          AND v.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------------------------
-- 4. EXPENSES TABLE RLS OPTIMIZATION
-- ------------------------------------------------------------------------------

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can view own expenses" ON public.expenses;

CREATE POLICY "Users can manage their own expenses"
ON public.expenses
FOR ALL
TO authenticated
USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.vehicles v
        WHERE v.id = expenses.vehicle_id
          AND v.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.vehicles v
        WHERE v.id = expenses.vehicle_id
          AND v.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------------------------
-- 5. AUDIT EVIDENCE TABLE RLS OPTIMIZATION
-- ------------------------------------------------------------------------------

ALTER TABLE public.audit_evidence ENABLE ROW LEVEL SECURITY;

-- Clean up any legacy or overlapping policies
DROP POLICY IF EXISTS "Users can only access their own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can view own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can insert own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "audit_evidence_select_own" ON public.audit_evidence;
DROP POLICY IF EXISTS "audit_evidence_insert_own" ON public.audit_evidence;

-- Append-only pattern: SELECT and INSERT only. UPDATE and DELETE denied by default.
CREATE POLICY "audit_evidence_select_own"
ON public.audit_evidence
FOR SELECT
TO authenticated
USING (
    user_id = (SELECT auth.uid())
);

CREATE POLICY "audit_evidence_insert_own"
ON public.audit_evidence
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = (SELECT auth.uid())
);
