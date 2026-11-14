# Honest Export, Verified Evidence & End-to-End Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate synthetic placeholder fallbacks in exports, separate receipt existence from verification, ensure complete receipt bundles in tax packs, and wire orphaned accounting and purpose services into the live UI flow.

**Architecture:** Refactor `LogbookExportService` and `CpkExportService` to output explicit unstated values (`[Unspecified]`), update `EvidenceReviewService` to flag them as actionable items, refactor `AccountantWorkpaperGenerator` to distinguish between reference, accessible file, and user-verified receipts, bundle `04_Cryptographic_Receipt_Index.csv` in `TaxPackBuilder`, and integrate `PurposeSynthesizerService` and `AccountantWorkpaperGenerator` into the user-facing review and export workflow.

**Tech Stack:** Dart, Flutter, SQLite, Crypto (SHA-256), Archive (ZIP)

**Spec:** `docs/superpowers/specs/2026-11-07-kilotax-strategic-weapons-architecture.md`

## Global Constraints
- Preserve existing dirty checkout and unrelated files.
- Zero synthetic data fabrication: missing fields remain explicitly unstated (`[Unspecified Origin]`, `[Unspecified Destination]`, `[Unspecified Purpose]`).
- All tests must pass: `flutter test`.

## Review Focus
- Trips with null origin, destination, or purpose must be exported as unstated, not "Work Site" or "Client Job Site".
- Expenses with invalid paths must not be counted as substantiated receipts in workpapers.
- The exported ZIP must include all readable receipt files and an index mapping them by SHA-256.
- The review UI must surface unspecified items and offer 1-tap synthesized suggestions requiring explicit user confirmation.

---

### Task 1: Eliminate Synthetic Fallbacks in Export Services
**Files:**
- Modify: `lib/services/engine/logbook_export_service.dart:75-84`
- Modify: `lib/services/engine/cpk_export_service.dart:45-52`
- Test: `test/services/engine/honest_export_service_test.dart`

- [ ] **Step 1: Write failing test verifying that null origins, destinations, and empty purposes export as `[Unspecified Origin]`, `[Unspecified Destination]`, and `[Unspecified Purpose]`.**
- [ ] **Step 2: Run test to verify failure.**
- [ ] **Step 3: Replace `'Work Site'`, `'Client Job'`, and `'Client Job Site'` fallbacks with truthful `[Unspecified ...]` labels.**
- [ ] **Step 4: Run test to verify pass.**

---

### Task 2: 3-State Receipt Verification in Accountant Workpaper
**Files:**
- Modify: `lib/services/engine/accountant_workpaper_generator.dart`
- Test: `test/services/engine/accountant_workpaper_generator_test.dart`

- [ ] **Step 1: Write failing test verifying that workpaper breaks receipts into: attached references, files accessible on disk, and taxpayer-verified items.**
- [ ] **Step 2: Run test to verify failure.**
- [ ] **Step 3: Update `AccountantWorkpaperGenerator.generateWorkpaper` to compute the 3 distinct states and render them clearly in markdown/text.**
- [ ] **Step 4: Run test to verify pass.**

---

### Task 3: Cryptographic Receipt Index & Standardized Bundle in TaxPackBuilder
**Files:**
- Modify: `lib/services/engine/tax_pack_builder.dart`
- Test: `test/tax_pack_builder_test.dart`

- [ ] **Step 1: Write/update test asserting `04_Cryptographic_Receipt_Index.csv` exists inside the generated ZIP with SHA-256 and docket references.**
- [ ] **Step 2: Run test to verify output.**
- [ ] **Step 3: Update `TaxPackBuilder` to format and include `04_Cryptographic_Receipt_Index.csv` alongside the PDF and CSV ledgers.**
- [ ] **Step 4: Run test to verify pass.**

---

### Task 4: Connect End-to-End Pipeline (UI $\to$ Service $\to$ Export)
**Files:**
- Modify: `lib/ui/screens/trips/trip_review_sheet.dart`
- Modify: `lib/ui/screens/evidence/evidence_review_screen.dart`
- Modify: `lib/services/engine/tax_pack_builder.dart`
- Test: `test/services/evidence_review_service_test.dart`

- [ ] **Step 1: Integrate `PurposeSynthesizerService.synthesize` suggestions into `TripReviewSheet` and `EvidenceReviewScreen` with 1-tap confirmation.**
- [ ] **Step 2: Include `AccountantWorkpaperGenerator`'s workpaper document inside `TaxPackBuilder` as `01_Executive_Tax_Workpaper.md` / summary.**
- [ ] **Step 3: Fix distance validation in `test/services/evidence_review_service_test.dart` so all suite tests pass green.**
- [ ] **Step 4: Run full targeted test suite to verify 100% green status.**
