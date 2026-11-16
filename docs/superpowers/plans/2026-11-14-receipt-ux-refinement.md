# Receipt UX Refinement (Items 1, 2, 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Streamline Tradie receipt processing by adding 1-tap item-level private allocation presets, a high-speed Single Shot scanning mode with 3-second quick confirm, and automatic trip suggestions using spatio-temporal matching (Evidence Graph).

**Architecture:** 
1. **Split Editor Context Actions**: Enhance `ReceiptIntelligenceService` and `ExpenseDetailScreen` allocation items to detect personal keywords (e.g., Ice break, Coke, Snack) and display a 1-tap "Mark as Private" chip.
2. **Evidence Graph Auto-Wiring**: Integrate `EvidenceAutoMatchEngine` into `ExpenseDetailScreen` initialization to automatically find the best matching trip based on time & GPS proximity, populating `initialLinkedTripId` and `autoMatchReason`.
3. **Scan Mode Split (Single Shot vs Shoebox)**: Refactor `ScanReceiptScreen` to detect whether 1 page was scanned with high OCR confidence (>0.90) to immediately navigate directly to Quick Review (`ExpenseDetailScreen`), reserving `ReceiptInboxScreen` for batch/multi-page captures.

**Tech Stack:** Flutter, Dart, Lucide Icons, Flutter Test

**Spec:** User UX Pain Points Specification (Items 1, 2, 4 from audit image).

## Global Constraints
- ATO Compliance: Allocations must balance 100% of the receipt total without rounding penny leakage.
- Zero-Friction Tradie Ergonomics: 1-tap action over form typing.
- Non-Destructive: Do not break existing batch inbox workflows or draft persistence.

## Review Focus
1. OCR single line text contains lowercase/uppercase personal keywords (e.g., "COCA COLA 600ML", "ICE BREAK 500ML").
2. Single Shot mode fallback when camera or OCR produces low confidence (<0.90) or multi-page scans.
3. Spatio-temporal matching with missing GPS (fallback to time-only window matching).
4. Unsaved edits in Split Editor when toggling private items back and forth.
5. Preserving existing batch inbox multi-page capture functionality.

---

### Task 1: 1-Tap "Mark as Private" for Mixed Items in Split Editor (Item 1)

**Files:**
- Modify: `lib/services/ocr/receipt_intelligence_service.dart`
- Modify: `lib/ui/screens/expenses/expense_detail_screen.dart`
- Create: `test/services/ocr/receipt_intelligence_personal_items_test.dart`
- Create: `test/ui/split_editor_mark_private_test.dart`

**Interfaces:**
- Consumes: `ReceiptAllocation`, `AllocationPurpose`
- Produces: `ReceiptIntelligenceService.isLikelyPersonalItem(String description) -> bool`

- [ ] **Step 1: Write unit tests for keyword detection on line items**
  Add test checking `ReceiptIntelligenceService.isLikelyPersonalItem` detects "Ice break", "Coke", "Snack", "Red Bull", "Chocolate", "Sandwich", "Chips".

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/services/ocr/receipt_intelligence_personal_items_test.dart`

- [ ] **Step 3: Implement `isLikelyPersonalItem` in `ReceiptIntelligenceService`**
  Add regex matcher for Australian convenience/beverage/personal snack terms.

- [ ] **Step 4: Update `ExpenseDetailScreen` allocation card UI**
  If an allocation item is not already marked as `AllocationPurpose.private` and its description matches `isLikelyPersonalItem`, display an inline action chip `[Mark as Private]` that immediately sets `purpose: AllocationPurpose.private` with haptic feedback.

- [ ] **Step 5: Write widget test and verify**
  Run: `flutter test test/ui/split_editor_mark_private_test.dart`
  Expected: PASS

- [ ] **Step 6: Commit**
  ```bash
  git add lib/services/ocr/receipt_intelligence_service.dart lib/ui/screens/expenses/expense_detail_screen.dart test/
  git commit -m "feat(ux): add 1-tap mark as private chip for detected personal items in split editor"
  ```

---

### Task 2: Wire `EvidenceAutoMatchEngine` to Auto-Suggest Matching Trips (Item 4)

**Files:**
- Track & Modify: `lib/services/evidence/evidence_auto_match_engine.dart`
- Modify: `lib/state/app_state.dart`
- Modify: `lib/ui/screens/expenses/expense_detail_screen.dart`
- Test: `test/evidence_auto_match_engine_test.dart`
- Create: `test/ui/expense_detail_auto_suggest_trip_test.dart`

**Interfaces:**
- Consumes: `EvidenceAutoMatchEngine.findBestMatchingTrip(...) -> AutoMatchResult?`
- Produces: Auto-suggested `initialLinkedTripId` and `autoMatchReason` passed during expense initialization.

- [ ] **Step 1: Verify existing unit tests for `EvidenceAutoMatchEngine` pass**
  Run: `flutter test test/evidence_auto_match_engine_test.dart`
  Expected: PASS

- [ ] **Step 2: Implement auto-match integration in `ExpenseDetailScreen.initState`**
  If `_linkedTripId` is null and `_suggestedTripId` is null, automatically run `EvidenceAutoMatchEngine.findBestMatchingTrip` against `widget.appState.trips` using receipt date/time and category. Populate `_suggestedTripId` and `_autoMatchReason` so the suggestion banner appears automatically.

- [ ] **Step 3: Write widget test for auto-suggestion banner**
  Verify the banner appears with text e.g., "Matched work trip ... 30 mins after trip" with a 1-tap checkbox to accept.

- [ ] **Step 4: Run tests and commit**
  ```bash
  git add lib/services/evidence/evidence_auto_match_engine.dart lib/ui/screens/expenses/expense_detail_screen.dart test/
  git commit -m "feat(evidence-graph): auto-suggest matching trips in expense detail screen"
  ```

---

### Task 3: Single Shot Mode vs Multi/Shoebox Mode in Scanner Flow (Item 2)

**Files:**
- Modify: `lib/ui/screens/expenses/scan_receipt_screen.dart`
- Create: `test/ui/scan_receipt_flow_mode_test.dart`

**Interfaces:**
- Consumes: `DocumentScannerService.scanBatchDocuments`, `ReceiptOcrEngine`, `ReceiptIntelligenceService`
- Produces: Direct navigation to `ExpenseDetailScreen` (Single Shot) if 1 image scanned with high confidence (>0.90), or `ReceiptInboxScreen` (Multi/Shoebox) if >1 images or bulk batch.

- [ ] **Step 1: Write widget test for Single Shot vs Shoebox navigation**
  - Case A: 1 image returned -> runs OCR in background, if confidence >= 0.90 -> navigates directly to `ExpenseDetailScreen`.
  - Case B: >1 images returned -> navigates to `ReceiptInboxScreen`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/ui/scan_receipt_flow_mode_test.dart`

- [ ] **Step 3: Implement mode switching logic in `ScanReceiptScreen._processBatchImages`**
  - If `imagePaths.length == 1`:
    Show quick status, run `ReceiptOcrEngine.processImage()`.
    If confidence >= 0.90, navigate directly to `ExpenseDetailScreen` with extracted details & suggested trip.
    If OCR confidence is low or OCR fails, fallback gracefully to `ExpenseDetailScreen` or inbox.
  - If `imagePaths.length > 1`:
    Navigate to `ReceiptInboxScreen` for batch processing.

- [ ] **Step 4: Run tests to verify they pass**
  Run: `flutter test test/ui/scan_receipt_flow_mode_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/ui/screens/expenses/scan_receipt_screen.dart test/ui/scan_receipt_flow_mode_test.dart
  git commit -m "feat(ux): implement single shot mode for 1-tap quick confirm vs shoebox batch inbox"
  ```
