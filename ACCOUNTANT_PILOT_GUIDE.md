# KiloTax — Accountant Pilot & Substantiation Guide
**For Australian Tax Practitioners, CPAs, & Registered Tax Agents**
**Statutory Basis:** ITAA 1997 Division 28 (ITAA 1997 Div 28) & ATO Ruling TR 2021/1

---

## 1. Executive Summary for Accountants

KiloTax is designed as a **Tax Evidence Operating System** for Australian sole traders and tradies. 
Rather than providing unstructured CSV dumps or generic mileage trackers, KiloTax exports a strictly standardized **2-File Accountant Delivery Pack**:

1. **`KiloTax_Tax_Summary_Sample.pdf`**: A formal summary declaration containing taxpayer identity (Name, ABN), vehicle details, opening/closing odometer readings, business percentage, and claim totals with a system audit timestamp.
2. **`KiloTax_Accountant_Pack_[CPK|Logbook]_Sample.xlsx`**: An OpenXML multi-tab ledger with pre-formatted cell types (numeric numbers, ISO dates, text) ready for direct copy-paste or macro ingestion into **HandiTax**, **Xero Practice Manager**, or **MYOB**.

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

## 3. Tax Software Field Mappings

### HandiTax Form D (Motor Vehicle Expenses)
| HandiTax Field | KiloTax Source | Notes |
| :--- | :--- | :--- |
| **Calculation Method** | `Tax Summary!B4` | Cents per km (C) or Logbook (L) |
| **Vehicle Make / Model / Rego** | `Tax Summary!B6:B8` | e.g., Toyota HiLux (TRADIE-CPK) |
| **Business Kilometres** | `Tax Summary!B10` | Capped at 5,000 for CPK; Total Business km for Logbook |
| **Business Percentage (%)** | `Tax Summary!B11` | Logbook Method only |
| **Fuel and Oil** | `Expenses & Receipts (Cat = Fuel)` | Sum of Net + GST claimed |
| **Repairs and Maintenance** | `Expenses & Receipts (Cat = Maintenance)` | Sum of Net + GST claimed |
| **Total Motor Vehicle Claim** | `Tax Summary!B15` | Total Deductible AUD |

### Xero Practice Manager / General Ledger
* **Account 449 (Motor Vehicle Expenses):** Total from `Tax Summary!B15`
* **GST on Expenses:** Accurately isolated in column `GST_Amount_AUD` on Tab 3 for BAS reconciliation.

---

## 4. Evidentiary Rigor & Audit Defense (TR 2021/1)

1. **Nexus Substantiation:** Trips are linked with known client JobSites when geofence dwell time $\ge 120$ seconds, eliminating generic "work travel" claims.
2. **Receipt Cryptographic Integrity:** Every receipt in Tab 3 carries an immutable `Image_SHA256` hash and `AuditEvidence_Id` backed by an encrypted storage vault with a 5-year retention guarantee (1,825 days).
3. **Pre-flight Error Gate:** KiloTax blocks the export button if opening/closing odometer readings are missing or if logbook weeks are unaccounted for.

---

## 5. Feedback & Support for Accountants
For questions regarding data schema, custom Practice Manager imports, or bulk tradie onboarding:
- **Email:** `accountants@kilotax.com.au`
- **Partner Portal:** `https://partners.kilotax.com.au`
