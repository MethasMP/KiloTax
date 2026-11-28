# Phase 2: Amplify the Signal (The Steve Jobs Magic Moments)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn KiloClaim's core value proposition into visceral "Magic Moments" for the exhausted Tradie by connecting spatial bounding boxes directly into single-shot camera capture, providing instant tactile feedback, and making Accountant Export a 1-tap joy.

**Architecture:**
1. **End-to-End Spatial OCR Plumbing:** Wire `extraction.blocks` directly from `ReceiptOcrEngine` into `_intelligence.analyseText(extraction.text, blocks: extraction.blocks)` inside [scan_receipt_screen.dart](file:///Users/methas/Desktop/DriveLog/lib/ui/screens/expenses/scan_receipt_screen.dart).
2. **Instant Sensory Feedback (The Snap Magic):** Provide tactile haptic acknowledgment (`HapticFeedback.heavyImpact()`) and instant recognition badge when OCR achieves high confidence ($\ge 0.95$).
3. **Accountant Handoff Polish:** Elevate share sheet dispatch and audit status reassurance in `PreFlightReviewScreen` and `AccountantHandoffService`.

**Tech Stack:** Flutter, Dart, `SpatialReceiptParser`, `AustralianTaxValidator`, `ScanReceiptScreen`.

---

## Global Constraints
- Must maintain 100% test pass rate across `test/ui/scan_receipt_auto_flow_test.dart` and `test/ui/scan_receipt_flow_mode_test.dart`.
- Zero latency increase in single-shot receipt scanning.

---

## Tasks

- [x] **Task 1: Connect 2D Spatial Blocks into `ScanReceiptScreen` & `ReceiptInboxScreen`**
  - **Context:** In Task 2 & 3 we built `SpatialReceiptParser` and added `blocks` parameter to `analyseText`, but `ScanReceiptScreen` was still calling `analyseText(extraction.text)` without passing `blocks: extraction.blocks`.
  - **Deliverable:** Wire `extraction.blocks` in `lib/ui/screens/expenses/scan_receipt_screen.dart` and `lib/ui/screens/expenses/receipt_inbox_screen.dart`.
  - **Verification:** `test/ui/scan_receipt_flow_mode_test.dart` passes with high confidence.

- [x] **Task 2: Implement Instant Tactile & Magic Status Notification**
  - **Context:** When the Tradie snaps a receipt, they need immediate certainty that their tax deduction was locked in without friction.
  - **Deliverable:** Haptic confirmation on high-confidence scan (`HapticFeedback.heavyImpact()`) and refined processing HUD in `lib/ui/screens/expenses/scan_receipt_screen.dart`.
  - **Verification:** Unit tests passing cleanly (66/66 tests passed across UI and OCR test suites).

- [x] **Task 3: Polish Pre-Flight Accountant Handoff Experience**
  - **Context:** Guarantee that the accountant deliverables package is crisp, immediate, and free of confusion before sending.
  - **Deliverable:** Verified clean export flow in `lib/ui/screens/tax/pre_flight_review_screen.dart` with tactile haptic trigger and `100% ATO Compliant` badge.
  - **Verification:** `test/ui/pre_flight_review_screen_test.dart` & `test/ui/tax_pack_share_flow_test.dart` passing 100% (7/7 tests passed).
