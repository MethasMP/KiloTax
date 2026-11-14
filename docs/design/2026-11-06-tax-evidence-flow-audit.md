# Tax Evidence Tool — critical workflow audit

6 November 2026. Focus: Logbook first, within an evidence capture-to-accountant journey.

## Decision

The product is a **Tax Evidence Tool for Australian Tradies**. A trip counter is insufficient: users need to know what was captured, what is uncertain, what needs correction, and what will be handed over. Market parity is an acceptance target, not a conclusion supported by the current implementation.

## Evidence and limits

This pass traces the current Flutter UI handlers, AppState transitions and export entry point. It is a bounded audit of critical paths, not an exhaustive audit of all screens. Source-confirmed findings are separated from hypotheses requiring device or user validation. No timed competitor trial, physical-device capture, persistence-failure injection, user interview or accountant review was performed. Existing render-test counts are not evidence of end-to-end usability.

## Market reference points

Official product documentation accessed 6 November 2026:

- [Driversnote tracking](https://www.driversnote.com.au/tracking): automatic capture and classification. [Trip review](https://driversnote.helpscoutdocs.com/article/106-how-to-edit-a-trip) and [reporting](https://www.driversnote.com.au/reporting): editable trips, vehicle/date selection and PDF/spreadsheet handoff. These establish baseline tasks; they do not establish measured task speed.
- [Rounded Trax](https://trax.rounded.com.au/): vehicle-triggered tracking, manual past trips with date/time, multiple vehicles, trip tags, PDF/CSV and Rounded integration. Do not use its website's deduction examples as authoritative tax-rate data.
- [Everlance](https://www.everlance.com/): mileage plus expense tracking and receipt management. [Export documentation](https://help.everlance.com/hc/en-us/articles/45326462003995-What-Will-the-Data-Export-Look-Like) describes receipt links in transaction exports. Use as a workflow benchmark, not as Australian tax-rule guidance.

No growth or market-leadership claim was independently verified. Autokept's site could not be accessed in this pass, so it is not scored. The ATO logbook web page returned 403; no legal-compliance conclusion is derived from competitor claims.

## Critical journey and release evidence

| Task | Successful outcome | Recovery path to verify | Evidence required |
|---|---|---|---|
| Prepare | Correct vehicle/method and understandable tracking readiness | Permission denied/revoked, Bluetooth absent, manual mode | Device walk-through and first-value timing |
| Capture a trip | Right vehicle/date/source with route/distance stored | Tracking missed, duplicate, interrupted app | Background device run + restart/reload test |
| Add a past trip | User can set actual date/time; source remains manual | Invalid input, uncertain distance, wrong vehicle | Save/reopen assertions and clear error messages |
| Capture expenses | Receipt image and user-reviewed financial data remain connected | OCR failure, duplicate, multi-page/multi-receipt scan | Review every imported item; restart retains image/data |
| Review | User understands suggestions and confirms/corrects purpose | Batch mistake, undo, record already edited | Changes preserve identifiers, source and receipt/job links |
| Resolve gaps | Uncertainty is explained and explicitly resolved | Missing trip, unknown classification, mistaken baseline | No unsupported personal/business claim created silently |
| Close logbook | User reviews period, end reading and unresolved evidence | Time complete but evidence incomplete; correction after close | Reachable UI and tested state transition |
| Export | Explicit vehicle/date scope and evidence contents previewed | Prepare failure, cancel share, missing email app, retry | Files open independently; totals match scope; sharing is not labelled delivery |

## Findings and implementation order

### P0 — Manual entry writes misleading metadata and review can lose links

Source before this fix: `logbook_trip_entry_screen.dart` constructed a fresh Trip without taxMethod/evidenceSource; defaults in `trip.dart` were CPK and auto telemetry. Reconstructing a detected trip also omitted receipt links, jobReference and clientDedupId. `recordTrip` replaces a matching record by ID, so omitted fields could replace existing metadata.

Implemented in this pass: manual entries explicitly use Logbook/manual_retroactive. Review uses copyWith on the detected trip, retaining its identity, vehicle, source and linked evidence. Personal classification/purpose initializes from the existing record. Regression assertions cover the save result, not only widget presence.

### P1 — Past-trip entry cannot choose when the trip occurred

Source before this fix: new entries always used DateTime.now and the form offered no date/time controls despite a past-trip entry route.

Implemented: date and time pickers; manual purpose requires a deliberate choice rather than defaulting to business. Non-finite distance is rejected. Save feedback confirms the recorded trip/date/distance instead of opening the tax-savings dialog after leaving the route. A widget interaction test selects a past date and verifies the stored result.

### P0 — Odometer gap is turned into a personal trip without confirmation

Source: the entry handler calls fillOdometerGap, and AppState.recordTrip also invokes OdometerGapReconciler, whose generated bridge has personal classification. This behavior exists at multiple write boundaries. A UI-only prompt would not fix all capture paths.

Next change: define an unresolved gap object or explicit provisional state and review action; preserve the observed readings and inference provenance. Specify effects on summaries and exports before changing shared ingestion behavior. This pass deliberately does not silently change every ingestion path.

### P1 — Logbook period completion has no connected UI action

Source: searching lib for completeLogbookPeriod finds its AppState definition but no caller. Progress currently displays elapsed time without a closing workflow.

Next change: a reachable Review period flow with scoped trips, end odometer, missing evidence, explicit confirmation and clear pending-review status. Completing elapsed time must not imply external approval or certification.

### P1 — Scope of the business-use number differs from the surrounding period

Source: hero uses AppState.taxSummary, which is filtered by primary vehicle and active financial year, while its headline describes the 12-week period.

Next change: separate period business use from financial-year totals; display explicit date/vehicle scope. Tests must span two vehicles, an FY boundary, deleted trips and dates outside the logbook window.

### P1 — Batch receipt flow differs from individual receipt review

Source: scan_receipt_screen.dart sends the first receipt to the detail UI but immediately records subsequent items. High-confidence OCR is marked verified; lower-confidence items may be recorded with zero/default values and needsReview.

Next change: a batch result list with per-item review status, visible counts and retry/correct controls. Define whether OCR confidence means extraction confidence or user confirmation; never conflate them. Verify image retention, deduplication and expense-trip associations.

### P1 — Export handoff needs review and content validation

Source: TaxPackShareHelper generates a summary PDF and trip CSV immediately from the selected vehicle/evidence engine; no preview or completeness gate is present at this entry point. The share text labels the ledger Audit-Proof unless an odometer monotonicity warning exists. Those are insufficient signals for that claim.

Next change: preview exact vehicle/date/method, totals, unresolved items, included receipts and privacy settings. Distinguish draft export from reviewed export. Verify a usable receipt/evidence manifest or attachment set; the two attachments in this path alone do not demonstrate complete accountant handoff. Replace unsupported guarantees with factual completeness descriptions. Test dispatch cancellation/retry and temporary-file lifetime.

### P1 — Save acknowledgement does not prove durable storage

Source: entry calls a void recordTrip method; storage calls are not awaited at this UI boundary. Actual failure behavior still requires investigation of the storage service.

Next check: trace storage error propagation before changing the API. Inject a local write failure and restart the app after success; only then define the precise saved/local-only/sync-pending statuses. Do not report a proven data-loss bug from this source observation alone.

## Acceptance before claiming market parity

1. Verify all critical outcomes and recovery paths above on the current build, including restart/reopen and export-file inspection.
2. Run identical realistic scenarios on selected competitors; record task success, time, taps, errors and what reaches the accountant. Do not invent competitor timings.
3. Test with approximately five representative tradies for qualitative issue discovery and at least one accountant for handoff quality. Use synthetic records and consent; small samples do not prove statistical superiority.
4. Proposed targets, pending baseline: at least 4/5 participants finish each critical task without intervention; common trip review within three actions after opening; zero silent source/link/classification loss in automated integrity cases; users can distinguish unreviewed evidence from reviewed evidence.
5. Product differentiation should be demonstrated by less reconciliation work and a traceable trip–expense–job–odometer chain, not by a larger feature list or a claimed certification badge.

## Current boundary

Update: the missing-travel journey is now implemented; see [delivery and validation](2026-11-06-missing-travel-journey.md). Automatic personal bridge creation has been removed from ingestion and entry, with an explicit user review flow and a user-facing export guard.

The entry and missing-travel flows have been improved. Period closing, scoped summaries, receipt batches, durable-save states and full export preview remain required work. No full parity, tax compliance, device-tracking reliability or accountant acceptance claim is made.

Validation for the entry change: `flutter test test/ui/logbook_trip_entry_flow_test.dart tool/design_audit/logbook_visual_test.dart test/cpk_logbook_journey_decoupling_test.dart --update-goldens` — **41 passed**, including actual date selection/save, metadata preservation and explicit purpose choice. Targeted analyzer reported **No issues found**. These tests validate UI/state behavior, not disk persistence or background tracking on hardware.
