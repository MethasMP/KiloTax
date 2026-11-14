-- Migration: 20261008_append_only_audit_evidence.sql
-- Restricts RLS policies on audit_evidence table to SELECT and INSERT only.
-- Explicitly drops any UPDATE or DELETE permissions for authenticated users to enforce strict immutability.

-- Drop existing broad policy if present
DROP POLICY IF EXISTS "Users can only access their own audit evidence" ON audit_evidence;
DROP POLICY IF EXISTS "Users can view own audit evidence" ON audit_evidence;
DROP POLICY IF EXISTS "Users can insert own audit evidence" ON audit_evidence;
DROP POLICY IF EXISTS "Users can update own audit evidence" ON audit_evidence;
DROP POLICY IF EXISTS "Users can delete own audit evidence" ON audit_evidence;

-- Enable RLS
ALTER TABLE audit_evidence ENABLE ROW LEVEL SECURITY;

-- 1. Read Policy: Users can select only their own evidence
CREATE POLICY "Users can view own audit evidence"
ON audit_evidence
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 2. Append-Only Policy: Users can insert evidence only for their own user_id
CREATE POLICY "Users can insert own audit evidence"
ON audit_evidence
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Ensure NO update or delete policies exist for authenticated users.
-- In PostgreSQL RLS, without an UPDATE or DELETE policy, operations on those commands are denied by default.
