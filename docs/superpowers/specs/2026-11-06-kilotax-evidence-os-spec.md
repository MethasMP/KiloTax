# KiloTax: The Tax Evidence OS for Australian Tradies
## Technical Specification & Blue Ocean Architecture

### 1. Vision & Strategic Positioning
KiloTax is NOT another generic mileage tracker. While incumbents (Driversnote, Travel Logs) focus on simple point-to-point GPS logs, and challengers (CarSavvy) offer broad consumer car management, KiloTax is built as **"The Tax Evidence OS for Australian Tradies & Sole Traders"**.

Targeting 1% (4,000 users) of Australia's ~404,000 construction tradespeople, KiloTax creates an unbreakable, audit-proof deduction chain connecting:
`GPS Trip -> Bunnings/Ampol Expense Receipt -> Job Site -> ATO Compliant Workpaper`.

### 2. The 101 -> 102 -> 103 Value Evolution
- **The 101 (Reverse & Synthesize):** Use REA to deconstruct the SQLite schema and API sync models of CarSavvy, Driversnote, and Logmaster (EWD), synthesizing them into a Unified Tradie Evidence Schema without copying flaws.
- **The 102 (Forensic Gap Audit & Data Healing):** When users or accountants import old reports or connect existing data, run a forensic tax simulation that flags unclaimed deductions (e.g., missing Bunnings stop-points, unlinked fuel expenses) and calculates missed tax refunds.
- **The 103 (Accountant Mandate Flywheel):** Produce CPA/CA ANZ-grade tax workpapers ready for 1-tap export to Xero/MYOB, turning accountants into an organic salesforce.

### 3. Core Engine Architecture
1. **Evidence Graph Engine (`src/core/evidence_graph.ts`):**
   - Nodes: `Trip`, `Receipt`, `JobSite`, `Vehicle`
   - Edges: `CORRELATED_WITH`, `OCCURRED_AT`, `CHARGED_TO`
2. **Reverse Extraction & Migration Adapter (`src/importers/universal_adapter.ts`):**
   - AST / Schema normalizer for Driversnote CSV/JSON, CarSavvy SQLite export, and generic ATO CSVs.
3. **Forensic Audit Analyzer (`src/audit/tax_risk_analyzer.ts`):**
   - Detects ATO audit red flags: gap in odometer logs, unevidenced business trips, missing receipt substantiations.
4. **Accountant Workpaper Generator (`src/export/accountant_workpaper.ts`):**
   - Produces structured ATO Logbook Method documentation with embedded receipt proof.
