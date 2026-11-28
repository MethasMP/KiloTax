# Evidence-first journey implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Let tradies capture vehicle records, resolve related evidence issues, and prepare a scoped accountant pack through one visible journey.

**Architecture:** Keep EvidenceReviewReport as the issue source and existing AppState mutations as record owners. Add pure contextual grouping, explicit receipt inspection state, and four persistent destinations with a separate capture action. Reuse the current editors and pack builder.

**Tech Stack:** Flutter, Dart, Provider, flutter_test. No new dependencies.

**Spec:** docs/superpowers/specs/2026-11-26-evidence-first-journey-design.md. Approved in chat on 26 November 2026.

## Global constraints

Preserve existing unrelated checkout changes. No database migration, inferred business use, invented records, required job entry, matcher scoring change, or tax calculation change. Cents-per-km retains its supported capture types. Pack scope stays local. No native sharing or external writes are required.

## Review focus

- A late receipt check must not overwrite a newly selected scope.
- Pack review editors must not change global active vehicle or financial year.
- A related older record is context only in This week.
- An optional match must not become a pending requirement or attach a pooled cost.
- Capture must preserve the selected destination and existing record-list filters.

## Throughput checkpoint

One implementer owns the coupled product diff so navigation and scoped callbacks stay consistent. Root owns baseline snapshots, independent inspection, final review, and rendered verification. Mutations remain serial. Use existing capture and export tools. Do not commit pre-existing changes or create a detached worktree that loses the current baseline.

## Task 1: Contextual Review

Files: lib/ui/screens/evidence/evidence_review_screen.dart; new pure grouping model alongside it if needed; lib/ui/screens/expenses/expense_detail_screen.dart and existing scoped editors only where scope isolation requires it; test/ui/evidence_review_flow_test.dart and new evidence journey tests.

Interfaces: EvidenceReviewScreen keeps required appState, vehicleId, financialYear. Add optional VoidCallback onOpenPack for persistent navigation and temporary Pack return. Keep show compatible. Grouping consumes one EvidenceReviewReport and the filtered issue list; returns real record context plus original typed issues.

- [ ] Add tests for accepted links, independent expenses, per-record week filtering, and scope-safe editing. Run them and observe failure.
- [ ] Implement contextual cards, receipt inspection failure/retry and stale-result protection. Keep suggestions optional and confined to unresolved expenses. Existing expense confirmation owns accept behavior.
- [ ] Open Pack through onOpenPack or a scoped TaxSummaryScreen fallback, never direct sharing or selectVehicle.
- [ ] Run focused review and existing scope tests. Expected all pass.

## Task 2: Evidence-led Home

Files: lib/ui/screens/dashboard/task_home_body.dart; Home presentation widgets; test/ui/home_next_action_test.dart; test/ui/home_v2_test.dart; new evidence journey tests.

Interfaces: Keep EvidenceHomeScreen/CpkHomeBody/LogbookHomeBody callback APIs compatible. onReviewTrips now means open combined Review. onViewTax opens Pack with the active vehicle and year. Home may consume a small inspection controller if shared behavior is demonstrably duplicated.

- [ ] Add tests for a mixed queue, older issues, receipt checking/failure, and empty capture. Observe failures.
- [ ] Replace trip-first hero with scoped issue digest, Pack status, and mixed recent records. Preserve recording controls, account retry, logbook and odometer access.
- [ ] Remove the estimate hero from Home. Keep estimate accessible in Pack. Never infer readiness from HomeRecordSummary's filtered issues.
- [ ] Run focused Home tests. Expected all pass after updating assertions for intentionally changed behavior.

## Task 3: Navigation and Pack scope

Files: lib/ui/screens/home/main_scaffold_screen.dart; lib/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart; Records container; lib/ui/screens/tax/tax_summary_screen.dart; navigation and export tests.

Interfaces: Nav indices are Home=0, Review=1, Records=2, Pack=3 for both methods. Centre Capture is an action. Add optional initialVehicleId and initialFinancialYear to TaxSummaryScreen; explicit scope requests must be distinguishable from ordinary tab selection so direct Pack taps preserve local state.

- [ ] Add journey tests for all destinations, capture retaining selection, records filters, Home/Review explicit Pack scope, and Pack to temporary Review to Pack scope preservation. Observe failures.
- [ ] Implement persistent combined Review and Records with Trips plus existing supported Expenses. Route centre action through QuickCaptureBottomSheet.show.
- [ ] Pack opens temporary scoped Review with onOpenPack returning to the existing route. Persistent Review follows global scope. Editors receive scope explicitly without selectVehicle side effects.
- [ ] Run focused journey, release navigation, and pack scope suites. Expected all pass.

## Task 4: Real renders and final review

Files: tool/design_audit evidence journey capture test; generated PNG evidence; implementation notes in this plan.

- [ ] Capture actual-theme empty, mixed, checking, failed, and resolved states at normal width and 320pt with 200 percent text. Inspect actual images.
- [ ] Run focused regression suite and flutter analyze --no-pub. Inspect task diff whitespace.
- [ ] Dispatch fresh code review over the task diff and spec. Fix material findings and run relevant regressions.
- [ ] Record actual evidence and native-platform limits. Hand back without committing unrelated work or sending data externally.

## Decision trail

- Baseline before implementation: 15 focused service, review, Home, and export-scope tests passed in the preceding turn.
- User explicitly approved implementation. Continue without a second plan approval checkpoint.
- Preserve the suitable current checkout because it contains the current product baseline and substantial pre-existing work. Save copies of touched files before editing so review can isolate this request.
- Design exploration is settled by the approved spec's three approaches and builder check. Do not repeat an arena over the same decision.

- Root regression completed. Four baseline Home renders passed. Scoped odometer, navigation readability and capture semantics suite passed 14 tests. Existing odometer and security suite with the new scoped mutation passed 21 tests before the widget case was added.
- Scoped odometer review now targets a vehicle ID without changing the global selection. The existing entry screen receives the same ID. Invalid and non-finite readings are rejected.
