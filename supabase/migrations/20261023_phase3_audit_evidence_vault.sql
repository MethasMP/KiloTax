-- ==============================================================================
-- KiloTax Migration: Phase 3 - Audit Evidence Vault & Storage Security
-- File: 20261023_phase3_audit_evidence_vault.sql
-- Description:
-- 1. Storage bucket 'receipts' security hardening:
--    - Set bucket to private (public = false)
--    - Drop legacy and overly-permissive storage policies
--    - Enforce folder-level multi-tenant isolation: (storage.foldername(name))[1] = (select auth.uid())::text
-- 2. Audit Evidence Vault hardening (public.audit_evidence):
--    - Verify / create unique index for (user_id, image_sha256)
--    - Enforce Tamper-Proof Append-Only Evidence Vault via trigger (prevent UPDATE / DELETE)
--    - Optimize RLS policies using (select auth.uid()) and revoke UPDATE/DELETE grants from authenticated
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. STORAGE BUCKET HARDENING: 'receipts'
-- ------------------------------------------------------------------------------

-- Ensure bucket exists and is strictly private with configured limits
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'receipts',
    'receipts',
    false,
    10485760, -- 10MB limit
    ARRAY['image/webp', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/webp', 'image/jpeg', 'image/png'];

-- Drop all insecure / legacy policies on storage.objects for the receipts bucket
DROP POLICY IF EXISTS "Public Read Access for Receipts" ON storage.objects;
DROP POLICY IF EXISTS "Allow Upload to Receipts" ON storage.objects;
DROP POLICY IF EXISTS "Allow Delete Receipts" ON storage.objects;
DROP POLICY IF EXISTS "Receipts bucket isolation policy" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own receipts" ON storage.objects;

-- Re-create isolated RLS policies on storage.objects
-- Note: Uses (select auth.uid())::text as per supabase-postgres-best-practices (security-rls-performance)
CREATE POLICY "receipts_select_own_folder"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "receipts_insert_own_folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "receipts_update_own_folder"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "receipts_delete_own_folder"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);


-- ------------------------------------------------------------------------------
-- 2. AUDIT EVIDENCE VAULT HARDENING: public.audit_evidence
-- ------------------------------------------------------------------------------

-- Ensure table exists
CREATE TABLE IF NOT EXISTS public.audit_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL,
    entity_id TEXT,
    storage_path TEXT NOT NULL,
    image_sha256 TEXT NOT NULL,
    file_size_bytes BIGINT,
    mime_type TEXT DEFAULT 'image/webp',
    captured_at TIMESTAMPTZ NOT NULL,
    capture_source TEXT NOT NULL DEFAULT 'camera_live',
    watermark_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure user_id index exists for RLS and foreign key performance
CREATE INDEX IF NOT EXISTS idx_audit_evidence_user_id ON public.audit_evidence (user_id);
CREATE INDEX IF NOT EXISTS idx_evidence_user_vehicle ON public.audit_evidence (user_id, vehicle_id);
CREATE INDEX IF NOT EXISTS idx_evidence_type ON public.audit_evidence (evidence_type);
CREATE INDEX IF NOT EXISTS idx_evidence_captured_at ON public.audit_evidence (captured_at);

-- Unique index per user on SHA-256 hash to prevent duplicate evidence reuse
CREATE UNIQUE INDEX IF NOT EXISTS unq_audit_evidence_user_sha256
ON public.audit_evidence (user_id, image_sha256);

-- Tamper-Proof Append-Only Trigger:
-- Prevents UPDATE or DELETE of tax audit evidence records (ATO compliance & ITAA 1997 / TR 97/11)
CREATE OR REPLACE FUNCTION public.enforce_audit_evidence_tamper_proof()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'Tamper-Proof Audit Vault: % operations are prohibited on audit_evidence (ATO Compliance ITAA 1997).', TG_OP
        USING ERRCODE = '55000'; -- object_not_modifiable
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_evidence_tamper_proof ON public.audit_evidence;

CREATE TRIGGER trg_audit_evidence_tamper_proof
BEFORE UPDATE OR DELETE ON public.audit_evidence
FOR EACH ROW
EXECUTE FUNCTION public.enforce_audit_evidence_tamper_proof();


-- ------------------------------------------------------------------------------
-- 3. RLS & PRIVILEGES HARDENING FOR public.audit_evidence
-- ------------------------------------------------------------------------------

ALTER TABLE public.audit_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_evidence FORCE ROW LEVEL SECURITY;

-- Clean existing policies
DROP POLICY IF EXISTS "Users can only access their own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can view own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can insert own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can update own audit evidence" ON public.audit_evidence;
DROP POLICY IF EXISTS "Users can delete own audit evidence" ON public.audit_evidence;

-- SELECT policy: Cached auth.uid() check
CREATE POLICY "audit_evidence_select_own"
ON public.audit_evidence
FOR SELECT
TO authenticated
USING (user_id = (SELECT auth.uid()));

-- INSERT policy: Cached auth.uid() check
CREATE POLICY "audit_evidence_insert_own"
ON public.audit_evidence
FOR INSERT
TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

-- Principle of Least Privilege: Revoke UPDATE and DELETE from authenticated and anon
REVOKE UPDATE, DELETE ON public.audit_evidence FROM authenticated;
REVOKE UPDATE, DELETE ON public.audit_evidence FROM anon;
