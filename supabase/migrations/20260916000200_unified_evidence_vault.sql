-- ==============================================================================
-- KiloTax Permanent Migration: Unified Audit Evidence Vault
-- Architecture: Polymorphic Evidence Repository (ITAA 1997 & TR 97/11 Compliant)
-- ==============================================================================

-- 1. Create the central Unified Audit Evidence Vault table
CREATE TABLE IF NOT EXISTS audit_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    
    -- Categorization: 'odometer_start', 'odometer_end', 'heavy_tools_setup', 'expense_receipt'
    evidence_type TEXT NOT NULL,
    entity_id TEXT, -- e.g. expense ID, trip ID, or logbook schedule ID
    
    -- File Storage & Verification
    storage_path TEXT NOT NULL,
    image_sha256 TEXT NOT NULL,
    file_size_bytes BIGINT,
    mime_type TEXT DEFAULT 'image/webp',
    
    -- Tamper-evidence & Live Capture Metadata
    captured_at TIMESTAMPTZ NOT NULL,
    capture_source TEXT NOT NULL DEFAULT 'camera_live', -- 'camera_live', 'scan_document'
    watermark_metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Strict Anti-Fraud Invariant: No duplicate image reuse permitted per taxpayer
    CONSTRAINT unq_user_evidence_image_hash UNIQUE (user_id, image_sha256)
);

-- 2. Query Performance Indexes for Fast Audit Dossier Generation
CREATE INDEX IF NOT EXISTS idx_evidence_user_vehicle ON audit_evidence (user_id, vehicle_id);
CREATE INDEX IF NOT EXISTS idx_evidence_type ON audit_evidence (evidence_type);
CREATE INDEX IF NOT EXISTS idx_evidence_captured_at ON audit_evidence (captured_at);

-- 3. Row-Level Security (RLS) Policy
ALTER TABLE audit_evidence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own audit evidence"
ON audit_evidence
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
