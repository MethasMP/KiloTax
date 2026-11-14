# KiloTax Evidence Graph Contract & Cryptographic Vault Specification

> **Version:** 1.0.0 (Production Immutable)
> **Squad:** Alpha (Lead Data Architect & Cryptographic Vault)
> **Regulatory Foundation:** Statutory compliance with ATO ITAA 1997 s 900-165, TR 97/11, TR 95/34, and Taxation Administration Act 1953 (TAA 1953) Schedule 1 s 284-75.
> **Classification:** EDE (Evidence-Driven Engineering) Tier-A / Tier-B Invariant Standard.

---

## 1. Executive Architecture & Mission Overview

Generic mileage loggers treat vehicle journeys as isolated GPS polyline snippets and expenses as detached receipt image blobs. This failure mode collapses under ATO Section 900-165 audits, where the Australian Taxation Office requires unbroken evidentiary linkage proving business nexus, contemporaneous records, and tamper-evident storage for a minimum of 5 statutory tax years (1,825 days).

**Squad Alpha establishes the Evidence Graph Data Layer:**
1. **JobSite POI Entity**: Sovereign representation of client job sites, building projects, work depots, and trade merchant geofences (`lat`, `lng`, `radiusMeters`, `clientName`, `projectCode`).
2. **Immutable Receipt Vault**: Cryptographic SHA-256 byte-level hash integrity matching Supabase Storage objects (`receipts/` private bucket), verified on client-side before upload, enforced via Postgres append-only triggers and row-level security.
3. **5-Year Digital Retention Enforcement**: Architectural lock-down guaranteeing immutability, audit logging, and forensic export compliance according to ITAA 1997 s 900-165.
4. **Invariant Contracts for Squad Beta & Squad Gamma**:
   - **Squad Beta (Matcher)**: Spatial & temporal geodesic correlation rules joining Trips, JobSites, and Expense Receipts.
   - **Squad Gamma (Handoff)**: Accountant-grade verifiable deduction chain packaging for export, HandiTax, and ATO forensic review.

---

## 2. Statutory Legal & Regulatory Compliance Framework

### 2.1 ATO ITAA 1997 Division 900 — Substantiation Rules
- **s 900-165 (Retention of Records):** A taxpayer must retain written evidence for 5 statutory years starting from the due date of lodging the return, or the date the return was lodged, whichever is later.
- **s 900-25 & s 900-115 (Written Evidence of Expense):** Document issued by supplier specifying supplier identity, amount, nature of goods/services, date, and currency.
- **s 28-120 & s 28-125 (Logbook Requirements):** Entries must be made contemporaneously (at or as soon as possible after the end of each journey) recording date, start/end odometer, distance, purpose, and driver.

### 2.2 Electronic Record Keeping Standards (TR 2018/2 & TR 97/11)
Digital records fulfill substantiation requirements **only if**:
1. They are completely tamper-evident (preventing retroactive alteration, tampering, or deletion).
2. The digital reproduction remains true and clear across the entire 5-year retention window.
3. Metadata proves contemporaneous capture (timestamp, geo-coordinates, capture device telemetry, SHA-256 checksum).

---

## 3. Formal Invariants Specification

### 3.1 Tier A Invariants (Non-Negotiable System Contracts — Runtime Falsifiable)

Violations of Tier A invariants MUST immediately halt execution, trigger audit alerts, or reject database mutations with strict Postgres exception codes.

* **[INV-A01] Cryptographic Content Hash Invariant (SHA-256):**
  Every receipt or audit photo stored in the vault MUST have an identical SHA-256 hash across:
  `Hash(Optimized Local File Bytes) == audit_evidence.image_sha256 == Storage Object SHA-256 Header`.
  *Proof:* Any discrepancy indicates file corruption or middle-tier byte tampering.

* **[INV-A02] Append-Only Vault Immutability:**
  Rows in `public.audit_evidence` CANNOT be updated (`UPDATE`) or deleted (`DELETE`) by any authenticated role, client token, or application service. Enforced via PostgreSQL trigger `trg_audit_evidence_tamper_proof` throwing error `55000` (`object_not_modifiable`).

* **[INV-A03] Retention Time Floor (1,825 Days):**
  No audit record or underlying storage object linked to a lodged tax year may be purged or removed prior to `created_at + INTERVAL '5 years'`. Hard deletion endpoints do not exist in the public API.

* **[INV-A04] Multi-Tenant Zero-Trust Storage Partitioning:**
  Supabase Storage path must strictly adhere to:
  `receipts/{auth.uid()}/{yyyy}/{mm}/{image_sha256}.{ext}`.
  Storage RLS rejects any read/write attempt outside `(storage.foldername(name))[1] = auth.uid()::text`.

* **[INV-A05] Zero-Entropy JobSite Geofence Geometry:**
  A `JobSite` must satisfy:
  `-90.0 <= latitude <= 90.0`, `-180.0 <= longitude <= 180.0`, and `10.0 <= radiusMeters <= 5000.0`.
  Zero, negative, or degenerate radii are rejected at both client Dart validation and database `CHECK` constraints.

---

### 3.2 Tier B Invariants (Operational & Matcher Contracts for Squad Beta & Gamma)

Violations of Tier B invariants degrade matching scores or require human resolution, but do not compromise cryptographic vault integrity.

* **[INV-B01] Geodesic Spatial Bounds for Expense Matching (Squad Beta):**
  An expense receipt docket can only auto-link to a `Trip` if the geodesic distance from the merchant coordinates to either trip origin, trip destination, or along-route bounding box is `<= 15.0 km` (default trade supply radius).

* **[INV-B02] Temporal Window for Receipt Correlation (Squad Beta):**
  Expense dockets can auto-correlate to a trip only within `trip.date ± 4.0 hours` (or same calendar day `00:00 - 23:59:59 AEST/AWST` for merchant materials with invoice delays).

* **[INV-B03] JobSite Dwell Time Threshold (Squad Beta):**
  A trip is automatically tagged with a `JobSite` POI if the vehicle stop event occurs within `job_site.radiusMeters` for `>= 120 seconds` (2 minutes).

* **[INV-B04] Idempotent Evidence Graph Edge Linking (Squad Beta & Gamma):**
  Linking an expense receipt or JobSite to a Trip must be idempotent. Repeating an association using the same `(trip_id, expense_id)` or `(trip_id, job_site_id)` tuple must yield the identical state without duplicating ledger line items.

* **[INV-B05] Statutory Accountant Export Provenance (Squad Gamma):**
  Every export generated for accountants or tax agents (CSV, Excel OpenXML, PDF) must include:
  1. `AuditEvidence.id` and `imageSha256` for every claimed vehicle expense line item.
  2. `JobSite.projectCode` and `clientName` where business purpose is claimed.
  3. System verification seal timestamp proving cryptographic substantiation.

---

## 4. Entity Relationship & Evidence Graph Topology

```
                       +-------------------+
                       |    auth.users     |
                       +---------+---------+
                                 |
         +-----------------------+-----------------------+
         | 1:N                                           | 1:N
+--------v--------+                             +--------v--------+
|    job_sites    |                             |    vehicles     |
| (POI & Geofence)|                             +--------+--------+
+--------+--------+                                      | 1:N
         | 1:N                                  +--------v--------+
         | (Destination / Stop)                 |      trips      |
         |                                      +--------+--------+
         |                                               | 1:N
         |              +--------------------------------+
         |              | 1:N
+--------v--------------v--------+              +-------------------------+
|     trip_evidence_links        |              |     audit_evidence      |
|  (Trips <-> JobSites / Exp)    |<-------------| (Immutable Cryptographic|
+--------------------------------+  EvidenceID  |      SHA-256 Vault)     |
                                                +-------------------------+
                                                             |
                                                +------------v------------+
                                                | Supabase Storage Objects|
                                                |   bucket: 'receipts'    |
                                                +-------------------------+
```

---

## 5. Supabase Postgres DDL & Cryptographic Storage Schemas

```sql
-- ==============================================================================
-- KiloTax Migration: Evidence Graph Core (JobSite POI & Cryptographic Vault)
-- Statutory Reference: ATO ITAA 1997 s 900-165 & TR 97/11
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

CREATE UNIQUE INDEX IF NOT EXISTS unq_audit_evidence_user_sha256
ON public.audit_evidence (user_id, image_sha256);

CREATE INDEX IF NOT EXISTS idx_audit_evidence_user_id ON public.audit_evidence (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_evidence_entity ON public.audit_evidence (user_id, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_evidence_type ON public.audit_evidence (evidence_type);

-- 3. EVIDENCE GRAPH INTERMEDIATE LINKING TABLE
CREATE TABLE IF NOT EXISTS public.trip_evidence_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    job_site_id UUID REFERENCES public.job_sites(id) ON DELETE SET NULL,
    expense_id UUID REFERENCES public.vehicle_expenses(id) ON DELETE CASCADE,
    evidence_id UUID REFERENCES public.audit_evidence(id) ON DELETE RESTRICT,
    confidence_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    association_method TEXT NOT NULL, -- 'manual_user', 'spatial_geofence', 'temporal_proximity', 'ocr_abn_match'
    linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_confidence_score CHECK (confidence_score >= 0.0 AND confidence_score <= 1.0),
    CONSTRAINT unq_trip_evidence_link UNIQUE (trip_id, expense_id, evidence_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_evidence_trip ON public.trip_evidence_links (trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_evidence_job ON public.trip_evidence_links (job_site_id);

-- 4. ROW LEVEL SECURITY (RLS) & PRIVILEGE HARDENING
ALTER TABLE public.job_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_sites FORCE ROW LEVEL SECURITY;

CREATE POLICY "job_sites_select_own" ON public.job_sites
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE POLICY "job_sites_insert_own" ON public.job_sites
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "job_sites_update_own" ON public.job_sites
    FOR UPDATE TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "job_sites_delete_own" ON public.job_sites
    FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

ALTER TABLE public.trip_evidence_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_evidence_links FORCE ROW LEVEL SECURITY;

CREATE POLICY "trip_evidence_select_own" ON public.trip_evidence_links
    FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE POLICY "trip_evidence_insert_own" ON public.trip_evidence_links
    FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

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
```

---

## 6. Dart Domain Data Models (Production Contracts)

### 6.1 `JobSite` Entity
- Encapsulates geofenced Points of Interest (POI) with client name, project code, latitude, longitude, and radius.
- Includes geodesic containment check using WGS-84 coordinate geometry.

### 6.2 `AuditEvidence` & `CryptographicReceiptVault`
- Provides byte-level streaming SHA-256 calculation.
- Guarantees zero hash drift prior to Supabase Storage upload.
- Implements ATO 5-year retention validity verification.
