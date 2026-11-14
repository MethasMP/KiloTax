# KiloTax Strategic Architecture Specification: The 3 Core Weapons & Moat Strategy

**Author:** Executive Product & Architecture Team (KiloTax / DriveLog)
**Regulatory Baseline:** Australian Taxation Office (ATO) — *ITAA 1997 Subdivisions 28-C, 28-F, 28-G; TR 2021/1; TR 97/11; TAA 1953 Sch 1 s 284-75*
**Date:** 2026-11-07

---

## 1. Executive Strategy: "สิ่งที่ยังไม่ใช่คูเมือง" (What is NOT a Moat) vs. The True Moat

### 1.1 The Commodity Traps & Audit Liabilities

| Commodity "Feature" | Why Competitors Think It's A Moat | The ATO Reality & Why It Fails |
| :--- | :--- | :--- |
| **1. Generic GPS Distance Tracking** | Any basic mobile app can log location breadcrumbs. Competitors treat distance as the sole metric. | Under *ITAA 1997 s28-125*, **odometer readings are mandatory**, not GPS estimates. An ATO auditor disallows claims if trip kilometers do not reconcile with annual service logs and registration records. |
| **2. Pretty Map Routes & Polylines** | Visual eye-candy for marketing screenshots. | Map routes do not establish tax deductibility. Home-to-work travel is statutory non-deductible (*Lunney v FCT [1958]*). Without establishing the *Bulky Tools Exception* (secure carriage of heavy trade equipment with no lockup at the job site), mapping the route proves nothing. |
| **3. Naive "Auto-Deductible" AI Guessing (e.g., Bunnings = 100% Tax Deductible)** | Apps claim AI can auto-mark hardware store stops as business expenses to provide instant dopamine. | **Catastrophic audit failure.** Bunnings sells outdoor lounge sets, BBQs, and home decor alongside timber and tools. The ATO's automated data-matching algorithms red-flag 100% retail claims without line-item substantiation. Tools belong under **D5 Depreciation (Div 40)**, NOT **D1 Car Expenses**. Conflating them destroys the accountant's trust. |
| **4. Silent Odometer Gap Bridging** | Silently injecting synthetic "personal trips" to balance missing odometer readings. | **Record fabrication.** Under *Crimes Act 1914* and ATO audit guidelines, manufacturing bridging records without human confirmation can be treated as fraudulent document creation during an audit. |
| **5. Plain PDF Generation** | Pressing "Generate PDF" with generic tables. | Accountants hate receiving 80-page non-actionable PDFs that they cannot import into Xero, HandiTax, or MYOB without re-typing numbers manually. |

---

### 1.2 The True Moat: The Unbreakable Tax Evidence Graph

```
+-----------------------------------------------------------------------------------------+
|                                    THE KILOTAX MOAT                                     |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|   [Trip Record]  ──(Proves Travel)──►  [Job Site POI]  ──(Justifies Work)               |
|         │                                       │                                       |
|         ▼                                       ▼                                       |
|   [Odometer Ledger] ◄──(Reconciles)──  [Tax Invoice Docket] ──(Substantiates Cost)      |
|                                        (SHA-256 Hashed Line-Item)                       |
|                                                                                         |
|   Result: Audit-proof chain where pulling one thread validates the entire fabric.       |
+-----------------------------------------------------------------------------------------+
```

1. **Multi-Layer Connected Evidence Graph:** Every claim connects telematics, physical odometer photos, job site references, and cryptographic receipt hashes.
2. **Dual-Basket Tax Arbitrage Engine:** Real-time mathematical arbitrage between **Cents per Kilometre (CPK - Subdiv 28-C, 5,000 km statutory cap)** and the **12-Week Logbook Method (Subdiv 28-F)**, showing exact dollar-for-dollar tax differences.
3. **The Accountant Distribution Flywheel (B2B2C):** We turn tax accountants into our primary sales force by cutting their EOFY prep time from 2 hours to 8 minutes through pre-formatted HandiTax D1 schedules.

---

## 2. Weapon 1: Pre-Flight Audit Gap Detection Engine ("ตรวจพบช่องว่างก่อนส่งให้นักบัญชี")

### 2.1 The 5 Lethal Audit Gap Types

```
  [Ingested Data]
         │
         ├──► Gap 1: Unclassified Trips (Null Status)
         ├──► Gap 2: Vague Purpose (e.g. "Work", "Meeting") ──► [Rejection / Remediation]
         ├──► Gap 3: Odometer Discontinuity (Δ > 0.1 km)     ──► [Visual Gap Journey]
         ├──► Gap 4: Unsubstantiated Running Expenses        ──► [OCR / Receipt Vault]
         └──► Gap 5: Mixed-Purpose Supplies (No Split %)     ──► [Apportionment Engine]
```

1. **Unclassified Trips (Null Classification):**
   *Risk:* Under *s28-115*, an incomplete logbook invalidates the entire 12-week sample.
   *Rule:* Flag any trip where `classification == null`. Bar final logbook certification until 100% classified.
2. **Vague or Defective Business Purpose:**
   *Risk:* In *Re Zoffman and FCT [2013] AATA 386*, generic descriptions like "Work", "Client", or "Meeting" failed substantiation under *s28-125(2)(c)*.
   *Rule:* Evaluated against a strict ban list: `['work', 'meeting', 'drive', 'client', 'job', 'misc', 'travel']`. Force context: `Client Name / Invoice Reference` + `Site Address` + `Activity Type`.
3. **Odometer Discontinuity (The Odometer Gap):**
   *Risk:* If Trip A ends at 45,210 km and Trip B starts at 45,350 km, the unaccounted 140 km is treated by the ATO as personal driving or logbook tampering.
   *Rule:* Calculate $\Delta_{\text{odo}} = \text{Trip}_{i+1}.\text{startOdometer} - \text{Trip}_i.\text{endOdometer}$. If $\Delta_{\text{odo}} > 0.1\text{ km}$, spawn an unresolved gap.
4. **Unsubstantiated Expenses (Missing Tax Invoices):**
   *Risk:* Under *s900-115*, bank statements alone do not suffice for amounts $> \$82.50$ (GST tax invoice threshold).
   *Rule:* Flag expenses where `receiptPath == null` or `receiptAudit.imageSha256 == null`.
5. **Mixed-Purpose Expenses Lacking Split Apportionment:**
   *Risk:* Hardware stores (Bunnings, Mitre10, Supercheap Auto) mix trade materials and domestic goods.
   *Rule:* High-risk merchant flagging prompts user to confirm line items and apportion business % before tax claim.

### 2.2 Provenance Engine & Anti-Fabrication Safeguards
To eliminate fraud liability, KiloTax enforces a 3-tier provenance model:
* **Tier 1 (Automated Telematics):** Raw GPS, Bluetooth BLE vehicle connect, or OBD2 sensor.
* **Tier 2 (Heuristic Inferred):** Suggested site name based on geofence or calendar.
* **Tier 3 (Human Confirmed):** Taxpayer affirmative verification with timestamp.

**Anti-Fabrication Odometer Rule:**
Never inject fake "personal bridging" trips. Gaps remain explicit items with two distinct user-driven resolutions:
- **Option A (Log Missing Journey):** User retroactively enters purpose, logged as `manual_retroactive`.
- **Option B (Acknowledge Personal Gap):** User confirms private weekend driving, logged as `human_confirmed_personal_gap`.

---

## 3. Weapon 2: The Accountant Handoff Pack ("ชุดส่งต่องานที่ผู้รับใช้ได้จริง")

### 3.1 The Standardized Handoff Pack Topology
Exported as an audit-proof signed container:

```
KiloTax_EOFY_Pack_2025_2026_TRADIE_01/
├── 01_Executive_Tax_Workpaper.pdf        <-- Signed CPA Summary & Statutory Attestation
├── 02_HandiTax_D1_Schedule.csv           <-- Direct Copy-Paste into HandiTax / Xero
├── 03_Continuous_Odometer_Ledger.csv     <-- 12-Week Representative Logbook (s28-125)
├── 04_Cryptographic_Receipt_Index.csv    <-- Substantiated Invoices with SHA-256 Hashes
└── Receipts_Vault/                       <-- Watermarked Invoices (ABN_Date_Amount.jpg)
```

### 3.2 HandiTax / Xero D1 Action Schedule Specification
```csv
Tax_Year,Client_Name,ABN,Vehicle_Rego,Vehicle_Description,Item_Label,Schedule_Code,Schedule_Name,Gross_Amount,Business_Percentage,Allowable_Deduction,ATO_Legislative_Reference
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1A,METHOD,"Logbook Method",0.00,85.00,0.00,"ITAA 1997 Subdiv 28-F (Code B)"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,401,"Fuel and Oil",4250.00,85.00,3612.50,"TR 97/11 Par 18"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,402,"Service, Repairs & Tyres",1850.00,85.00,1572.50,"ITAA 1997 s8-1"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,403,"Registration & Insurance",2400.00,85.00,2040.00,"ITAA 1997 s8-1"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,404,"Interest on Car Loan / Lease",950.00,85.00,807.50,"ITAA 1997 s25-25"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,405,"Depreciation (Division 40 Capital Allowance)",16850.00,85.00,14322.50,"ITAA 1997 Div 40 (Car Limit: $68,108)"
2025-2026,Dave Miller Plumbing,51 824 753 556,TRADIE-01,2023 Toyota Hilux SR5,D1B,406,"Direct Tolls & Work Parking",580.00,100.00,580.00,"TR 97/11 Par 19 (100% Direct Deductible)"
```

### 3.3 The Accountant Flywheel (B2B2C Growth)
1. **Frictionless Tax Agent Workflow:** Reconciling tradie receipts is an unbillable write-off for accounting firms. KiloTax turns a 2-hour painful manual reconciliation into an 8-minute verification.
2. **Firm-Wide Mandates:** Accountants mandate KiloTax across their entire client base (e.g. 300+ tradie clients per practice) because it eliminates their professional indemnity risk.

---

## 4. Weapon 3: Zero-Anxiety Privacy & Backup ("Privacy ที่ไม่ทำให้ลูกค้ากลัวข้อมูลหาย")

### 4.1 The ATO myDeductions Crisis (1.8-Star Lesson)
The official ATO *myDeductions* app has an average ~1.8 star rating due to a recurring catastrophe: **Data Loss Upon Phone Migration or App Updates**. ATO's official response: *"myDeductions records are stored locally on your device and are not backed up to ATO systems. You must manually export your backup via settings."*
When tradies lose a phone, they lose \$5,000–\$15,000 in deductions.

### 4.2 KiloTax's Solution: The `.ktpack` Container
A deterministic, compressed ZIP archive (`application/x-kilotax-pack`) holding the complete state:
- `manifest.json`: Archive header, schema versions, entity counts, device metadata.
- `database/state.json`: Full relational state (Vehicles, Trips, Expenses, Evidence, Annual Odometer).
- `receipts/{sha256}.webp`: Content-Addressable Storage (CAS) for all receipt binaries and odometer photos.
- `checksums.sha256`: Cryptographic manifest of every relative file path.

```
archive_20261107_153022.ktpack
├── manifest.json            # Versioning, counts, metadata
├── database/state.json      # Complete relational state
├── receipts/                # Binary photos named by SHA-256
│   ├── a8f5c9e2b0...webp
│   └── f14d90ca11...webp
└── checksums.sha256         # SHA-256 integrity verification
```

### 4.3 Native OS Vaulting (Zero Surveillance)
Instead of uploading raw GPS telemetry to external servers, KiloTax leverages OS-native private sandboxes:
- **iOS:** Apple iCloud Drive Ubiquity Container (`iCloud.com.kilotax.app/Documents/Backups`).
- **Android:** Scoped Storage / Private App Data with restricted Google Drive App Folder.
- **Trigger Cadence:** Automated snapshot 60s after trip completion, on receipt approval, and daily at 5:00 PM.
- **FIFO Ring Buffer Retention:** 7 daily rolling snapshots + 4 weekly milestones + 5-year statutory EOFY lock (ATO s900-165).

### 4.4 1-Tap Bulletproof Restore Engine
- **Pre-Restore Rollback Guarantee:** Always creates an emergency snapshot of current state before applying any backup.
- **Dry-Run Inspection:** Validates SHA-256 checksums, schema compatibility, and binary integrity before writing to SQLite.
- **Live Backup Health Shield:** Emerald Green (`Protected`), Amber (`Backup Recommended`), Coral Red (`Critical: No Recent Backup`).

---

## 5. Architectural Implementation Roadmap

```
┌────────────────────────────────────────────────────────────────────────┐
│                        KILOTAX CORE ROADMAP                            │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 1: Pre-Flight Audit Gap Engine (Weapon 1)                        │
│ - Integrate ForensicAuditAnalyzer into EvidenceReviewService           │
│ - Add non-fabrication odometer gap resolution workflow                 │
│ - Add line-item split check for mixed-purpose merchants                │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 2: HandiTax D1 Schedule & Accountant Pack (Weapon 2)             │
│ - Implement HandiTax CSV exporter mapped to ATO codes 401-406          │
│ - Implement Cryptographic Receipt Index with SHA-256 verification      │
│ - Update TaxPackBuilder to generate unified signed handoff bundle      │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3: .ktpack Archive & Restore Engine (Weapon 3)                   │
│ - Replace lightweight JSON with KtPackService (CAS WebP receipts)      │
│ - Implement RestoreEngineService with dry-run verification             │
│ - Connect OS-native iCloud / Google Drive background sync              │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 4: Tradie Ergonomics & Shield UI                                 │
│ - Embed BackupHealthShieldCard on Dashboard                            │
│ - Enforce 48x48dp tap targets and 1-tap ute cabin workflows            │
└────────────────────────────────────────────────────────────────────────┘
```
