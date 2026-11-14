# Mixed receipt and cloud persistence implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve full receipts, exclude private/unresolved allocations from calculations, and persist/restore the same facts in Supabase without false sync success.

**Architecture:** One existing expense is the receipt parent, retaining total/image. Optional allocation lines carry description, amount, actual GST, category and work/private/unresolved purpose. JSONB allocations are committed atomically with the parent and inherit its existing RLS, avoiding partial child writes. Calculation projections expose only work lines; exports retain all lines for reconciliation. Legacy unsplit receipts remain compatible.

**Tech Stack:** Flutter/Dart, existing HTTP client, Supabase PostgreSQL/Storage. No new dependencies.

**Spec:** docs/design/2026-11-10-receipt-workflow-review.md, Supabase follow-up. User authorized app and Supabase implementation after the proposed mixed-bill approach.

## Global constraints
- Keep receipt item allocation separate from logbook apportionment.
- Never infer GST as total/11 when GST is unknown in the new review flow.
- Retain existing records and RLS. Apply an additive migration only; do not replay unrelated pending migrations.
- Extend existing test files. No iPad testing is available.
- Reuse current checkout with its existing uncommitted changes; do not commit unrelated work.

## Review focus
- Two same-date/same-amount receipts must remain distinct, and retries/edits idempotent.
- Local non-UUID IDs must round-trip through UUID cloud keys without breaking links.
- Invalid/unbalanced splits and unresolved lines must never inflate claims.
- Missing/failed photo uploads and HTTP non-2xx must not report full sync success.
- Multiple categories in one receipt must reach the correct calculation/export buckets.

### Task 1: Allocation model and calculations
**Files:** lib/data/models/vehicle_expense.dart; lib/services/engine/tax_calculator_service.dart; lib/services/engine/logbook_export_service.dart; existing receipt_data_validation_test.dart.
**Interfaces:** ReceiptAllocation.toJson/fromJson; VehicleExpense.allocationError, claimComponents, allocatedWorkAmount. Legacy no-allocation expenses retain existing amounts.
- [ ] Add regression tests for reconciliation, exclusion, mixed categories, local/cloud round-trip and logbook application exactly once; run RED.
- [ ] Implement immutable allocations and validation in cents; update tax calculations/export category projections; run GREEN.

### Task 2: Receipt review and export
**Files:** existing expense_detail_screen.dart, scan_receipt_screen.dart, tax_pack_builder.dart and existing receipt_audit_service_test.dart.
**Interfaces:** Review edits allocations and supplier; saves preserve total and all allocations. Export allocation CSV references parent ID/image.
- [ ] Add widget regression to existing test file for mixed-bill save and validation.
- [ ] Add compact split editor with private/unresolved exclusion, reconciliation feedback, unknown GST and per-line category. Require all batch images to enter review rather than autosave.
- [ ] Verify widget tests and export allocation traceability.

### Task 3: Cloud contract and migration
**Files:** sync_engine_service.dart; new additive SQL migration; existing sync_engine_service_test.dart.
**Interfaces:** Cloud payload includes supplier, GST, audit, vault flags and allocations; stable tenant-scoped UUID transport IDs plus local_id retain app identities.
- [ ] Add HTTP rejection, identity/idempotency and allocation round-trip tests; run RED.
- [ ] Implement fail-honest sync/restore and image upload handling; run GREEN.
- [ ] Inspect live schema constraints/views; create additive migration matching payload and allocation validation; apply using Supabase migration tool.
- [ ] Verify schema, invalid-split rejection and RLS in a rollback-only synthetic transaction; no real user records changed.

### Task 4: Verification and review
- [ ] Run analyzer and relevant/full suite; fix regressions.
- [ ] Fresh reviewer checks only this task's files/diff and migration; resolve material findings.
- [ ] Record actual commands/results and limitations in this plan; report applied Supabase migration and app outcome.

## Execution ledger
- Initial root cause: client sends columns absent in live expenses; non-2xx not propagated. Expense/supplier/audit representation also diverges; there is no allocation model. Existing UI creates non-UUID IDs despite UUID database keys.
- Decision: embedded JSONB allocations use the existing parent RLS and a server validation trigger; this keeps the receipt and all allocations atomic. This is a storage implementation choice, not an ATO requirement.
- Decision: native execution in this existing checkout follows the user's direct instruction to fix both systems; no additional approval loop. Branch codex/mixed-receipt-sync preserves all existing work. No task commits until changes can be separated from pre-existing edits.
- Task 1: implemented allocation model, validation in cents, work-only calculation projections and mixed-category exports. Regression tests observed RED then GREEN; full suite before final review fixes: 544 passed.
- Task 2: implemented item editor, supplier persistence, blank unknown GST, batch images entering review rather than automatic ledger writes, and allocation CSV linked to original receipts. Extended existing tests only.
- Task 3: applied live migrations `20261110164301_receipt_allocations_and_sync_contract.sql` and `20261110164407_vehicle_display_name_contract.sql`. The first migration attempt rolled back because the existing view amount column requires numeric(10,2); an explicit matching cast resolved it before successful application. No pre-existing rows were rewritten.
- Live rollback-only verification passed: 150 total = 100 fuel + 20 parking + 20 private + 10 unresolved gives 80 at 60% logbook use and 20 with CPK; invalid allocation/GST rejected; vault-only excluded; owner read succeeds; another tenant cannot read or write the receipt or calculation view. Synthetic users remaining after rollback: 0. Security advisor warnings match the pre-existing baseline, with no findings on the new functions/receipt contract.
- Additional deployed contract findings: vehicles.display_name is an ordinary required column (the local base schema uses a generated column), and vehicles.user_id references profiles. A compatible fill trigger and ignore-duplicate profile creation address these without overwriting existing profiles.
- Decision: retain JSONB allocations on the existing expense parent, rather than new child tables, so an expense and all allocations have one atomic write and inherit existing ownership RLS. This changes storage implementation only; all excluded allocations remain available for reconciliation.
- Fresh reviewer `/root/mixed_receipt_final_review` identified five actionable findings: partial restore merge, async allocation mutation, inherited CPK vault state, non-finite parent GST and selected-method CSV inclusion. Each enters one RED→GREEN fix pass below; no deferred findings or second reviewer pass are planned.
- Final fix pass: regression cases observed failure for all five findings, then the relevant 35-test suite passed. Partial recovery now merges valid records while retaining error status; save uses validated allocation/category/date/GST/image/trip snapshots and blocks pointer edits/unfocuses the editor; CPK-only vault restrictions are released for direct work allocations; non-finite GST yields a validation message; allocation CSV inclusion reflects the selected method.
- Additional calculation regression: a legacy whole-bill business percentage of 50 must not reduce an explicitly allocated work line a second time. The example initially returned 70 instead of 80; the app projection and applied migration `20261111014427_explicit_receipt_allocation_percentage.sql` now use the explicit work amounts for direct lines, retaining the historical parent percentage as metadata. The same live rollback-only example with the historical 50% field passed at 80 (logbook) and 20 (CPK), with tenant isolation still passing.
- Decision: explicit money allocations replace a legacy whole-bill private/work ratio; running costs still receive the separate logbook use rate once. This avoids hidden double apportionment when editing an older record. If a work item has private use, its monetary private share belongs in a private allocation.
- Verification to this point: full suite 549 passed before the final legacy-percentage regression; dedicated allocation tests 10 passed after it. Analyzer was clean before the final arithmetic adjustment. Final whole-suite/analyzer and device build results follow below.
- Native limitation: iOS simulator build failed linking the existing MLImage framework slice built for iOS rather than simulator. No SDK patch or unrelated dependency upgrade was introduced. A no-codesign device build is being checked; physical iPad testing remains unavailable as stated by the user.
- Final verification confirmed after the interrupted turn: `flutter analyze` reports no issues; latest full `flutter test --reporter expanded` passed 549 tests, including the legacy-percentage regression. `BUILD_FOR_DEVICE=1 flutter build ios --debug --no-codesign` succeeded. The built kernel timestamp is newer than the changed allocation model, expense editor and AppState sources. `git diff --check` passed for the task files.
- Delivery status: all three migrations are applied to the connected Supabase project; app source is in the existing checkout on `codex/mixed-receipt-sync`. No installation, signed distribution, merge or push was performed. Existing unrelated edits were preserved.
- Remaining acceptance work: representative real receipt OCR/manual-allocation checks; native keyboard/large-text/photo usability on physical hardware; a signed-in client upload/restore exercise with receipt binaries across devices. The broader HTML prototype's durable draft queue and multi-photo receipt grouping are not implemented by this mixed-allocation/cloud-contract change. Line allocation currently requires user input/review rather than automatic product-line extraction.
