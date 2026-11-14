-- Migration: 20261008_storage_receipts_rls.sql
-- Creates private receipts storage bucket and RLS policies ensuring users can only read/write to their own folder `auth.uid()`.

-- 1. Create the receipts bucket if it doesn't already exist
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

-- 2. Drop any legacy open policies on storage.objects for the receipts bucket
DROP POLICY IF EXISTS "Authenticated users can upload receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own receipts" ON storage.objects;
DROP POLICY IF EXISTS "Receipts bucket isolation policy" ON storage.objects;

-- 3. Row-Level Security on storage.objects scoped strictly to user folder: auth.uid() = (storage.foldername(name))[1]

-- Policy: Select / Read
CREATE POLICY "Users can read own receipts"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Insert / Upload
CREATE POLICY "Users can upload own receipts"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Update / Upsert
CREATE POLICY "Users can update own receipts"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Delete
CREATE POLICY "Users can delete own receipts"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
