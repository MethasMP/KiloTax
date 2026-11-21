# Reality Check & Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign KiloTax with real-world Australian market reality by eliminating false-promise claims ("audit-proof"), delivering a turnkey Accountant Pilot Pack with test fixtures, and enforcing 100% zero-friction ergonomics for the 5-minute tradie ute test.

**Architecture:** Maintain the pure-Dart offline-first architecture. Strip compliance-violating slogans across UI and notifications. Add a deterministic export generator CLI and sample pack fixture (`assets/samples/accountant_sample_pack/`) with accompanying practitioner documentation (`ACCOUNTANT_PILOT_GUIDE.md`). Build an automated integration verification test simulating the 5-minute ute test workflow.

**Tech Stack:** Flutter / Dart, SQLite, OpenXML (.xlsx via archive package), PDF (pdf package), Crypto SHA-256.

**Spec:** [Google Docs Competitive & Founder Strategy Analysis](https://docs.google.com/document/d/1P7ncruby5STCOTGOkJ3iknPWgQ5f7ylXRcRD7HHtBB8/edit?usp=sharing) and [KiloTax Product Readiness Checklist](file:///Users/methas/.gemini/antigravity/brain/cb06f9f1-1812-4c77-8f3f-eb89b3d507c8/kilotax-product-readiness-checklist.md).

## Global Constraints

- **No False Claims:** Never display "audit-proof", "guaranteed deduction", or "unbreakable chain". Replace with legally defensible terms: "Accountant-Ready", "ATO-Compliant Substantiation", "Defensible Evidence Trail".
- **Accountant-First Interoperability:** All exports must be directly openable and importable into HandiTax, Xero, and Excel without schema transformation errors.
- **Tradie Ute Ergonomics:** Minimum 48x48dp touch targets on every single action; 1-tap gap resolution; offline launch immunity.
- **Pure Dart Stack:** Zero native FFI or foreign toolchains; retain full test suite green pass.

## Review Focus

- The string "AUDIT-PROOF READY" displayed in tax summary badge must be replaced with "ACCOUNTANT READY".
- Year-end notification message must cite "accountant-ready business claim" instead of "audit-proof business claim".
- Accountant Sample Pack generator must output valid .xlsx and .pdf files to `assets/samples/accountant_sample_pack/`.
- Practitioner guide (`ACCOUNTANT_PILOT_GUIDE.md`) must map ITAA 1997 Div 28 statutory fields to HandiTax / Xero fields.
- 5-minute Ute Test integration harness must verify trip capture, receipt OCR attachment, and pre-flight validation in under 2 seconds without network.

---

### Task 1: Sanitize Copywriting & Trust Boundaries

**Files:**
- Modify: `lib/ui/screens/tax/tax_summary_screen.dart:350-360`
- Modify: `lib/services/notifications/notification_service.dart:250-256`
- Test: `test/ui/tax/tax_summary_screen_test.dart`

**Interfaces:**
- Consumes: `AppType`, `AppColor`
- Produces: Sanitized UI badges and notification messages without legal liability

- [x] **Step 1: Write the failing test for sanitized copy in `test/ui/tax/tax_summary_copy_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';

void main() {
  testWidgets('TaxSummaryScreen displays ACCOUNTANT READY badge instead of AUDIT-PROOF',
      (WidgetTester tester) async {
    // Verifies the sanitized compliant string is present and unsafe claims are absent
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/tax/tax_summary_copy_test.dart`
Expected: FAIL (still finding 'AUDIT-PROOF READY')

- [x] **Step 3: Update copy in `tax_summary_screen.dart` and `notification_service.dart`**

Replace:
`'AUDIT-PROOF READY'` with `'ACCOUNTANT READY'` in `tax_summary_screen.dart:353`.
`'maintain your audit-proof business claim'` with `'maintain your accountant-ready business claim'` in `notification_service.dart:253`.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/tax/tax_summary_copy_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/ui/screens/tax/tax_summary_screen.dart lib/services/notifications/notification_service.dart test/ui/tax/tax_summary_copy_test.dart
git commit -m "fix(copy): replace unsafe audit-proof claims with defensible accountant-ready copy"
```

---

### Task 2: Build Accountant Pilot Kit & Sample Artifacts

**Files:**
- Create: `bin/generate_accountant_pilot_pack.dart`
- Create: `ACCOUNTANT_PILOT_GUIDE.md`
- Output: `assets/samples/accountant_sample_pack/KiloTax_Accountant_Pack_CPK_Sample.xlsx`
- Output: `assets/samples/accountant_sample_pack/KiloTax_Accountant_Pack_Logbook_Sample.xlsx`
- Output: `assets/samples/accountant_sample_pack/KiloTax_Tax_Summary_Sample.pdf`
- Test: `test/services/engine/accountant_pilot_pack_test.dart`

**Interfaces:**
- Consumes: `AccountingExportValidator`, `ExcelExportService`, `PdfExportService`
- Produces: Pre-generated, verifiable sample files and practitioner guide for immediate pilot testing with AU tax agents

- [x] **Step 1: Write test verifying sample pack generator generates valid files**

```dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Accountant sample pack files exist and are valid PKZip archives', () async {
    // Assert .xlsx files exist and can be decoded by ZipDecoder
    // Assert .pdf exists and size > 10KB
  });
}
```

- [x] **Step 2: Run test to verify failure**

Run: `flutter test test/services/engine/accountant_pilot_pack_test.dart`
Expected: FAIL (files do not exist yet)

- [x] **Step 3: Implement `bin/generate_accountant_pilot_pack.dart` and generate sample files**

Create generator script that creates a realistic Australian sparkie scenario (Toyota Hilux, 42 business trips between JobSites and Bunnings, 8 fuel/material receipts with valid ABNs and GST), then generates the 3 sample files into `assets/samples/accountant_sample_pack/`.

- [x] **Step 4: Create `ACCOUNTANT_PILOT_GUIDE.md`**

Write practitioner documentation explaining:
1. Executive Summary for CPAs and Tax Agents
2. Data Structure & Sheet Schema (Tax Summary, Trip Ledger, Receipts Vault)
3. HandiTax / Xero Import Mappings
4. Statutory substantiation under ITAA 1997 Div 28 and TR 2021/1
5. How odometer gaps and non-business trips are quarantined

- [x] **Step 5: Run verification test**

Run: `flutter test test/services/engine/accountant_pilot_pack_test.dart`
Expected: PASS

- [x] **Step 6: Commit**

```bash
git add bin/generate_accountant_pilot_pack.dart ACCOUNTANT_PILOT_GUIDE.md assets/samples/accountant_sample_pack/ test/services/engine/accountant_pilot_pack_test.dart
git commit -m "feat(pilot): provide accountant sample pack fixtures and practitioner guide"
```

---

### Task 3: Tradie 5-Minute Ute-Test Verification Harness

**Files:**
- Create: `test/ui/tradie_ute_test_harness_test.dart`
- Modify: `lib/ui/screens/dashboard/task_home_body.dart` (if any touch target is under 48dp)

**Interfaces:**
- Consumes: `TaskHomeBody`, `VehicleSetupFlow`, `GapBridgeSheet`
- Produces: Automated end-to-end regression proving the 5 PM tradie flow takes < 2 seconds and requires zero manual data typing

- [x] **Step 1: Write the Ute Test integration harness**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('5-Minute Ute Test: 1-tap gap review, 1-tap receipt association, and export preflight',
      (WidgetTester tester) async {
    // 1. Launch in offline mode
    // 2. Verify all tap targets have minimumSize: Size(48, 48)
    // 3. Verify Home renders OdometerGapReviewCard and tapping it opens GapBridgeSheet
    // 4. Verify pre-flight validation gates export when odometer gap exists
  });
}
```

- [x] **Step 2: Run test to verify it fails or passes**

Run: `flutter test test/ui/tradie_ute_test_harness_test.dart`

- [x] **Step 3: Fix any UI touch target or flow bottleneck if identified**

Ensure every action button has `minimumSize: const Size(48, 48)` and clear haptic feedback.

- [x] **Step 4: Re-run test to verify 100% green pass**

Run: `flutter test test/ui/tradie_ute_test_harness_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add test/ui/tradie_ute_test_harness_test.dart lib/ui/screens/dashboard/task_home_body.dart
git commit -m "test(ute): add 5-minute tradie ute test integration harness and touch target verification"
```
