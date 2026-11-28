# EDE Specification: Accountant Export Deliverables (PDF & Multi-Tab Excel)
## Scope: Tier 1 (Financial/Tax Engine & File I/O)

### Business & Domain Context
Under ATO guidelines (ITAA 1997 Division 28 & Subdivision 28-F, TR 97/11), tax agents (accountants) require mathematically immutable, audit-proof, and clean deliverables without junk or unverified claims.
KiloClaim provides exactly 2 files:
1. One A4 PDF (Master Report / Summary Declaration)
2. One Multi-Tab OpenXML Excel Workbook (`.xlsx`)

### Inviolable Invariants (Tier A & Tier B)
1. **Invariant 1: Exact File Count & Formats (Anti-Junk/Anti-CSV)**
   - CPK and Logbook must deliver exactly 2 files: `[Vehicle]_Summary_Declaration.pdf` (or `Master_Tax_Report.pdf`) + `[Vehicle]_Tax_Ledger.xlsx`.
   - Zero `.csv` files and zero unattached raw image bundles in deliverable packages.
2. **Invariant 2: OpenXML Specification Compliance**
   - The `.xlsx` workbook must be a valid PKZip archive containing `[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml`, and worksheet XMLs.
   - All cell values must be sanitized against XML illegal characters (`0x00-0x08`, `0x0B-0x0C`, `0x0E-0x1F`).
3. **Invariant 3: Multi-Tab Structure & Integrity**
   - For CPK: Exactly 2 worksheets (`Tax Summary` and `CPK Trip Ledger`).
   - For Logbook: Exactly 3 worksheets (`Tax Summary`, `Logbook Trips`, and `Expenses & Receipts`).
4. **Invariant 4: Statutory Tax Arithmetic (Single Source of Truth)**
   - CPK deduction = min(Business KM, 5000) * Rate.
   - Logbook deduction = sum(Eligible Car Running Costs) * Business % + 100% * Direct Work Tolls/Parking.
   - Trade materials (Bunnings/Reece under ITAA 1997 s 8-1) must be isolated from car running costs.
5. **Invariant 5: ATO Required Fields Presence**
   - Both PDF and Excel Tab 1 MUST present Taxpayer Name, ABN, Vehicle Rego, Financial Year, Opening Odometer, Closing Odometer, and Deductible Claim.
   - Tab 3 (Expenses) MUST contain `Merchant_Name`, `Merchant_ABN`, `Gross_Amount_AUD`, `GST_Amount_AUD`, `Net_Amount_AUD`, `Business_Percent`, `Deductible_Amount_AUD`, and `Cloud_Receipt_URL`.
6. **Invariant 6: Division 28-C Running Cost Exclusion**
   - Under CPK method, fuel, maintenance, or running expenses must NEVER be factored into the deduction or attached as evidence.
