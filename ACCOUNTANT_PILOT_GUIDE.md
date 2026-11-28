# KiloClaim — Accountant Pilot & Substantiation Guide
**For Australian Tax Practitioners, CPAs, & Registered Tax Agents**
**Statutory Basis:** ITAA 1997 Division 28 (ITAA 1997 Div 28) & ATO Ruling TR 2021/1

---

## 1. Executive Summary for Accountants

KiloClaim is designed as a **Tax Evidence Operating System** for Australian sole traders and tradies. 
Rather than providing unstructured CSV dumps or generic mileage trackers, KiloClaim exports a strictly standardized **2-File Accountant Delivery Pack**:

1. **`KiloClaim_Tax_Summary_Sample.pdf`**: A formal summary declaration containing taxpayer identity (Name, ABN), vehicle details, opening/closing odometer readings, business percentage, and claim totals with a system audit timestamp.
2. **`KiloClaim_Accountant_Pack_[CPK|Logbook]_Sample.xlsx`**: An OpenXML multi-tab ledger with pre-formatted cell types (numeric numbers, ISO dates, text) ready for direct copy-paste or macro ingestion into **HandiTax**, **Xero Practice Manager**, or **MYOB**.

---

## 2. Statutory Deduction Methods Supported

### A. Cents-per-Kilometre (CPK) Method (ITAA 1997 Subdivision 28-C)
* **Statutory Rate:** \$0.88 / km (or current ATO statutory rate).
* **Hard 5,000 km Cap:** Capped strictly at 5,000 km per vehicle per financial year (max deduction \$4,400 per vehicle).
* **Multi-Vehicle Independence:** If the client operates 2 vehicles, each vehicle has its own independent 5,000 km cap.
* **Division 28-C Exclusion:** Fuel, repair, and maintenance costs are statutory inclusions in the rate and are quarantined from the deduction total.
* **Excel Structure (2 Tabs):**
  - **Tab 1: `Tax Summary`** — Total business km, capped km, claim amount in AUD, taxpayer details.
  - **Tab 2: `CPK Trip Ledger`** — Date, Start/End Odometer, Distance (km), Business Purpose, Start/End Addresses.

### B. Logbook Method (ITAA 1997 Subdivision 28-F)
* **Logbook Period:** Minimum 12 consecutive weeks to establish a representative business percentage.
* **Odometer Continuity:** Consecutive odometer readings with zero-gap enforcement; any unaccounted gap triggers review flags before export.
* **Running Costs & Receipts:** All vehicle expenses categorized into Fuel, Maintenance, Insurance, Registration, and Tool Transport.
* **Excel Structure (3 Tabs):**
  - **Tab 1: `Tax Summary`** — Business km, Private km, Total km, Business %, Total Vehicle Running Costs, Net Tax Deduction.
  - **Tab 2: `Logbook Trips`** — Date, Odometer Start/End, Business Distance, Purpose, Job Reference, Driver Name.
  - **Tab 3: `Expenses & Receipts`** — Date, Vendor Name, Vendor ABN (checked against ATO mod-89 algorithm), Gross Amount, GST (1/11), Net Amount, Business %, Deductible AUD, Cloud Receipt URL, and SHA-256 Vault Hash.

---

## 3. Tax Software Field Mappings (Zero-Mapping Presets)

### 1-Click HandiTax Form D (Motor Vehicle Expenses Workpaper)
Sheet 1 (`Tax Summary`) contains a dedicated **`1-CLICK HANDITAX FORM D (D1 WORKPAPER RECONCILIATION)`** block that maps 1:1 into HandiTax without copying across disparate sheets:

| HandiTax Field | KiloClaim Worksheet Field | Notes / Statutory Reference |
| :--- | :--- | :--- |
| **Calculation Method** | `Calculation Method` | Cents per KM (Code S) or Logbook Method (Code B) |
| **Business Kilometres** | `Business Kilometres (Capped 5,000 km)` | Strictly capped at 5,000 km for CPK (ITAA 1997 s 28-25) |
| **Logbook Business %** | `Logbook Business Percentage` | `(Business KM / Total Odometer KM) * 100` |
| **Fuel and Oil ($)** | `Fuel and Oil Total ($)` | Gross fuel receipts claimed |
| **Repairs and Maintenance ($)** | `Repairs and Maintenance ($)` | Servicing, mechanical repairs, replacement tyres |
| **Registration and Insurance ($)** | `Registration and Insurance ($)` | State motor vehicle registration & comprehensive/CTP insurance |
| **Net Item D1 Allowable Claim ($)** | `D1 Box A/B Allowable Deduction` | Direct entry value for Box A (CPK) or Box B (Logbook) |

### 1-Click Xero Bills to Pay Import Preset
For practitioners using Xero, KiloClaim delivers a dedicated `KiloClaim_Xero_Bills_Import_Sample.csv` matching Xero's official Bills Import schema. Drag-and-drop directly into **Xero -> Business -> Bills to pay -> Import -> Bills**:

* `*ContactName`: Merchant / Supplier name (e.g. BP Connect, Ultra Tune, Bunnings)
* `*InvoiceNumber`: Receipt Reference / Vault Batch ID
* `*InvoiceDate` & `*DueDate`: Transaction date (YYYY-MM-DD)
* `*Description`: Expense category, Vehicle Rego, and Logbook Business %
* `*UnitAmount` & `Total`: Gross invoice amount
* `*AccountCode`: Standard Australian chart code `489` (Motor Vehicle Expenses) or `493` (Tolls & Travel)
* `*TaxType`: `GST on Expenses` (or `BAS Excluded` for stamp duty/rego components)

---

## 4. Statutory Quarantine & Audit Defense (ITAA 1997 Div 28 & TR 2021/1)

1. **Page 2 Statutory Quarantine Certificate:** The summary PDF includes a formal **"Statutory Non-Business Quarantine & Exclusion Certificate"** explicitly detailing quarantined private kilometres and non-allowable expenses. Auditors and tax agents have immediate mathematical proof that private travel contains 0% claimable deduction.
2. **Cryptographic SHA-256 Audit Seal:** Every certificate and receipt ledger entry is sealed client-side with a deterministic SHA-256 hash, ensuring records cannot be retroactively tampered with.
3. **Nexus Substantiation:** Trips are linked with known client JobSites when geofence dwell time $\ge 120$ seconds, eliminating generic "work travel" claims.
4. **Pre-flight Error Gate:** KiloClaim blocks export if opening/closing odometer readings are missing or if logbook weeks are unaccounted for.

---

## 5. Feedback & Support for Accountants
For questions regarding data schema, custom Practice Manager imports, or bulk tradie onboarding:
- **Email:** `accountants@kiloclaim.com.au`
- **Partner Portal:** `https://partners.kiloclaim.com.au`
