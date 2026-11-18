# High-Accuracy Receipt Extraction Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate KiloTax's receipt OCR extraction accuracy to $\ge 95\%$ on Australian receipts by anchoring extraction to ATO GST mathematical invariants, 2D bounding-box horizontal raycasting, and ABN Modulus-89 validation.

**Architecture:** 
1. **ATO Tax Mathematical Validator:** Independent consensus engine verifying $\text{Total} \approx 11 \times \text{GST}$ across numerical candidates.
2. **Spatial Key-Value Associator:** Projects horizontal rays from identified anchor labels (`TOTAL`, `INVOICE`, `DATE`, `ABN`) across `ReceiptOcrBlock` bounding boxes to isolate associated values.
3. **ABN Modulus-89 Engine:** Algorithmic validator using ATO weighting coefficients `[10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]` to guarantee ABN authenticity and eliminate phone/order number false positives.
4. **Confidence & Fallback Policy:** Flags edge cases where mathematical consensus fails, cleanly routing to an optional Tier-2 Multimodal Vision LLM fallback.

**Tech Stack:** Dart, Flutter, `google_mlkit_text_recognition`, existing `ReceiptIntelligenceService`.

---

## Global Constraints
- Must remain 100% offline-capable for Tier-1 local processing.
- Must not break existing `ReceiptIntelligenceService.analyseText` signatures or existing test suites.
- Latency budget for Tier-1 local extraction must remain under 350ms on mobile.
- Zero new external runtime package dependencies added to `pubspec.yaml` for Tier-1.

---

## Review Focus
1. **Single-item non-taxable / mixed GST receipts:** Invoices where only partial items attract GST (e.g., mixed fuel + convenience items) must not fail parsing when $\text{Total} \neq 11 \times \text{GST}$.
2. **Thermal paper noise:** OCR outputs with missing decimal points (e.g. `12450` instead of `124.50`) or alphanumeric substitutions (`$4B.50` instead of `$48.50`).
3. **Date disambiguation:** Ensuring Australian `DD/MM/YYYY` is strictly favored over US `MM/DD/YYYY` format.
4. **Bounding box orientation:** Ensuring receipts photographed in non-standard rotation or multi-column layouts don't cross-contaminate line items.
5. **ABN checksum edge cases:** Validating 11-digit numbers that match ABN regex format but fail the ATO weighted Mod-89 check.

---

## File Structure & Responsibilities

| File Path | Responsibility |
| :--- | :--- |
| `lib/services/ocr/australian_tax_validator.dart` | Pure math validator for ATO GST consistency ($Total \approx 11 \times GST$) and ABN Mod-89 checksum algorithm. |
| `lib/services/ocr/spatial_receipt_parser.dart` | 2D Bounding-Box vector matching: pairs anchor text blocks with right-adjacent value blocks. |
| `lib/services/ocr/receipt_intelligence_service.dart` | Integrates `AustralianTaxValidator` and `SpatialReceiptParser` into the existing analysis pipeline. |
| `test/services/ocr/australian_tax_validator_test.dart` | Unit tests for GST cross-validation and ABN Mod-89 calculation. |
| `test/services/ocr/spatial_receipt_parser_test.dart` | Unit tests for 2D bounding-box spatial association with synthetic receipt geometries. |
| `test/services/ocr/receipt_intelligence_accuracy_test.dart` | End-to-end regression tests verifying extraction of problematic receipts (Bunnings, BP, Shell). |

---

## Tasks

- [ ] **Task 1: ATO Tax & ABN Modulus-89 Algorithmic Engine**
  - **Context:** Currently, ABN is extracted via a 11-digit regex which frequently mistakes phone numbers, tax invoice IDs, or order bar codes for ABNs. GST is extracted independently of Total.
  - **Deliverable:** `lib/services/ocr/australian_tax_validator.dart` with passing unit tests.
  - **Steps:**
    - [ ] Step 1: Write unit tests in `test/services/ocr/australian_tax_validator_test.dart` testing:
      - Valid ABN checksum verification (e.g. Bunnings ABN `26 008 672 179`).
      - Rejection of invalid ABNs (e.g. arbitrary 11-digit phone numbers).
      - GST 10% cross-validation ($\text{Total} \approx 11 \times \text{GST} \pm 0.02$).
    - [ ] Step 2: Run tests to confirm failure: `flutter test test/services/ocr/australian_tax_validator_test.dart`.
    - [ ] Step 3: Implement `AustralianTaxValidator`:
      - Implement `bool isValidAbn(String rawAbn)` subtracting 1 from first digit, applying weights `[10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]`, and modulo 89 == 0.
      - Implement `bool isGstConsistent(double total, double gst, {double tolerance = 0.05})`.
      - Implement `double? deduceTotalFromGst(double gst)` and `double? deduceGstFromTotal(double total)`.
    - [ ] Step 4: Run tests and ensure 100% pass: `flutter test test/services/ocr/australian_tax_validator_test.dart`.

- [ ] **Task 2: Spatial 2D Bounding-Box Key-Value Association**
  - **Context:** `ReceiptOcrBlock` stores `bounds` `[left, top, right, bottom]`, but `ReceiptReadingOrder.assemble` flattens them into a single string, losing line horizontal proximity.
  - **Deliverable:** `lib/services/ocr/spatial_receipt_parser.dart` which associates horizontal label $\to$ value pairs.
  - **Steps:**
    - [ ] Step 1: Write unit tests in `test/services/ocr/spatial_receipt_parser_test.dart` using mock `ReceiptOcrBlock` inputs with varying bounding box coordinates.
    - [ ] Step 2: Run tests to confirm failure.
    - [ ] Step 3: Implement `SpatialReceiptParser`:
      - Filter anchor candidates matching `TOTAL`, `GST`, `DATE`, `INVOICE`, `ABN`.
      - For each anchor block, search for target blocks situated horizontally right within `[top - 0.5 * h, bottom + 0.5 * h]` and bounded within a max horizontal gap.
      - Extract and pair raw candidate values before string flattening.
    - [ ] Step 4: Verify all spatial pairing tests pass.

- [ ] **Task 3: Integration into `ReceiptIntelligenceService` & Consensus Upgrades**
  - **Context:** Wire `AustralianTaxValidator` and `SpatialReceiptParser` into `ReceiptIntelligenceService.analyseText` without breaking callers.
  - **Deliverable:** Updated `lib/services/ocr/receipt_intelligence_service.dart` with heightened confidence metrics and fallback signaling.
  - **Steps:**
    - [ ] Step 1: Write end-to-end regression tests in `test/services/ocr/receipt_intelligence_accuracy_test.dart` using real-world messy OCR transcripts (BP, Shell, Bunnings, Ampol).
    - [ ] Step 2: Run tests and record initial baseline failures.
    - [ ] Step 3: Refactor `ReceiptIntelligenceService`:
      - Incorporate spatial bounding box predictions if blocks are available.
      - Pass extracted candidates through `AustralianTaxValidator.isGstConsistent`.
      - If Total is corrupted (e.g. decimal missing) but GST is crisp, auto-repair Total via `deduceTotalFromGst`.
      - Validate ABN with Mod-89 check; discard invalid candidate numbers.
      - Set `confidence >= 0.95` when GST math and ABN checksum validate cleanly.
    - [ ] Step 4: Run regression test suite and verify accuracy lift: `flutter test test/services/ocr/`.

- [ ] **Task 4: Tier-2 Multimodal Vision LLM Fallback Hook**
  - **Context:** For damaged/crumpled receipts where `confidence < 0.78` or mathematical consensus fails, expose an interface for background multimodal parsing.
  - **Deliverable:** `lib/services/ocr/receipt_fallback_engine.dart` abstract interface & wiring in `ReceiptWorkflowPolicy`.
  - **Steps:**
    - [ ] Step 1: Define `ReceiptFallbackEngine` interface with `Future<ReceiptOcrResult?> parseImage(String imagePath)`.
    - [ ] Step 2: Implement test harness / mock fallback engine in unit tests.
    - [ ] Step 3: Wire into `ReceiptWorkflowPolicy` to dispatch only when `!result.isHighConfidence`.
    - [ ] Step 4: Run existing test suites across `test/services/receipts/` to verify zero regression.
