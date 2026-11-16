# Codex branch integration

The user requested finishing the remaining Codex branch, merging it into main, and removing the merged branches.

## Resolution

The baseline is main `269c28e`. The remaining branch is `325ffe4`. The histories diverged after independently integrating overlapping application work. A raw merge reports 47 conflicts. The integration records both histories and selects changes by subsystem rather than replacing newer main behavior.

The source checkout has unrelated ongoing work. During verification it moved to `feat/onboarding-persona-engine` with pending tracking changes. Integration runs in a managed worktree and leaves that checkout, branch and edits intact. Main is updated from the verified integration worktree.

The merged UI retains camera processing and review, split-receipt allocation, trip navigation, home actions and optional tracking permission prompts. The tax summary combines receipt readiness information with main's direct accountant handoff. Main's authenticated receipt resolver, session isolation, lifecycle guards, gap-tolerant accountant export and regression tests stay intact.

The branch's annual/logbook cloud additions are excluded as an incomplete feature. AppState never uploads or consumes their records. Their proposed policies also omit parent vehicle ownership checks. The broad Postgres migration and duplicate remote patch are excluded because they weaken existing ownership policies and replace the accountant view with an unsupported observed-ratio calculation. These exclusions are explicit dispositions, not claims that those cloud features were completed.

The evidence graph migration's expense foreign key points to the existing `expenses` table and gains its missing evidence lookup index. No database deployment is part of this integration. The legacy accountant service and its still-tested screen remain together to avoid an unrelated deletion.

Imported skill caches, generated captures, local OCR environment, personal documents and blanket ignore rules for source assets and documentation are excluded.

## Verification

Final commands and outcomes are appended after execution. An initial baseline full-suite attempt was interrupted before completion to avoid testing source while the integration changed. It is not counted as a passing baseline.

# Backend integration audit

Goal is to finish the remaining Codex branch integration while retaining main's newer export and lifecycle guarantees. Compared committed main `269c28e` against branch `325ffe4`. This was a read-only source audit. No runtime verification is claimed.

## Recommended resolution matrix

| Files | Resolution | Evidence |
| --- | --- | --- |
| lib/state/app_state.dart | Keep main in full, then wire retained annual/logbook feature separately if included. | Branch's 9 additions are formatting. Its 75 deletions remove `_disposed`, restore epoch/session guards, workflow save gates, restore/account exclusion and export session validation. Branch has no calls to syncAnnualOdometersToCloud or syncLogbookPeriodsToCloud, no consumption of restored annual/logbook lists. |
| lib/services/engine/tax_pack_builder.dart | Keep main in full. | Branch removes ReceiptExportResolver, reviewGroups and authenticated receipt collection, reverting to direct File reads. |
| lib/services/engine/tax_pack_documents.dart | Keep main. | Only changed line removes authenticated private-storage collection from evidenceNote. |
| lib/services/engine/evidence_review_service.dart | Keep main. | Branch marks receipt missing solely from empty receiptPath even when resolved remote file is available. |
| lib/services/engine/tax_pack_share_helper.dart | Keep main in full. | Branch removes session guards, remote resolver, current-vehicle odometer-gap scoping and readable review groups. |
| lib/services/engine/receipt_export_resolver.dart | Keep main file. | Branch deletes entire implementation required by current export behavior. |
| lib/services/engine/accountant_handoff_service.dart | Branch deletion is plausible dead code cleanup, but confirm callers. | Replaced export path is TaxPackBuilder. No need to resurrect an unused legacy service. |
| lib/services/engine/tax_pack_analysis.dart and openxml_workbook_builder.dart | Identical at compared tips. | Not listed in direct git diff. Decomposition already exists on main. |
| lib/services/evidence/evidence_vault_service.dart | Keep main. | Branch adds one blank line only. |
| lib/services/ocr/receipt_intelligence_service.dart | Take branch's new personal-item hint if branch UI is retained. | Adds isLikelyPersonalItem and a case-insensitive food/drink regex. Keep it a suggestion, never silently assert tax eligibility. |
| lib/services/scanner/document_scanner_service.dart | Take branch addition with its failure test. | Optional reportCaptureErrors flag preserves default behavior and lets new capture UI show fallback errors. |
| lib/services/sync/sync_engine_service.dart | Branch additions can be retained after integration hardening. | Entire diff is additive, 234 lines for annual/logbook POST and GET plus CloudRestoreResult lists. No existing lifecycle changes here. |
| lib/data models | Identical at tips. | No direct model diff. AnnualVehicleOdometer and LogbookPeriod already exist. |
| supabase/migrations/20261008_enforce_user_id_rls.sql, 20261008_fix_accountant_deductions_view.sql, 20261023_phase1_security_rls_optimization.sql, 20261023_phase2_cpk_logbook_isolation.sql, 20261112000100_trip_job_review_workflow.sql | Keep main. | All direct differences are trailing whitespace. |
| supabase/migrations/20261108_evidence_graph_contract.sql | Take only FK correction vehicle_expenses to expenses, evidence_id index, and UPDATE policy after ownership review. | Base schema creates public.expenses, no vehicle_expenses table exists. Remaining changes are whitespace. |
| supabase/migrations/20261114220000_annual_odometer_and_logbook_periods.sql | Keep table feature only after hardening vehicle ownership in RLS. | New policies only require row.user_id=auth.uid(), allowing an own row to reference someone else's vehicle UUID. Existing trip/expense policy explicitly verifies parent ownership. |
| supabase/migrations/20261114235900_modern_postgres_performance_and_security.sql | Do not take wholesale. | It drops existing trips/expenses policies and recreates them without parent vehicle ownership checks. Its view rewrite also presents observed trip ratio as logbook claim basis. No measured index gains establish need. |
| supabase/COMPLETE_REMOTE_PATCH_20261114.sql | Do not take wholesale. | Duplicates new migration content and its ownership-policy risks. Use one canonical migration rather than a second executable copy. |

## Annual/logbook sync gaps if retained

1. AppState currently never pushes the new lists, consumes restored lists, or persists restored logbook periods. Merely retaining the new service tests is not an end-user integration proof.
2. New POST methods put record counts in `syncedExpenses`. That is semantically wrong for annual/logbook records. Introduce an explicit result shape or intentionally leave these count fields at zero and check success without misreporting expenses.
3. New restore GET responses silently ignore non-2xx responses and may return success with no annual/logbook records. Preserve existing records and communicate partial failure rather than silently claiming full restore.
4. Restore mappings must round-trip null closing/end odometers and certified metadata. New schema is not deployed by a source merge. Existing installations lacking tables should have an explicit compatible error strategy.
5. Account transition lifecycle guards belong around the whole AppState restore including added annual/logbook persistence. Preserve every main isCurrent check.
6. New annual/logbook RLS should require both current user ownership and matching vehicle owner on INSERT and UPDATE. Foreign keys alone only ensure existence.

## Verification to run

Run full flutter analysis and tests after merge because UI/state/service changes cross the app. Focused suites are test/sync_engine_service_test.dart, test/dynamic_token_sync_test.dart, test/workflow_persistence_exclusion_test.dart, test/receipt_workflow_integrity_test.dart, test/trip_job_receipt_workflow_test.dart, test/services/engine/receipt_export_resolver_test.dart, test/tax_pack_builder_test.dart, test/services/engine/tax_pack_accountant_review_test.dart, test/ui/tax_pack_share_flow_test.dart, test/document_scanner_service_test.dart and new document_scanner_failure_test.dart. Add user-visible annual/logbook roundtrip and stale-session restore tests if completing that feature. SQL needs an isolated database migration run and two-user parent-ownership checks before any deployment. No deployment is authorized by this audit.

Principles applied are Prove It Works for distinguishing source audit from runtime proof, and Model the Domain for recommending explicit annual/logbook sync result counts rather than using expense counts.

## Final scope decision from coordinator

Annual/logbook cloud behavior is not required by this branch reconciliation. Keep main sync_engine_service.dart and omit both annual/logbook schema migration and sync service additions as one incomplete feature. Do not add the modern Postgres migration or duplicated COMPLETE_REMOTE_PATCH. This avoids expanding the work into a new cloud behavior implementation. The retained local annual/logbook models and recorded-data exports remain available.

# UI integration audit

Goal is to finish codex/mixed-receipt-sync integration into main and delete the branch only after preserving its useful work.

Compared main 269c28e against branch 325ffe4 with git diff and inspected source at both commits. This is a static review, not a runtime PASS.

## File choices

| Files | Choice | Reason |
| --- | --- | --- |
| lib/ui/screens/expenses/scan_receipt_screen.dart and widgets/receipt_processing_view.dart | Take branch, run scan tests | Genuine single-photo OCR to review, batching to inbox, injected services, camera errors, processing UI and busy guards. Requires branch scanner service reportCaptureErrors API. |
| lib/ui/screens/expenses/expense_detail_screen.dart | Take branch then inspect any main-only semantic fixes | Genuine trip auto-suggestion, receipt evidence presentation, explicit allocation presets, balanced cent totals, individual private classification, date review and accessible row layouts. Large structural diff, preserve downstream private-job export isolation in engine. |
| lib/ui/screens/dashboard/task_home_body.dart and widgets/home_record_hero.dart | Take branch | Adds next-action review flow and vehicle creation, retry state, clearer home hierarchy and tax summary callback. Retry currently calls restoreFromCloud even when generic syncStatus error arose during upload; verify this does not imply uploading pending records. |
| lib/ui/screens/cpk/cpk_home_body.dart, logbook/logbook_home_body.dart, dashboard/evidence_home_screen.dart | Take branch | Required callback plumbing for trip review and tax summary navigation. |
| lib/ui/screens/home/main_scaffold_screen.dart, home/widgets/scaffold_bottom_nav_bar.dart, home/widgets/trips_ledger_tab.dart | Take branch as coupled group | Scan button opens camera, trip add moved into Trips, home next action opens filtered ledger scoped to selected vehicle/year, trip tools and clearer rows. TaxSummaryScreen requires onViewTrips callback adaptation. |
| lib/main.dart, onboarding/onboarding_flow_screen.dart, onboarding/widgets/permission_preprompt_screen.dart | Take branch as coupled group if preserving authored branch product change | Adds explicit welcome, auth or guest, optional permission, vehicle states. Manual skip remains supported. Main existing guest release journey must be updated to act on new intermediate screens rather than deleted. Comments claiming mandatory biometric or compliance are unsupported descriptions and should be removed. |
| lib/ui/screens/tax/tax_summary_screen.dart | Merge branch redesign with main handoff | Branch adds async receipt inspection, generation guard, per-record readiness and useful method explanation. It removes main onSend injection and routes primary action through evidence checklist. Preserve main Send to accountant primary action and callback injection while integrating branch onViewTrips. Do not regress into draft ZIP gating. |
| dashboard/widgets/account_settings_sheet.dart | Keep main | Branch only renames Send to accountant to Export Tax Pack First. Main wording is newer intended product contract. |
| dashboard/widgets/tax_readiness_card.dart | Keep main | Branch removes showAction and direct accountant export, restores extra review gate. Main contract deliberately permits gaps to remain in accountant pack. |
| evidence/evidence_review_screen.dart | Keep main | Branch passes old allowDraftWithGaps flag and restores draft/share labels. Main newer share helper uses default accountant handoff. |
| workflow/workflow_screen.dart | Keep main | Branch replaces direct accountant send with another review step and technical ZIP inventory. |
| expenses/receipt_inbox_screen.dart, vehicle/vehicle_setup_flow.dart | Keep main | Only whitespace differs. |
| tax/pre_flight_review_screen.dart | Keep main unless proved unused | Branch deletes legacy screen. Removal is separable and unneeded for preserving behavior. |

## Test choices

Take all branch-only UI tests that exercise retained scanner, allocation, trip menu, onboarding prompt and next-action behavior. Also take test/support/main_menu_fixtures.dart required by menu test. Keep main test/ui/tax_pack_share_flow_test.dart unchanged. Branch removes the authenticated-session-change and duplicate-export tests and substitutes the old odometer export blocker. These are real regressions against the current main contract.

Keep main evidence_handoff_render_test.dart and evidence_review_flow_test.dart because their only changes restore stale Share records labels. Keep existing odometer_gap_journey_test.dart and do not import its branch-added export-blocking test. Keep pre_flight_review_screen_test.dart with its screen unless removing both after proving unused.

Take branch home_v2_test.dart scrolling changes, trips_ledger_tab_surgical_refactor_test.dart changed rendered row assertions, and release_main_journey_test.dart trip navigation updates with retained existing guest/persistence assertions.

Branch tax_summary_readiness_test.dart assumes old Review primary CTA. Adapt assertions to preserve Send to accountant and injected onSend where ready or incomplete. Retain readiness, stale async inspection, vehicle/year changes, empty-state and receipts assertions. Existing main tax summary tests may use onSend constructor argument and must keep compiling.

## Verification

Run flutter analyze and full flutter test after integration. Focused tests include scan_navigation_test, scan_receipt_auto_flow_test, scan_receipt_flow_mode_test, receipt_processing_view_test, receipt_capture_render_test, receipt_review_guidance_test, expense_detail_auto_suggest_trip_test, split_editor_mark_private_test, permission_preprompt_screen_test, home_next_action_test, main_menu_redesign_test, trips_ledger_design_test, tax_summary_readiness_test, tax_pack_share_flow_test, evidence_review_flow_test, odometer_gap_journey_test and release_main_journey_test. Run native integration journey for scanner/navigation if simulator is available.

## Proven risk

Whole-branch replacement would delete main export session test coverage and restore the old odometer-gap export blockade. Evidence is git diff 269c28e 325ffe4 -- test/ui/tax_pack_share_flow_test.dart. This is why export UI and tests need selective preservation.

## Final verification and repairs

- Whole-project `flutter analyze --no-pub` reported no issues in `/tmp/drivelog-integration-clean-analyze.log`.
- Native `flutter test integration_test/release_main_journey_test.dart -d 0B2FF6C7-F20E-421F-B0F8-244F75F1E598 --no-pub --reporter expanded` passed the guest, vehicle, trip correction, expense, export and persisted restart journey on iPhone Simulator. Evidence is `/tmp/drivelog-integration-native-journey.log`.
- Scanner, OCR, sync exclusion and accountant review focused checks passed 65 tests in `/tmp/drivelog-integration-core-tests.log`.
- The first exploratory full run passed 729 and failed 14 tests. Stale UI expectations were aligned without removing record identity, account isolation or duplicate-dispatch assertions.
- Parallel Flutter commands raced generated native libraries. The SQLite inbox fixture therefore failed before saving data. The correct two-review-group and one-current-pending-draft assertions were retained. Evidence is `/tmp/drivelog-export-test-repair.md`.
- The serialized full run passed 742 tests and failed one CPK Home navigation test in `/tmp/drivelog-integration-serialized-full.log`. That remaining test incorrectly expected direct form entry. Product code still offers GPS/manual choices on Home and direct manual entry from Trips. Only the test was corrected to pump after scrolling, tap a hit-testable control, choose a past trip, and assert the form. Its independent rerun is recorded below after execution. No product source changed after the serialized run.
- Source review found a real Retry defect in the branch. Retry now uploads pending local records rather than restoring potentially stale cloud data. A regression throws if Retry attempts restore.
- Permission denial now proceeds without another background request. A method-channel regression checks that only the foreground request occurs.
- Main's deprecated Supabase `anonKey` initialization argument uses its equivalent `publishableKey` alias. The constant and credential value are unchanged.
- The scanner cancellation tests model native cancellation and assert return to the caller. Receipt editor tests use the scoped Replace action and retain identity, linked-trip, deduplication and review assertions.

Review is independent but uses the available session model. Configured cross-family model families, Cursor-only control skills and the cursor-team-kit deslop plugin were unavailable. Native Flutter integration, widget interaction tests, static analysis and manual diff/comment reviews were used. No unsupported cross-family review or full transcript audit is claimed.

## Independent landing verdict

The independent same-model reviewer returned PASS+NOTES. Its own serialized widget command passed all 18 tests across `test/cpk_gestalt_ux_test.dart`, `test/ui/home_next_action_test.dart` and `test/onboarding_auth_state_test.dart`. This includes the corrected sole full-suite failure and the new Retry and denied-permission regressions. Evidence is `/tmp/drivelog-landing-independent-tests.log` and `/tmp/drivelog-landing-review.md`.

All 743 unique tests in the full-suite inventory now have passing evidence from the full run and the independent corrected-test rerun. The full command itself ended 742 passed and one failed before that test-only correction. It was not represented as a zero-exit full command. No application source changed between those checks.

Prove It Works drove native interaction and real export checks. Sequence Work into Verifiable Units kept source selection, regression repairs and landing separate. Laziness Protocol kept newer main safety code and rejected unrelated unsafe or incomplete branch changes.
