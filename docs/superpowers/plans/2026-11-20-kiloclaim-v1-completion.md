# KiloClaim v1.0 Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all Phase 3-5 gaps in the KiloClaim product readiness checklist so that an Australian tradie can record a work trip, link it to job and receipts, and produce an ATO-compliant export pack that an accountant can use without follow-up questions.

**Architecture:** Evidence-first Flutter/Dart app (offline SQLite → Supabase sync). Engine layer in `lib/services/engine/` owns all business logic. UI layer in `lib/ui/screens/` consumes AppState via Provider. No business logic in widgets.

**Tech Stack:** Flutter (Dart), SQLite (drift), Supabase (Postgres + Storage), Provider, pdf, excel (OpenXML), SHA-256 crypto

**Spec:**
- `PRODUCT.md` — product principles and workflow quality standard
- `specs/evidence_graph_contract.md` — invariants INV-A01..A05, INV-B01..B05
- `specs/accountant_export_deliverables_spec.md` — invariants 1-6 for PDF + xlsx
- `.audit/receipt-flow-2026-11-15/RESULT.md` — receipt flow audit result
- `docs/superpowers/plans/2026-11-20-kiloclaim-v1-completion.md` (this file)

## Global Constraints

- Flutter stable channel; Dart null-safe, no dynamic unless at JSON boundaries
- Offline-first: every capture writes SQLite before attempting Supabase
- RLS: `user_id = auth.uid()` on every Supabase write; RLS must be tested
- Minimum 48x48dp touch targets on all interactive elements
- No business logic inside StatefulWidget or build() methods
- ATO CPK cap: `min(businessKm, 5000) × rate`; Logbook: `sum(runningCosts) × businessPct`
- SHA-256 must match: `clientHash == storageSha256` before marking upload complete
- No CSV exports; exactly 2 files per export: PDF + xlsx
- Trade materials (tools/Bunnings) must never appear in CPK car-running cost column

## Review Focus

Five failure modes most likely to bite a real user:

1. **Export opens corrupted in Excel** — xlsx PKZip archive malformed; test: open generated file with `python -c "import zipfile; zipfile.ZipFile('output.xlsx').testzip()"` after every export run.
2. **CPK deduction exceeds \$5,000 km cap** — arithmetic bypass; test: trip set with 6,000 business km must yield `deduction = 5000 × rate`.
3. **Receipt linked to wrong user's trip** — RLS bypass; test: user B token cannot SELECT from `trip_evidence_links` where `user_id = user_A`.
4. **Auto-match fires on trip from wrong day** — temporal window bug; test: receipt timestamp `trip.date + 5h` must NOT auto-link.
5. **Export stalls without progress feedback** — UI freeze during PDF/xlsx generation; test: 500ms after tapping Export, a progress indicator must be visible before the file appears.

---

## Squad Alpha (Team A) — Evidence Graph Engine
**Owner scope:** `lib/services/tracking/job_site_geofence_engine.dart`, auto-matching logic, `lib/ui/screens/workflow/`

### Task A1: JobSite Geofence Auto-Tag (INV-B03)

**Files:**
- Modify: `lib/services/tracking/job_site_geofence_engine.dart`
- Modify: `lib/services/tracking/autonomous_trip_detector.dart`
- Test: `test/services/tracking/job_site_geofence_engine_test.dart`

**Interfaces:**
- Consumes: `Trip { id, startLat, startLng, endLat, endLng, stoppedAt, stoppedDuration }`
- Produces: `GeofenceMatch? matchTripToJobSite(Trip trip, List<JobSite> sites)` → `{ jobSiteId, confidenceScore, associationMethod: 'spatial_geofence' }`

- [ ] **Step 1: Write failing test for dwell ≥ 120s within radius**
```dart
test('tags trip when dwell ≥ 120s inside geofence', () {
  final engine = JobSiteGeofenceEngine();
  final trip = makeTripWithDwell(lat: -33.865, lng: 151.209, seconds: 180);
  final site = JobSite(lat: -33.865, lng: 151.209, radiusMeters: 150);
  expect(engine.matchTripToJobSite(trip, [site])?.confidenceScore, greaterThan(0.0));
});
test('does NOT tag trip when dwell < 120s', () {
  final engine = JobSiteGeofenceEngine();
  final trip = makeTripWithDwell(lat: -33.865, lng: 151.209, seconds: 90);
  final site = JobSite(lat: -33.865, lng: 151.209, radiusMeters: 150);
  expect(engine.matchTripToJobSite(trip, [site]), isNull);
});
```
- [ ] **Step 2:** Run `flutter test test/services/tracking/job_site_geofence_engine_test.dart` → expect FAIL "matchTripToJobSite not implemented"
- [ ] **Step 3:** Implement `matchTripToJobSite` using WGS84 geodesic distance (already in `wgs84_geodesic_engine.dart`). Check `stoppedDuration >= 120` and `geodesicDistance(trip.endLat, trip.endLng, site.lat, site.lng) <= site.radiusMeters`.
- [ ] **Step 4:** Run test → expect PASS
- [ ] **Step 5:** `git commit -m "feat(geofence): auto-tag trip to job site when dwell ≥ 120s (INV-B03)"`

### Task A2: Receipt Auto-Link (INV-B01 + INV-B02)

**Files:**
- Modify: `lib/services/engine/evidence_engine.dart`
- Test: `test/services/engine/evidence_engine_match_test.dart`

**Interfaces:**
- Consumes: `Receipt { id, capturedAt, merchantLat?, merchantLng? }`, `Trip { id, date, originLat, originLng, destLat, destLng }`
- Produces: `List<ReceiptMatch> autoLinkReceipts(List<Receipt>, List<Trip>)` → each match has `{ tripId, receiptId, confidenceScore, associationMethod }`

- [ ] **Step 1: Write failing tests**
```dart
test('links receipt within 15km and 4h of trip', () { ... });
test('does NOT link receipt 16km from trip route', () { ... });
test('does NOT link receipt trip.date + 5h', () { ... });
test('link is idempotent for same (tripId, receiptId)', () { ... }); // INV-B04
```
- [ ] **Step 2:** Run → expect FAILs
- [ ] **Step 3:** Implement `autoLinkReceipts`. Use `wgs84_geodesic_engine.dart` for distance. Temporal window: `receipt.capturedAt` must be within `trip.date - 4h .. trip.date + 4h`. Distance: geodesic to nearest of `(originLat, originLng)` or `(destLat, destLng)` <= 15,000m.
- [ ] **Step 4:** Run → expect all PASS
- [ ] **Step 5:** `git commit -m "feat(evidence): receipt auto-link by spatial+temporal bounds (INV-B01, B02, B04)"`

### Task A3: Unlinked Trip UI Indicator

**Files:**
- Modify: `lib/ui/screens/trips/trip_detection_screen.dart`
- Modify: `lib/ui/screens/trips/widgets/` (add `trip_evidence_badge.dart`)

**Interfaces:**
- Consumes: `Trip.evidenceLinks: List<TripEvidenceLink>` (already in domain model or add field)
- Produces: `TripEvidenceBadge(trip)` widget — shows amber badge "Needs evidence" when `trip.evidenceLinks.isEmpty`

- [ ] **Step 1:** Widget test: unlinked trip renders amber "Needs evidence" badge; linked trip renders no badge
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement `TripEvidenceBadge` — amber container, min 48dp tap target, tapping opens `WorkflowScreen` for that trip
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** `git commit -m "feat(ui): amber evidence badge on unlinked trips"`

---

## Squad Beta (Team B) — Export Verification
**Owner scope:** `lib/services/engine/pdf_export_service.dart`, `openxml_workbook_builder.dart`, `cpk_export_service.dart`, `logbook_export_service.dart`

### Task B1: CPK Export Arithmetic Verification

**Files:**
- Test: `test/services/engine/cpk_export_service_test.dart`
- Modify: `lib/services/engine/cpk_export_service.dart` (fix if failing)

**Interfaces:**
- Consumes: `CpkExportInput { businessKm, ratePerKm, trips: List<Trip> }`
- Produces: `CpkExportResult { deductionAud, cappedKm }` where `cappedKm = min(businessKm, 5000)`

- [ ] **Step 1: Write tests with exact ATO arithmetic**
```dart
test('CPK deduction caps at 5000km', () {
  final result = CpkExportService().calculate(businessKm: 6000, ratePerKm: 0.88);
  expect(result.cappedKm, 5000);
  expect(result.deductionAud, closeTo(4400.00, 0.01));
});
test('CPK deduction does not cap under 5000km', () {
  final result = CpkExportService().calculate(businessKm: 3000, ratePerKm: 0.88);
  expect(result.cappedKm, 3000);
  expect(result.deductionAud, closeTo(2640.00, 0.01));
});
test('fuel/maintenance costs not included in CPK deduction', () {
  final result = CpkExportService().calculate(
    businessKm: 3000, ratePerKm: 0.88,
    runningCosts: [VehicleExpense(category: 'fuel', amount: 500)],
  );
  expect(result.deductionAud, closeTo(2640.00, 0.01)); // unchanged
});
```
- [ ] **Step 2:** Run → record PASS or FAIL; if FAIL, fix arithmetic in `cpk_export_service.dart`
- [ ] **Step 3:** Confirm all 3 PASS
- [ ] **Step 4:** `git commit -m "test(export): pin CPK arithmetic including 5000km cap and running-cost exclusion"`

### Task B2: xlsx PKZip Validity Test

**Files:**
- Test: `test/services/engine/openxml_workbook_builder_test.dart`
- Modify: `lib/services/engine/openxml_workbook_builder.dart` (fix if needed)

**Interfaces:**
- Consumes: `WorkbookInput { method: 'cpk'|'logbook', trips, expenses, taxpayerName, abn, rego, fy }`
- Produces: `Uint8List xlsxBytes` — valid PKZip with `[Content_Types].xml`, `xl/workbook.xml`, correct tab count

- [ ] **Step 1: Write structural validity test**
```dart
test('CPK xlsx has exactly 2 worksheets', () async {
  final bytes = await OpenXmlWorkbookBuilder().build(cpkInput);
  final archive = ZipDecoder().decodeBytes(bytes);
  final sheetNames = _extractSheetNames(archive);
  expect(sheetNames, hasLength(2));
  expect(sheetNames, containsAll(['Tax Summary', 'CPK Trip Ledger']));
});
test('Logbook xlsx has exactly 3 worksheets', () async { ... });
test('xlsx bytes form a valid zip', () async {
  final bytes = await OpenXmlWorkbookBuilder().build(cpkInput);
  expect(() => ZipDecoder().decodeBytes(bytes), returnsNormally);
});
```
- [ ] **Step 2:** Run → record result; fix `openxml_workbook_builder.dart` if archive malformed
- [ ] **Step 3:** All 3 PASS
- [ ] **Step 4:** `git commit -m "test(export): pin xlsx PKZip structure and worksheet count"`

### Task B3: ATO Required Fields in PDF + xlsx Tab 1

**Files:**
- Test: `test/services/engine/pdf_export_service_test.dart`
- Test: `test/services/engine/openxml_workbook_builder_test.dart` (extend)

**Interfaces:**
- Produces: PDF text must contain all 7 ATO required fields; xlsx Tab 1 row 1 headers must contain all 7

Required fields: `taxpayerName`, `abn`, `vehicleRego`, `financialYear`, `openingOdometer`, `closingOdometer`, `deductibleClaim`

- [ ] **Step 1:** Test: render PDF with known input; extract text via `pdf` package; assert all 7 fields present and non-empty
- [ ] **Step 2:** Test: parse xlsx Tab 1; assert all 7 column headers present
- [ ] **Step 3:** Run → record PASS/FAIL; fix service if any field missing
- [ ] **Step 4:** All PASS
- [ ] **Step 5:** `git commit -m "test(export): pin ATO required fields in PDF and xlsx Tab 1"`

### Task B4: Tab 3 Expense Fields + SHA-256 Provenance (INV-B05)

**Files:**
- Test: `test/services/engine/logbook_export_service_test.dart`
- Modify: `lib/services/engine/logbook_export_service.dart` (add provenance fields if missing)

Required columns: `Merchant_Name`, `Merchant_ABN`, `Gross_Amount_AUD`, `GST_Amount_AUD`, `Net_Amount_AUD`, `Business_Percent`, `Deductible_Amount_AUD`, `Cloud_Receipt_URL`, `AuditEvidence_Id`, `Image_SHA256`

- [ ] **Step 1:** Test: build logbook export with one expense; parse Tab 3 row; assert all 10 column values non-empty
- [ ] **Step 2:** Run → FAIL if `AuditEvidence_Id` or `Image_SHA256` column missing
- [ ] **Step 3:** Add provenance columns to `logbook_export_service.dart` from `AuditEvidence` linked via `trip_evidence_links`
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** `git commit -m "feat(export): add AuditEvidence.id + SHA-256 provenance to xlsx Tab 3 (INV-B05)"`

### Task B5: Export UX — Progress Indicator Before File Appears

**Files:**
- Modify: `lib/ui/screens/tax/tax_summary_screen.dart`
- Test: `test/ui/tax/tax_summary_screen_test.dart`

- [ ] **Step 1:** Widget test: tap Export; pump 500ms; expect `CircularProgressIndicator` or equivalent is in tree before `Share` sheet appears
- [ ] **Step 2:** Run → FAIL if export is synchronous with no indicator
- [ ] **Step 3:** Wrap export call in async with `setState(() => _exporting = true)` before `await` and `false` after; show progress widget while `_exporting`
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** `git commit -m "feat(ui): show export progress indicator before file generation completes"`

---

## Squad Gamma (Team C) — Pre-flight Review + Compliance Gate
**Owner scope:** `lib/ui/screens/tax/pre_flight_review_screen.dart`, `lib/services/engine/accounting_export_validator.dart`

### Task C1: Validator Surface All Errors Before Export

**Files:**
- Modify: `lib/services/engine/accounting_export_validator.dart`
- Test: `test/services/engine/accounting_export_validator_test.dart`

**Interfaces:**
- Consumes: `AppState` with trips, expenses, vehicle, method
- Produces: `ValidationResult { errors: List<ValidationError>, warnings: List<ValidationWarning>, canExport: bool }` where `canExport = errors.isEmpty`

- [ ] **Step 1: Write failing tests**
```dart
test('blocks export when no trips in logbook period', () {
  final result = AccountingExportValidator().validate(emptyState);
  expect(result.canExport, isFalse);
  expect(result.errors.any((e) => e.code == 'NO_TRIPS'), isTrue);
});
test('blocks export when closing odometer not set', () { ... });
test('warns when logbook period < 12 weeks', () {
  final result = validator.validate(shortPeriodState);
  expect(result.warnings.any((w) => w.code == 'SHORT_LOGBOOK'), isTrue);
  expect(result.canExport, isTrue); // warning only, not error
});
```
- [ ] **Step 2:** Run → FAILs
- [ ] **Step 3:** Implement validator: errors block export; warnings allow export with acknowledgement
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "feat(validation): export validator surfaces all errors + warnings"`

### Task C2: Pre-flight Screen Blocks Export on Errors

**Files:**
- Modify: `lib/ui/screens/tax/pre_flight_review_screen.dart`
- Test: `test/ui/tax/pre_flight_review_screen_test.dart`

- [ ] **Step 1:** Widget test: inject `ValidationResult` with 1 error; Export button must be disabled (not tappable)
- [ ] **Step 2:** Widget test: inject result with 0 errors + 1 warning; Export button enabled; warning card visible; user taps "I understand"; Export proceeds
- [ ] **Step 3:** Run both → FAILs
- [ ] **Step 4:** Implement: `canExport && warningsAcknowledged` gates the button; show amber warning cards with checkbox acknowledge
- [ ] **Step 5:** PASS
- [ ] **Step 6:** `git commit -m "feat(ui): pre-flight screen blocks export on errors; warnings require acknowledge"`

### Task C3: Logbook Period Progress — Gap Detection

**Files:**
- Modify: `lib/ui/screens/logbook/logbook_progress_screen.dart`
- Test: `test/ui/logbook/logbook_progress_screen_test.dart`

- [ ] **Step 1:** Widget test: render screen with logbook period 10 weeks covered, 2 weeks gap; expect text "2 weeks unaccounted" visible
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Add gap calculation: `totalDaysInPeriod - daysWithAtLeastOneTrip = gapDays`; display `gapDays / 7` as weeks
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "feat(logbook): show unaccounted gap weeks in progress screen"`

---

## Squad Delta (Team D) — Security + RLS Hardening
**Owner scope:** Supabase migrations, RLS policies, auth session handling

### Task D1: RLS Cross-User Isolation Test

**Files:**
- Create: `test/integration/rls_isolation_test.dart`

**Interfaces:**
- Requires: two Supabase test users (user A and user B) with seeded data

- [ ] **Step 1:** Integration test: user A creates a `trip_evidence_link`; user B's token queries same table; assert empty result set returned (no rows leaked)
- [ ] **Step 2:** Run against local Supabase (`supabase start`) → record PASS or FAIL
- [ ] **Step 3:** If FAIL, audit `trip_evidence_links` RLS policies in `supabase/migrations/`; add missing `SELECT` policy
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "test(security): cross-user RLS isolation on trip_evidence_links"`

### Task D2: SHA-256 Upload Integrity Verification

**Files:**
- Modify: `lib/services/storage/` (upload path)
- Test: `test/services/storage/upload_integrity_test.dart`

**Interfaces:**
- Produces: `UploadResult { storagePath, confirmedSha256, matchesClientHash: bool }` — `matchesClientHash` must be `true` before marking upload complete

- [ ] **Step 1:** Test: mock upload that returns mismatched ETag; expect `UploadResult.matchesClientHash == false` and upload aborted
- [ ] **Step 2:** Test: matching hash → `matchesClientHash == true` → `audit_evidence` row written
- [ ] **Step 3:** Run → FAIL (if no hash verification currently in upload path)
- [ ] **Step 4:** Implement: after upload, fetch storage object headers, compare SHA-256; throw `HashMismatchException` on mismatch
- [ ] **Step 5:** PASS
- [ ] **Step 6:** `git commit -m "feat(storage): verify SHA-256 post-upload before writing audit_evidence (INV-A01)"`

---

## Execution Order

Tasks within each squad are sequential (each builds on the prior). Squads are parallel.

```
Sprint 1 (now → done):
  Squad Alpha: A1, A2, A3
  Squad Beta:  B1, B2, B3
  Squad Gamma: C1, C2, C3
  Squad Delta: D1, D2
```

All squads run in parallel. Each task ends with a commit. After all tasks green, run `flutter test` for full suite before creating PR.
