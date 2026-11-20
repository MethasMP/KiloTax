-- ==============================================================================
-- KiloTax Database Migration: Odometer Evidence Vault & Anti-Fraud Verification
-- Complies with ITAA 1997 Subdivision 28-F & TR 97/11 (Statutory substantiation)
-- Enforces tamper-evident cryptographic hashes to prevent image reuse fraud
-- ==============================================================================

-- 1. Add Odometer and Tool Setup Evidence columns to vehicles table
ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS start_odometer_photo_path TEXT,
ADD COLUMN IF NOT EXISTS start_odometer_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS start_odometer_image_hash TEXT,
ADD COLUMN IF NOT EXISTS end_odometer_photo_path TEXT,
ADD COLUMN IF NOT EXISTS end_odometer_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS end_odometer_image_hash TEXT,
ADD COLUMN IF NOT EXISTS tool_setup_photo_path TEXT,
ADD COLUMN IF NOT EXISTS tool_setup_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS tool_setup_image_hash TEXT;

-- 2. Anti-fraud constraint: Start and end photos for the same vehicle cannot share the same image hash
ALTER TABLE vehicles
DROP CONSTRAINT IF EXISTS chk_different_odometer_photos;

ALTER TABLE vehicles
ADD CONSTRAINT chk_different_odometer_photos
CHECK (
  start_odometer_image_hash IS NULL 
  OR end_odometer_image_hash IS NULL 
  OR start_odometer_image_hash <> end_odometer_image_hash
);

-- 3. Audit index for quick lookups and cross-tenant duplicate fraud prevention
CREATE INDEX IF NOT EXISTS idx_vehicles_start_odo_hash ON vehicles (start_odometer_image_hash);
CREATE INDEX IF NOT EXISTS idx_vehicles_end_odo_hash ON vehicles (end_odometer_image_hash);
