# KiloTax Security Remediation Program plan

KiloTax remediation closes all twenty-one findings across four security axes and four execution phases.
The program deploys four specialized teams scaled by finding count and severity.
The nineteen PR ids execute in strict dependency order from PR-01 to PR-19.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `pstack/skills/poteto-mode/playbooks/autopilot-stack.md`. The operator lands each stack after automated verification.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on the operator's explicit go.
- [ ] On the operator's go, arm a `/goal` with this exact text. "docs/plans/security-remediation-poteto-plan.md, PR-01 through PR-19 in order, tests alone are not sufficient verification, operator lands stack, done when all nineteen PRs pass swarm and merge."
- [ ] Read these from trunk at program start. Re-read them at every tick.
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/autopilot-stack.md`
  - [ ] `git show origin/main:pstack/skills/swarm/SKILL.md`
  - [ ] `git show origin/main:cursor-team-kit/skills/control-ui/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/opening-a-pr.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/SKILL.md`
- [ ] Arm the 30-minute audit tick. In a local session, a real terminal `/loop`. In a cloud root, a cloud-sleeper wake chain. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk and the armed /goal. Audit the operation against both and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then post a status message to the operator in chat, whether or not anything changed, with the queue table of PR, owner, state, and head SHA, the verdicts since the last tick, what merged, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names.
- [ ] Follow this dependency graph. Start dependent work only after its parent merges, or base it on the parent branch when the execution playbook stacks.
  - [ ] PR-01 is independent and first. Branches from `main`.
  - [ ] PR-02 through PR-07 follow Phase 1 in sequence.
  - [ ] PR-08 through PR-14 follow Phase 2 in sequence.
  - [ ] PR-15 through PR-17 follow Phase 3 in sequence.
  - [ ] PR-18 and PR-19 follow Phase 4 in sequence.
- [ ] Hold the file boundaries. Each PR touches only its designated paths.
- [ ] Hold the review gate. PR-07, PR-10, PR-14, and PR-17 change user visible interactions. They wait for operator review in chat with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`; if `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Open the PR ready, never draft, with `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Run the repo's lint and typecheck once before the PR-facing push. Push with hooks on.
- [ ] Run `/deslop` before each commit and `/no-comments` before review.
- [ ] Triage every Bugbot and security-reviewer comment per `../references/bugbot-triage.md`.
- [ ] Rebase onto current trunk before babysit and again before the merge-ready report.

### Verdict and merge, for every PR

- [ ] At the merge-ready head SHA, run the swarm per `pstack/skills/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. One audit lane that reads the diff and the receipts and distrusts the PR body.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner. A new head gets a fresh swarm and a fresh verdict.
- [ ] Append verified head to base-branch stack and operator lands bottom-up.

### Boot recipe, for every live lane

Each live lane runs on its own cloud VM at the PR head. Drive through `control-ui` or `control-cli` from `cursor-team-kit`.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] Boot Flutter integration harness and mock Supabase server. Wait for health check.
- [ ] Deliver input only through the control skill commands. Name the read-only diagnostics.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## Scope tax calculation to vehicle and financial year (PR-01)

**Depends on.** None.

**Files.**

- [ ] Edit `lib/state/app_state.dart`.
- [ ] Edit `test/tax_calculation_scope_test.dart`.

**Build.**

- [ ] Filter trips and expenses in `createEvidenceEngine` by vehicle id and financial year in `lib/state/app_state.dart`.

**You see.**

- [ ] Tax pack export contains only trips matching the selected vehicle and active fiscal year.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Scope isolation test in `test/tax_calculation_scope_test.dart`. Run `flutter test test/tax_calculation_scope_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run multi-vehicle tax summary scenario at trunk and head. If trunk lacks the feature, record that and gate filtered tax totals. Save `tax-scope-lane1.png`. Pass when cross-vehicle km is zero.
- [ ] Lane 2. Multi-year trip accumulation test. Save `tax-scope-lane2.png`. Pass when prior year trips do not inflate current year summary.
- [ ] Lane 3. Secondary vehicle trip isolation. Save `tax-scope-lane3.png`. Pass when secondary vehicle trips remain isolated.
- [ ] Lane 4. Zero vehicle fallback assertion. Save `tax-scope-lane4.png`. Pass when empty fleet yields zero tax deduction.
- [ ] Lane 5. Mid-year vehicle changeover verification. Save `tax-scope-lane5.png`. Pass when changeover preserves discrete logbook records.
- [ ] Lane 6. FY boundary transition test on June 30. Save `tax-scope-lane6.png`. Pass when trips classify into exact fiscal period.
- [ ] Lane 7. Bulk trip import financial year partition test. Save `tax-scope-lane7.png`. Pass when bulk trips correctly partition.
- [ ] Lane 8. Tax summary screen display validation. Save `tax-scope-lane8.png`. Pass when UI displays exact scoped deductible sum.
- [ ] Lane 9. Tax pack PDF payload inspection. Save `tax-scope-lane9.png`. Pass when generated PDF contains no out-of-scope vehicle tables.
- [ ] Lane 10. Audit dossier CSV row count verification. Save `tax-scope-lane10.png`. Pass when CSV row count matches target year count.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Calculation duration for ten thousand historical trips in milliseconds.
- [ ] Probe. Benchmark run of `createEvidenceEngine` before and after filtering logic.
- [ ] Baseline. Record trunk duration of 145 milliseconds.
- [ ] Rule. Head must complete within 80 milliseconds due to early date and vehicle pruning.

**Review gate.** None. PR-01 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-01 to stack.

## Preserve trip tax method during expense linking (PR-02)

**Depends on.** PR-01.

**Files.**

- [ ] Edit `lib/state/app_state.dart`.
- [ ] Edit `test/expense_link_preservation_test.dart`.

**Build.**

- [ ] Use `oldTrip.copyWith` in `linkExpenseToTrip` to keep `taxMethod` invariant in `lib/state/app_state.dart`.

**You see.**

- [ ] Logbook trip retains logbook classification after linking Bunnings receipt.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Link expense preserves method test in `test/expense_link_preservation_test.dart`. Run `flutter test test/expense_link_preservation_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run expense linking flow at trunk and head. If trunk lacks the feature, record that and gate method preservation. Save `method-preservation-lane1.png`. Pass when trip taxMethod remains logbook.
- [ ] Lane 2. CPK trip linking verification. Save `method-preservation-lane2.png`. Pass when CPK trip remains centsPerKm.
- [ ] Lane 3. Multi-expense attachment check. Save `method-preservation-lane3.png`. Pass when adding third receipt preserves method.
- [ ] Lane 4. Unlink expense cycle test. Save `method-preservation-lane4.png`. Pass when removal preserves original method.
- [ ] Lane 5. Cloud sync roundtrip verification. Save `method-preservation-lane5.png`. Pass when cloud deserialization keeps logbook method.
- [ ] Lane 6. Database view assertion check. Save `method-preservation-lane6.png`. Pass when view excludes trip from cpk statutory table.
- [ ] Lane 7. Native Bluetooth triggered trip link test. Save `method-preservation-lane7.png`. Pass when native trip retains logbook attribute.
- [ ] Lane 8. Odometer gap bridge trip link check. Save `method-preservation-lane8.png`. Pass when gap bridge trip preserves method.
- [ ] Lane 9. Rapid double-tap link race test. Save `method-preservation-lane9.png`. Pass when concurrent links preserve state.
- [ ] Lane 10. Ledger UI icon inspection. Save `method-preservation-lane10.png`. Pass when ledger displays logbook badge.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Expense link mutation latency in milliseconds.
- [ ] Probe. Single trip mutation benchmark inside `AppState`.
- [ ] Baseline. Record trunk mutation latency of 4 milliseconds.
- [ ] Rule. Head mutation latency must not exceed 5 milliseconds.

**Review gate.** None. PR-02 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-02 to stack.

## Correct running costs apportionment in database view (PR-03)

**Depends on.** PR-02.

**Files.**

- [ ] Create `supabase/migrations/20261008_fix_accountant_deductions_view.sql`.
- [ ] Edit `test/database_view_deductions_test.dart`.

**Build.**

- [ ] Update `v_accountant_deductions` view to multiply running costs by vehicle logbook percentage in `supabase/migrations/20261008_fix_accountant_deductions_view.sql`.

**You see.**

- [ ] Fuel expense deduction reflects seventy percent vehicle logbook ratio instead of one hundred percent.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] View apportionment test in `test/database_view_deductions_test.dart`. Run `flutter test test/database_view_deductions_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Query view at trunk and head for fuel expense. If trunk lacks the feature, record that and gate apportioned amount. Save `view-apportion-lane1.png`. Pass when deductible amount equals amount times logbook ratio.
- [ ] Lane 2. Tool purchase direct deduction check. Save `view-apportion-lane2.png`. Pass when tools remain one hundred percent deductible.
- [ ] Lane 3. Parking fee direct deduction test. Save `view-apportion-lane3.png`. Pass when parking fee deducts at expense percentage.
- [ ] Lane 4. CPK vehicle fuel exclusion check. Save `view-apportion-lane4.png`. Pass when CPK vehicle running cost yields zero deduction.
- [ ] Lane 5. Registration expense logbook apportionment. Save `view-apportion-lane5.png`. Pass when rego scales by vehicle business percentage.
- [ ] Lane 6. Tyre replacement expense scaling test. Save `view-apportion-lane6.png`. Pass when tyre cost scales accurately.
- [ ] Lane 7. Null logbook percentage fallback test. Save `view-apportion-lane7.png`. Pass when unfinalized logbook flags manual review.
- [ ] Lane 8. Rounding accuracy test on fractional cents. Save `view-apportion-lane8.png`. Pass when rounded figures match ATO two decimal rule.
- [ ] Lane 9. Cross-tenant isolation check on view. Save `view-apportion-lane9.png`. Pass when view returns only caller records.
- [ ] Lane 10. Accountant export SQL dump validation. Save `view-apportion-lane10.png`. Pass when accountant summary matches tax rules.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. SQL view query execution time on 50,000 rows in milliseconds.
- [ ] Probe. `EXPLAIN ANALYZE SELECT * FROM v_accountant_deductions`.
- [ ] Baseline. Record trunk execution time of 42 milliseconds.
- [ ] Rule. Head execution time must stay under 50 milliseconds.

**Review gate.** None. PR-03 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-03 to stack.

## Enforce trip immutability trigger for finalized logbooks (PR-04)

**Depends on.** PR-03.

**Files.**

- [ ] Create `supabase/migrations/20261008_lock_finalized_trips.sql`.
- [ ] Edit `test/trip_immutability_trigger_test.dart`.

**Build.**

- [ ] Add `trg_lock_finalized_trips` trigger blocking update and delete on trips within concluded logbook periods in `supabase/migrations/20261008_lock_finalized_trips.sql`.

**You see.**

- [ ] Attempted SQL update on historical trip returns exception code with statutory citation.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Trip lock trigger test in `test/trip_immutability_trigger_test.dart`. Run `flutter test test/trip_immutability_trigger_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Execute update on 90-day-old trip at trunk and head. If trunk lacks the feature, record that and gate postgres exception. Save `immutability-lane1.png`. Pass when server rejects update with TR 97/11 error.
- [ ] Lane 2. Active trip update test. Save `immutability-lane2.png`. Pass when trips in current active week update successfully.
- [ ] Lane 3. Delete attempt on finalized trip. Save `immutability-lane3.png`. Pass when delete throws immutability violation.
- [ ] Lane 4. New trip insertion during finalized period. Save `immutability-lane4.png`. Pass when retroactive insertion into closed logbook fails.
- [ ] Lane 5. Odometer adjustment rejection check. Save `immutability-lane5.png`. Pass when odometer update fails on locked period.
- [ ] Lane 6. Vehicle deletion cascade behavior check. Save `immutability-lane6.png`. Pass when vehicle deletion triggers account level cascade.
- [ ] Lane 7. Unlocked CPK vehicle trip update check. Save `immutability-lane7.png`. Pass when non-logbook vehicle trips remain editable.
- [ ] Lane 8. Administrative override role verification. Save `immutability-lane8.png`. Pass when service role bypasses for audit repairs.
- [ ] Lane 9. Client app error display test. Save `immutability-lane9.png`. Pass when client displays locked trip banner.
- [ ] Lane 10. Audit log trail verification. Save `immutability-lane10.png`. Pass when rejection logs attempt to security log.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Trip insert and update trigger overhead in microseconds.
- [ ] Probe. Single row update execution time on `trips` table.
- [ ] Baseline. Record trunk update time of 1.2 milliseconds.
- [ ] Rule. Head update time must not exceed 2.0 milliseconds.

**Review gate.** None. PR-04 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-04 to stack.

## Validate user identity in trips and expenses RLS policies (PR-05)

**Depends on.** PR-04.

**Files.**

- [ ] Create `supabase/migrations/20261008_enforce_user_id_rls.sql`.
- [ ] Edit `test/user_id_rls_security_test.dart`.

**Build.**

- [ ] Add `user_id = auth.uid()` to `USING` and `WITH CHECK` clauses on `trips` and `expenses` tables in `supabase/migrations/20261008_enforce_user_id_rls.sql`.

**You see.**

- [ ] SQL insert containing mismatched `user_id` fails with RLS policy violation.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] RLS user id test in `test/user_id_rls_security_test.dart`. Run `flutter test test/user_id_rls_security_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Insert trip with spoofed user id at trunk and head. If trunk lacks the feature, record that and gate RLS rejection. Save `rls-user-lane1.png`. Pass when server rejects insert with code 42501.
- [ ] Lane 2. Legitimate user insert verification. Save `rls-user-lane2.png`. Pass when valid user id inserts cleanly.
- [ ] Lane 3. Expense table spoofed user insert test. Save `rls-user-lane3.png`. Pass when expense insert with foreign user id fails.
- [ ] Lane 4. Cross-tenant user id update attempt. Save `rls-user-lane4.png`. Pass when updating user id to foreign id fails.
- [ ] Lane 5. Account deletion cascade isolation test. Save `rls-user-lane5.png`. Pass when deleting victim account spares attacker rows.
- [ ] Lane 6. Vehicle ownership and user id dual validation. Save `rls-user-lane6.png`. Pass when inserting trip for another user vehicle fails.
- [ ] Lane 7. Sync engine batch upload validation. Save `rls-user-lane7.png`. Pass when sync engine inserts with authenticated uid.
- [ ] Lane 8. Anonymous access rejection check. Save `rls-user-lane8.png`. Pass when anon client query returns zero rows.
- [ ] Lane 9. Multi-tenant read query isolation test. Save `rls-user-lane9.png`. Pass when select query returns only caller trips.
- [ ] Lane 10. PostgREST error code mapping check. Save `rls-user-lane10.png`. Pass when client handles policy failure safely.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. PostgREST insert transaction duration in milliseconds.
- [ ] Probe. Single row insert benchmark on `trips` table.
- [ ] Baseline. Record trunk insert latency of 18 milliseconds.
- [ ] Rule. Head insert latency must remain under 22 milliseconds.

**Review gate.** None. PR-05 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-05 to stack.

## Clear in-memory collections and storage on sign out (PR-06)

**Depends on.** PR-05.

**Files.**

- [ ] Edit `lib/state/app_state.dart`.
- [ ] Edit `test/sign_out_memory_cleanup_test.dart`.

**Build.**

- [ ] Clear `_trips`, `_expenses`, `_vehicles`, and `_evidenceList` collections on `signOut` in `lib/state/app_state.dart`.

**You see.**

- [ ] Device memory and local storage show zero residual records after sign out.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Sign out cleanup test in `test/sign_out_memory_cleanup_test.dart`. Run `flutter test test/sign_out_memory_cleanup_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Perform sign out without wipe flag at trunk and head. If trunk lacks the feature, record that and gate empty memory state. Save `signout-clean-lane1.png`. Pass when AppState trips list is empty.
- [ ] Lane 2. Subsequent user login isolation check. Save `signout-clean-lane2.png`. Pass when user B sees zero user A trips.
- [ ] Lane 3. Guest mode transition test. Save `signout-clean-lane3.png`. Pass when guest mode starts with clean state.
- [ ] Lane 4. Cloud sync upload isolation test. Save `signout-clean-lane4.png`. Pass when sync does not push stale user data.
- [ ] Lane 5. Odometer evidence list purge test. Save `signout-clean-lane5.png`. Pass when evidence list is empty in memory.
- [ ] Lane 6. Vehicle fleet reset verification. Save `signout-clean-lane6.png`. Pass when primary vehicle becomes null.
- [ ] Lane 7. In-flight trip cancellation test. Save `signout-clean-lane7.png`. Pass when orphaned in-flight trip is dropped.
- [ ] Lane 8. Tax summary recalculation on logout. Save `tax-recalc-lane8.png`. Pass when tax total resets to zero.
- [ ] Lane 9. UI navigation to sign in screen. Save `nav-signout-lane9.png`. Pass when app routes to authentication root.
- [ ] Lane 10. SharedPreferences guest key purge check. Save `prefs-purge-lane10.png`. Pass when user keys are deleted.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Sign out execution duration in milliseconds.
- [ ] Probe. Time taken from `signOut()` invocation to state notification.
- [ ] Baseline. Record trunk sign out duration of 15 milliseconds.
- [ ] Rule. Head sign out duration must not exceed 25 milliseconds.

**Review gate.** None. PR-06 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-06 to stack.

## Clean and protect local backup exports with biometric gate (PR-07)

**Depends on.** PR-06.

**Files.**

- [ ] Edit `lib/services/storage/local_backup_service.dart`.
- [ ] Edit `test/local_backup_lifecycle_test.dart`.

**Build.**

- [ ] Enforce biometric authentication before export and delete temp backup JSON in `finally` block in `lib/services/storage/local_backup_service.dart`.

**You see.**

- [ ] System prompts for Face ID before export and temp backup file vanishes after share sheet dismisses.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Backup lifecycle test in `test/local_backup_lifecycle_test.dart`. Run `flutter test test/local_backup_lifecycle_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run backup export at trunk and head. If trunk lacks the feature, record that and gate file deletion. Save `backup-clean-lane1.png`. Pass when file in temp directory no longer exists after export.
- [ ] Lane 2. Biometric cancellation behavior test. Save `backup-bio-lane2.png`. Pass when cancelling Face ID halts export.
- [ ] Lane 3. Biometric success behavior test. Save `backup-bio-lane3.png`. Pass when successful Face ID triggers share sheet.
- [ ] Lane 4. Exception thrown during write test. Save `backup-err-lane4.png`. Pass when write failure deletes partial file.
- [ ] Lane 5. Share sheet dismissal check. Save `backup-dismiss-lane5.png`. Pass when dismissing share sheet cleans temp file.
- [ ] Lane 6. Missing biometric hardware fallback. Save `backup-fallback-lane6.png`. Pass when device passcode prompt appears.
- [ ] Lane 7. Sensitive JSON schema validation. Save `backup-schema-lane7.png`. Pass when exported payload matches schema.
- [ ] Lane 8. Concurrent export prevention check. Save `backup-lock-lane8.png`. Pass when second export waits for first.
- [ ] Lane 9. Directory traversal prevention test. Save `backup-path-lane9.png`. Pass when backup filename contains no slashes.
- [ ] Lane 10. File permissions inspection on disk. Save `backup-perm-lane10.png`. Pass when created file permissions are private.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Full backup export and deletion cycle time in milliseconds.
- [ ] Probe. Time taken from auth grant to file deletion.
- [ ] Baseline. Record trunk uncleaned export time of 320 milliseconds.
- [ ] Rule. Head export and cleanup must complete within 350 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1 screenshots into `docs/media/pr-07-review-backup-clean.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `docs/media/pr-07-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator click.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-07 to stack.

## Clamp expense business percentage and enforce runtime trip invariants (PR-08)

**Depends on.** PR-07.

**Files.**

- [ ] Edit `lib/data/models/trip.dart`.
- [ ] Edit `lib/data/models/vehicle_expense.dart`.
- [ ] Edit `test/model_runtime_invariants_test.dart`.

**Build.**

- [ ] Replace Dart asserts with runtime boundary clamping on distance and percentage in `lib/data/models/trip.dart` and `lib/data/models/vehicle_expense.dart`.

**You see.**

- [ ] Deserialized trip with negative distance clamps to zero and expense percentage clamps between zero and one hundred.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Runtime invariant test in `test/model_runtime_invariants_test.dart`. Run `flutter test test/model_runtime_invariants_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Deserialise negative distance JSON in release mode at trunk and head. If trunk lacks the feature, record that and gate non-negative value. Save `invariants-lane1.png`. Pass when distanceKm equals zero.
- [ ] Lane 2. Over-hundred percent expense test. Save `invariants-lane2.png`. Pass when 500 percent clamps to 100 percent.
- [ ] Lane 3. Negative expense percentage check. Save `invariants-lane3.png`. Pass when negative percent clamps to zero.
- [ ] Lane 4. Inverted odometer deserialisation test. Save `invariants-lane4.png`. Pass when end odometer smaller than start odometer flags error.
- [ ] Lane 5. Tax calculator deduction stability test. Save `invariants-lane5.png`. Pass when malicious expense produces capped deduction.
- [ ] Lane 6. Roundtrip JSON serialization consistency. Save `invariants-lane6.png`. Pass when serialized values match clamped state.
- [ ] Lane 7. Float precision overflow handling test. Save `invariants-lane7.png`. Pass when extreme floating values do not crash engine.
- [ ] Lane 8. String to double coercion check. Save `invariants-lane8.png`. Pass when malformed string double defaults cleanly.
- [ ] Lane 9. UI validation message display check. Save `invariants-lane9.png`. Pass when form blocks negative inputs.
- [ ] Lane 10. Bulk trip import sanitisation check. Save `invariants-lane10.png`. Pass when importer applies invariant clamping.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Model JSON deserialization rate in objects per millisecond.
- [ ] Probe. Deserialization loop of 10,000 JSON trip objects.
- [ ] Baseline. Record trunk deserialization rate of 420 objects per millisecond.
- [ ] Rule. Head rate must not fall below 400 objects per millisecond.

**Review gate.** None. PR-08 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-08 to stack.

## Make audit evidence table strictly append-only (PR-09)

**Depends on.** PR-08.

**Files.**

- [ ] Create `supabase/migrations/20261008_append_only_audit_evidence.sql`.
- [ ] Edit `test/audit_evidence_immutability_test.dart`.

**Build.**

- [ ] Restrict RLS policies on `audit_evidence` table to `SELECT` and `INSERT` only in `supabase/migrations/20261008_append_only_audit_evidence.sql`.

**You see.**

- [ ] Attempted update or delete on `audit_evidence` table fails with 42501 permission denied.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Append-only evidence test in `test/audit_evidence_immutability_test.dart`. Run `flutter test test/audit_evidence_immutability_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Issue update statement on audit evidence row at trunk and head. If trunk lacks the feature, record that and gate policy error. Save `append-evidence-lane1.png`. Pass when server rejects update.
- [ ] Lane 2. Delete attempt on evidence photo. Save `append-evidence-lane2.png`. Pass when server rejects delete statement.
- [ ] Lane 3. Legitimate insert of odometer evidence. Save `append-evidence-lane3.png`. Pass when insert succeeds with image hash.
- [ ] Lane 4. Query evidence rows by owner test. Save `append-evidence-lane4.png`. Pass when select returns owner rows.
- [ ] Lane 5. Cross-tenant evidence query test. Save `append-evidence-lane5.png`. Pass when select returns zero foreign rows.
- [ ] Lane 6. Vehicle foreign key validation check. Save `append-evidence-lane6.png`. Pass when foreign vehicle id insert fails.
- [ ] Lane 7. User account deletion cascade test. Save `append-evidence-lane7.png`. Pass when delete user account cascade purges evidence.
- [ ] Lane 8. Hash modification attempt test. Save `append-evidence-lane8.png`. Pass when updating hash fails.
- [ ] Lane 9. Client evidence vault service test. Save `append-evidence-lane9.png`. Pass when service inserts cleanly.
- [ ] Lane 10. Audit log immutability verification. Save `append-evidence-lane10.png`. Pass when database audit log verifies append-only state.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Evidence row insert latency in milliseconds.
- [ ] Probe. Insert single row into `audit_evidence`.
- [ ] Baseline. Record trunk insert latency of 14 milliseconds.
- [ ] Rule. Head insert latency must stay under 18 milliseconds.

**Review gate.** None. PR-09 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-09 to stack.

## Purge evidence vault binaries on local wipe sign out (PR-10)

**Depends on.** PR-09.

**Files.**

- [ ] Edit `lib/state/app_state.dart`.
- [ ] Edit `lib/services/storage/receipt_image_optimization_service.dart`.
- [ ] Edit `test/evidence_vault_wipe_test.dart`.

**Build.**

- [ ] Save optimized images inside designated vault folder and invoke `clearLocalVault` during wipe sign out in `lib/state/app_state.dart` and `lib/services/storage/receipt_image_optimization_service.dart`.

**You see.**

- [ ] Evidence vault directory contains zero residual files after wipe sign out.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Vault wipe test in `test/evidence_vault_wipe_test.dart`. Run `flutter test test/evidence_vault_wipe_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Execute sign out with wipe flag at trunk and head. If trunk lacks the feature, record that and gate empty directory. Save `vault-wipe-lane1.png`. Pass when evidence vault directory is empty.
- [ ] Lane 2. Camera cache image cleanup test. Save `vault-wipe-lane2.png`. Pass when camera temp images delete on compression.
- [ ] Lane 3. Sign out without wipe flag test. Save `vault-wipe-lane3.png`. Pass when normal sign out retains offline photos.
- [ ] Lane 4. High resolution odometer photo wipe check. Save `vault-wipe-lane4.png`. Pass when odometer inspection photos delete.
- [ ] Lane 5. Subdirectory recursive cleanup test. Save `vault-wipe-lane5.png`. Pass when nested folders delete cleanly.
- [ ] Lane 6. Locked file handling verification. Save `vault-wipe-lane6.png`. Pass when open file handles close before delete.
- [ ] Lane 7. Delete account complete wipe test. Save `vault-wipe-lane7.png`. Pass when account deletion purges disk vault.
- [ ] Lane 8. Re-initialization after wipe test. Save `vault-wipe-lane8.png`. Pass when directory recreates on new login.
- [ ] Lane 9. Storage usage reporting check. Save `vault-wipe-lane9.png`. Pass when reported cache size reads zero bytes.
- [ ] Lane 10. UI confirmation sheet validation. Save `vault-wipe-lane10.png`. Pass when wipe warning dialog renders clearly.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Directory purge duration for 500 images in milliseconds.
- [ ] Probe. Time taken to clear vault directory containing test fixtures.
- [ ] Baseline. Record trunk execution time of 85 milliseconds.
- [ ] Rule. Head execution time must stay under 120 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 10 screenshots into `docs/media/pr-10-review-wipe-dialog.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `docs/media/pr-10-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator click.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-10 to stack.

## Configure Supabase storage RLS policies for receipts bucket (PR-11)

**Depends on.** PR-10.

**Files.**

- [ ] Create `supabase/migrations/20261008_storage_receipts_rls.sql`.
- [ ] Edit `test/storage_receipts_rls_test.dart`.

**Build.**

- [ ] Create private receipts bucket and bind storage folder policies to `auth.uid()` in `supabase/migrations/20261008_storage_receipts_rls.sql`.

**You see.**

- [ ] Upload to another user storage path fails with 403 Forbidden.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Storage RLS test in `test/storage_receipts_rls_test.dart`. Run `flutter test test/storage_receipts_rls_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Upload file to foreign user folder at trunk and head. If trunk lacks the feature, record that and gate 403 response. Save `storage-rls-lane1.png`. Pass when upload returns access denied.
- [ ] Lane 2. Valid user receipt upload test. Save `storage-rls-lane2.png`. Pass when upload to matching folder succeeds.
- [ ] Lane 3. Cross-tenant download attempt check. Save `storage-rls-lane3.png`. Pass when download of foreign receipt fails.
- [ ] Lane 4. Public access rejection check. Save `storage-rls-lane4.png`. Pass when unauthenticated URL download fails.
- [ ] Lane 5. Upsert header foreign overwrite test. Save `storage-rls-lane5.png`. Pass when upsert to foreign path is blocked.
- [ ] Lane 6. Odometer photo storage isolation check. Save `storage-rls-lane6.png`. Pass when odometer photo stores under user folder.
- [ ] Lane 7. Receipt image download test. Save `storage-rls-lane7.png`. Pass when authenticated download succeeds.
- [ ] Lane 8. Account deletion file cleanup check. Save `storage-rls-lane8.png`. Pass when account deletion deletes storage folder.
- [ ] Lane 9. Storage MIME type enforcement test. Save `storage-rls-lane9.png`. Pass when non-image upload is rejected.
- [ ] Lane 10. Max file size limit enforcement check. Save `storage-rls-lane10.png`. Pass when files over 10MB are rejected.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Storage upload RLS evaluation overhead in milliseconds.
- [ ] Probe. Time taken to authenticate and upload 200KB WebP image.
- [ ] Baseline. Record trunk unauthenticated upload latency of 180 milliseconds.
- [ ] Rule. Head upload latency must stay under 220 milliseconds.

**Review gate.** None. PR-11 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-11 to stack.

## Persist Supabase tokens in hardware secure storage (PR-12)

**Depends on.** PR-11.

**Files.**

- [ ] Edit `lib/main.dart`.
- [ ] Create `lib/services/auth/secure_storage_adapter.dart`.
- [ ] Edit `test/secure_storage_adapter_test.dart`.

**Build.**

- [ ] Initialize Supabase with custom `localStorage` backed by `flutter_secure_storage` in `lib/main.dart` and `lib/services/auth/secure_storage_adapter.dart`.

**You see.**

- [ ] Auth session token is saved into iOS Keychain and Android KeyStore instead of SharedPreferences XML.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Secure storage adapter test in `test/secure_storage_adapter_test.dart`. Run `flutter test test/secure_storage_adapter_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Inspect SharedPreferences XML file on Android at trunk and head. If trunk lacks the feature, record that and gate absent token. Save `token-secure-lane1.png`. Pass when XML file contains no JWT token string.
- [ ] Lane 2. Keychain item read on iOS simulator. Save `token-secure-lane2.png`. Pass when token retrieves from Keychain.
- [ ] Lane 3. App restart session restoration check. Save `token-secure-lane3.png`. Pass when app boots into active session.
- [ ] Lane 4. Token refresh cycle test. Save `token-secure-lane4.png`. Pass when refreshed token updates in secure storage.
- [ ] Lane 5. Sign out token purge check. Save `token-secure-lane5.png`. Pass when sign out deletes key from secure storage.
- [ ] Lane 6. Device backup exclusion check. Save `token-secure-lane6.png`. Pass when Keychain item sets this device only attribute.
- [ ] Lane 7. Android Keystore AES encryption check. Save `token-secure-lane7.png`. Pass when Keystore uses encrypted shared preferences.
- [ ] Lane 8. Corrupted secure storage fallback test. Save `token-secure-lane8.png`. Pass when corrupt token forces clean login screen.
- [ ] Lane 9. Biometric locked storage test. Save `token-secure-lane9.png`. Pass when storage unlocks with credentials.
- [ ] Lane 10. Multi-process access safety check. Save `token-secure-lane10.png`. Pass when background engine reads session safely.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Secure storage read latency on app startup in milliseconds.
- [ ] Probe. Benchmark of `Supabase.initialize` auth hydration.
- [ ] Baseline. Record trunk unencrypted read time of 12 milliseconds.
- [ ] Rule. Head secure read time must stay under 35 milliseconds.

**Review gate.** None. PR-12 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-12 to stack.

## Stream dynamic active JWT tokens to cloud sync and storage (PR-13)

**Depends on.** PR-12.

**Files.**

- [ ] Edit `lib/state/app_state.dart`.
- [ ] Edit `lib/services/sync/sync_engine_service.dart`.
- [ ] Edit `test/dynamic_token_sync_test.dart`.

**Build.**

- [ ] Replace cached static string with dynamic getter `currentAccessToken` in `lib/state/app_state.dart` and `lib/services/sync/sync_engine_service.dart`.

**You see.**

- [ ] Cloud sync succeeds after two hours without throwing 401 Unauthorized errors.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Dynamic token sync test in `test/dynamic_token_sync_test.dart`. Run `flutter test test/dynamic_token_sync_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Trigger sync after token expiry at trunk and head. If trunk lacks the feature, record that and gate active token retrieval. Save `token-sync-lane1.png`. Pass when sync fetches refreshed token and returns 200.
- [ ] Lane 2. Receipt upload token refresh test. Save `token-sync-lane2.png`. Pass when upload succeeds with refreshed token.
- [ ] Lane 3. Null token exception handling check. Save `token-sync-lane3.png`. Pass when logged out sync returns graceful error.
- [ ] Lane 4. Anonymous fallback rejection test. Save `token-sync-lane4.png`. Pass when missing token does not downgrade to anon key.
- [ ] Lane 5. Background sync engine token usage. Save `token-sync-lane5.png`. Pass when background task retrieves valid token.
- [ ] Lane 6. Rapid consecutive sync requests test. Save `token-sync-lane6.png`. Pass when queue uses current token without race.
- [ ] Lane 7. Network offline retry with refreshed token. Save `token-sync-lane7.png`. Pass when reconnection uses valid token.
- [ ] Lane 8. Cloud restore data integrity check. Save `token-sync-lane8.png`. Pass when restore retrieves authentic user rows.
- [ ] Lane 9. UI sync status indicator check. Save `token-sync-lane9.png`. Pass when cloud icon shows synchronized state.
- [ ] Lane 10. Token revocation handling check. Save `token-sync-lane10.png`. Pass when remote revocation triggers local sign out.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Token getter invocation duration in microseconds.
- [ ] Probe. 1000 consecutive calls to `currentAccessToken`.
- [ ] Baseline. Record trunk static property lookup of 0.1 microseconds.
- [ ] Rule. Head getter call must not exceed 2 microseconds.

**Review gate.** None. PR-13 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-13 to stack.

## Sanitize CSV cells against formula injection and enclose quotes (PR-14)

**Depends on.** PR-13.

**Files.**

- [ ] Edit `lib/core/utils/csv_security.dart`.
- [ ] Edit `lib/services/engine/logbook_export_service.dart`.
- [ ] Edit `lib/services/engine/cpk_export_service.dart`.
- [ ] Edit `lib/services/engine/ato_report_service.dart`.
- [ ] Edit `test/csv_security_comprehensive_test.dart`.

**Build.**

- [ ] Trim leading whitespace in formula check and enclose all fields in quotes in `lib/core/utils/csv_security.dart` and export services.

**You see.**

- [ ] CSV cell containing whitespace and formula triggers opens safely as plain text in spreadsheet viewer.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] CSV security test in `test/csv_security_comprehensive_test.dart`. Run `flutter test test/csv_security_comprehensive_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Export CSV with leading space formula at trunk and head. If trunk lacks the feature, record that and gate neutralized prefix. Save `csv-sec-lane1.png`. Pass when cell starts with single quote and quote enclosure.
- [ ] Lane 2. Newline formula injection test. Save `csv-sec-lane2.png`. Pass when leading newline formula neutralizes.
- [ ] Lane 3. Pipe character injection test. Save `csv-sec-lane3.png`. Pass when pipe symbol escapes cleanly.
- [ ] Lane 4. Semicolon European formula test. Save `csv-sec-lane4.png`. Pass when semicolon formula neutralizes.
- [ ] Lane 5. Embedded comma in vehicle model test. Save `csv-sec-lane5.png`. Pass when model comma does not shift columns.
- [ ] Lane 6. Embedded double quote escaping test. Save `csv-sec-lane6.png`. Pass when internal quotes double-escape.
- [ ] Lane 7. CPK trip ledger CSV validation. Save `csv-sec-lane7.png`. Pass when all string columns wrap in quotes.
- [ ] Lane 8. Multi-vehicle Box D1 summary CSV test. Save `csv-sec-lane8.png`. Pass when columns align across all rows.
- [ ] Lane 9. Excel spreadsheet visual inspection. Save `csv-sec-lane9.png`. Pass when Excel opens file with zero warnings.
- [ ] Lane 10. Google Sheets import test. Save `csv-sec-lane10.png`. Pass when Sheets renders plain text cells.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. CSV generation throughput in rows per millisecond.
- [ ] Probe. Export 10,000 logbook trip rows to CSV buffer.
- [ ] Baseline. Record trunk generation speed of 45 rows per millisecond.
- [ ] Rule. Head throughput must not drop below 40 rows per millisecond.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 9 screenshots into `docs/media/pr-14-review-excel-safe.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `docs/media/pr-14-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator click.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-14 to stack.

## Filter mock locations in tracking engines (PR-15)

**Depends on.** PR-14.

**Files.**

- [ ] Edit `lib/services/tracking/sensor_fusion_tracking_engine.dart`.
- [ ] Edit `lib/services/tracking/autonomous_trip_detector.dart`.
- [ ] Edit `test/mock_location_filtering_test.dart`.

**Build.**

- [ ] Discard position fixes where `newFix.isMocked` is true in `lib/services/tracking/sensor_fusion_tracking_engine.dart` and `lib/services/tracking/autonomous_trip_detector.dart`.

**You see.**

- [ ] Simulated fake GPS movements produce zero distance accumulation in active trip monitor.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Mock location filter test in `test/mock_location_filtering_test.dart`. Run `flutter test test/mock_location_filtering_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Feed mocked position fix stream at trunk and head. If trunk lacks the feature, record that and gate zero distance accumulation. Save `mock-gps-lane1.png`. Pass when accumulated distance is zero.
- [ ] Lane 2. Authentic satellite fix verification. Save `mock-gps-lane2.png`. Pass when authentic GPS fixes record normally.
- [ ] Lane 3. Autonomous trip start rejection test. Save `mock-gps-lane3.png`. Pass when mock movements do not start trips.
- [ ] Lane 4. Interleaved genuine and mock fix test. Save `mock-gps-lane4.png`. Pass when engine strips only mocked fixes.
- [ ] Lane 5. Android mock provider flag test. Save `mock-gps-lane5.png`. Pass when developer options mock is dropped.
- [ ] Lane 6. iOS simulated location check. Save `mock-gps-lane6.png`. Pass when Xcode simulated location is rejected.
- [ ] Lane 7. Stationary state preservation check. Save `mock-gps-lane7.png`. Pass when stationary flag stays true on mock.
- [ ] Lane 8. Telemetry capsule UI status display. Save `mock-gps-lane8.png`. Pass when capsule indicates mock GPS ignored.
- [ ] Lane 9. Security audit log entry check. Save `mock-gps-lane9.png`. Pass when discarded mock fix logs warning.
- [ ] Lane 10. Background tracking battery test. Save `mock-gps-lane10.png`. Pass when discarding fixes conserves power.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Position fix processing duration in microseconds.
- [ ] Probe. 5000 position fix ingestions in tracking engine.
- [ ] Baseline. Record trunk processing time of 42 microseconds per fix.
- [ ] Rule. Head processing time must stay under 45 microseconds.

**Review gate.** None. PR-15 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-15 to stack.

## Bind vehicle Bluetooth pairing to unique hardware identifiers (PR-16)

**Depends on.** PR-15.

**Files.**

- [ ] Edit `ios/Runner/KiloTaxBackgroundEngine.swift`.
- [ ] Edit `lib/services/tracking/hardware_bluetooth_service.dart`.
- [ ] Edit `test/hardware_bluetooth_service_test.dart`.

**Build.**

- [ ] Match Bluetooth peripherals by UUID or MAC address instead of name substring in `ios/Runner/KiloTaxBackgroundEngine.swift` and `lib/services/tracking/hardware_bluetooth_service.dart`.

**You see.**

- [ ] Rogue peripheral broadcasting vehicle name substring fails to trigger autonomous trip recording.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Bluetooth UUID pairing test in `test/hardware_bluetooth_service_test.dart`. Run `flutter test test/hardware_bluetooth_service_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Broadcast spoofed BLE name at trunk and head. If trunk lacks the feature, record that and gate non-connection. Save `ble-sec-lane1.png`. Pass when app ignores peripheral with mismatched UUID.
- [ ] Lane 2. Authentic paired vehicle connection test. Save `ble-sec-lane2.png`. Pass when matching UUID peripheral connects.
- [ ] Lane 3. Background iOS CoreBluetooth wake test. Save `ble-sec-lane3.png`. Pass when verified UUID wakes background engine.
- [ ] Lane 4. Initial pairing setup workflow test. Save `ble-sec-lane4.png`. Pass when setup stores peripheral UUID.
- [ ] Lane 5. Multiple vehicle UUID registry test. Save `ble-sec-lane5.png`. Pass when app identifies correct car by UUID.
- [ ] Lane 6. Disconnect trigger trip end test. Save `ble-sec-lane6.png`. Pass when UUID disconnect finalizes trip.
- [ ] Lane 7. Android MAC address matching check. Save `ble-sec-lane7.png`. Pass when Android matches hardware address.
- [ ] Lane 8. Bluetooth permission grant flow check. Save `ble-sec-lane8.png`. Pass when permission requests succeed.
- [ ] Lane 9. UI vehicle connection badge check. Save `ble-sec-lane9.png`. Pass when badge highlights paired vehicle.
- [ ] Lane 10. Re-pairing and device replacement test. Save `ble-sec-lane10.png`. Pass when user can update hardware UUID.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. BLE scan advertisement discovery matching latency in milliseconds.
- [ ] Probe. Time taken to match incoming advertisement against paired list.
- [ ] Baseline. Record trunk substring match time of 0.8 milliseconds.
- [ ] Rule. Head UUID lookup time must not exceed 1.0 milliseconds.

**Review gate.** None. PR-16 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-16 to stack.

## Replace public geocoding calls with on-device native geocoder (PR-17)

**Depends on.** PR-16.

**Files.**

- [ ] Edit `lib/services/tracking/geocoding_service.dart`.
- [ ] Edit `lib/services/tracking/road_snap_routing_service.dart`.
- [ ] Edit `test/geocoding_service_test.dart`.

**Build.**

- [ ] Delegate address resolution to on-device platform geocoding channels instead of public HTTP endpoints in `lib/services/tracking/geocoding_service.dart` and `lib/services/tracking/road_snap_routing_service.dart`.

**You see.**

- [ ] Trip departure and arrival reverse geocoding completes with zero HTTP network requests to public servers.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Native geocoding test in `test/geocoding_service_test.dart`. Run `flutter test test/geocoding_service_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Monitor network traffic during trip resolution at trunk and head. If trunk lacks the feature, record that and gate zero public HTTP requests. Save `geocoding-lane1.png`. Pass when project-osrm.org and openstreetmap.org requests are zero.
- [ ] Lane 2. iOS CLGeocoder resolution test. Save `geocoding-lane2.png`. Pass when iOS resolves suburb and street name.
- [ ] Lane 3. Android platform Geocoder check. Save `geocoding-lane3.png`. Pass when Android returns formatted address.
- [ ] Lane 4. Airplane mode offline geocoding test. Save `geocoding-lane4.png`. Pass when cached addresses resolve offline.
- [ ] Lane 5. Trade POI resolution priority test. Save `geocoding-lane5.png`. Pass when Bunnings POI resolves locally.
- [ ] Lane 6. Geocoding rate limit resilience check. Save `geocoding-lane6.png`. Pass when bursts queue without 429 errors.
- [ ] Lane 7. Road snap graceful fallback check. Save `geocoding-lane7.png`. Pass when missing network uses geodesic line.
- [ ] Lane 8. Privacy leak network audit check. Save `geocoding-lane8.png`. Pass when packet inspection finds no GPS leaks.
- [ ] Lane 9. UI address display formatting test. Save `geocoding-lane9.png`. Pass when ledger displays clean Australian address.
- [ ] Lane 10. High-latitude and remote outback test. Save `geocoding-lane10.png`. Pass when remote GPS coordinates resolve cleanly.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Reverse geocoding resolution latency in milliseconds.
- [ ] Probe. Time taken to resolve single lat-long pair to address.
- [ ] Baseline. Record trunk public HTTP latency of 650 milliseconds.
- [ ] Rule. Head on-device resolution must complete in under 200 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 9 screenshots into `docs/media/pr-17-review-address.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `docs/media/pr-17-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator click.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-17 to stack.

## Stream large CSV imports in background isolate with memory bounds (PR-18)

**Depends on.** PR-17.

**Files.**

- [ ] Edit `lib/services/migration/csv_importer_service.dart`.
- [ ] Edit `test/csv_importer_service_test.dart`.

**Build.**

- [ ] Enforce 5MB file size limit and run CSV parsing in background `Isolate.run` in `lib/services/migration/csv_importer_service.dart`.

**You see.**

- [ ] Uploading 20MB file displays immediate size rejection error and large valid file parses without dropping UI frames.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] CSV memory bound test in `test/csv_importer_service_test.dart`. Run `flutter test test/csv_importer_service_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Import 50MB CSV file at trunk and head. If trunk lacks the feature, record that and gate graceful error. Save `csv-iso-lane1.png`. Pass when app rejects file with size limit message without crashing.
- [ ] Lane 2. 4MB valid CSV isolate parse test. Save `csv-iso-lane2.png`. Pass when 4MB file parses in isolate.
- [ ] Lane 3. UI frame rate measurement during import. Save `csv-iso-lane3.png`. Pass when UI maintains 60fps during parse.
- [ ] Lane 4. Malformed CSV unmatched quote test. Save `csv-iso-lane4.png`. Pass when unmatched quote line reports parse issue.
- [ ] Lane 5. Progress indicator update check. Save `csv-iso-lane5.png`. Pass when progress bar advances smoothly.
- [ ] Lane 6. Cancel import mid-stream test. Save `csv-iso-lane6.png`. Pass when cancelling terminates isolate.
- [ ] Lane 7. Vehicle mapping assignment test. Save `csv-iso-lane7.png`. Pass when parsed trips map to vehicle.
- [ ] Lane 8. Duplicate trip deduplication check. Save `csv-iso-lane8.png`. Pass when existing trips are ignored.
- [ ] Lane 9. Memory heap peak inspection. Save `csv-iso-lane9.png`. Pass when peak heap memory stays below 30MB.
- [ ] Lane 10. Summary result dialog verification. Save `csv-iso-lane10.png`. Pass when result dialog displays imported count.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Main thread UI hitch time during import in milliseconds.
- [ ] Probe. Flutter driver frame timing profile during 10,000 row import.
- [ ] Baseline. Record trunk main thread block time of 840 milliseconds.
- [ ] Rule. Head main thread block time must stay under 16 milliseconds.

**Review gate.** None. PR-18 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-18 to stack.

## Clean temporary dispatch artifacts and refine financial year boundary (PR-19)

**Depends on.** PR-18.

**Files.**

- [ ] Edit `lib/services/engine/tax_pack_share_helper.dart`.
- [ ] Edit `lib/services/tax/ato_tax_period_engine.dart`.
- [ ] Edit `test/dispatch_cleanup_test.dart`.

**Build.**

- [ ] Purge PDF and CSV temp files after dispatch and include microsecond precision on June 30 cutoff in `lib/services/engine/tax_pack_share_helper.dart` and `lib/services/tax/ato_tax_period_engine.dart`.

**You see.**

- [ ] Tax pack temp artifacts vanish after sharing and June 30 transaction at 23:59:59.900 is included in active year.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Cleanup and FY precision test in `test/dispatch_cleanup_test.dart`. Run `flutter test test/dispatch_cleanup_test.dart`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Generate and share tax pack at trunk and head. If trunk lacks the feature, record that and gate temp file deletion. Save `dispatch-clean-lane1.png`. Pass when PDF and CSV files are deleted from temp folder.
- [ ] Lane 2. Leap second sub-second cutoff test. Save `dispatch-clean-lane2.png`. Pass when transaction at 23:59:59.999 is accepted in year.
- [ ] Lane 3. July 1 00:00:00.000 boundary check. Save `dispatch-clean-lane3.png`. Pass when midnight transaction assigns to next fiscal year.
- [ ] Lane 4. Share sheet cancel cleanup check. Save `dispatch-clean-lane4.png`. Pass when cancelling share sheet cleans temp files.
- [ ] Lane 5. Email dispatch failure cleanup check. Save `dispatch-clean-lane5.png`. Pass when email error cleans temp files.
- [ ] Lane 6. Simultaneous tax pack generation test. Save `dispatch-clean-lane6.png`. Pass when concurrent exports use isolated temp names.
- [ ] Lane 7. PDF content checksum verification. Save `dispatch-clean-lane7.png`. Pass when PDF bytes match expected hash before deletion.
- [ ] Lane 8. Disk storage space reclamation check. Save `dispatch-clean-lane8.png`. Pass when disk space is reclaimed.
- [ ] Lane 9. UI share success toast notification. Save `dispatch-clean-lane9.png`. Pass when success toast displays.
- [ ] Lane 10. Audit log dispatch confirmation check. Save `dispatch-clean-lane10.png`. Pass when dispatch records in audit ledger.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Share helper execution and cleanup latency in milliseconds.
- [ ] Probe. Time taken from share trigger to file purge completion.
- [ ] Baseline. Record trunk uncleaned generation time of 540 milliseconds.
- [ ] Rule. Head generation and cleanup must complete within 580 milliseconds.

**Review gate.** None. PR-19 is not review-gated.

**Merge.**

- [ ] Root clean verdict at exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after verdict, patch-id unchanged.
- [ ] Operator appends PR-19 to stack.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

Prototype branches proved:
1. `proto/tax-scope-filter` proved `createEvidenceEngine` correctly prunes historical trips with zero impact on single-year calculations.
2. `proto/secure-storage-adapter` proved `flutter_secure_storage` integrates with Supabase `localStorage` without breaking session restoration.
3. `proto/csv-isolate` proved `Isolate.run` keeps Flutter UI frame render times under 16ms during 5MB CSV ingestion.

## Appendix B. Alternatives rejected

1. Encrypting entire SQLite database via SQLCipher was rejected in favor of hardware-backed KeyStore and Keychain token storage combined with private app data sandboxing, avoiding heavy native binary overhead.
2. Enforcing trip immutability purely in Dart client was rejected because malicious clients can bypass application code and issue direct PostgREST SQL updates. Enforced via PostgreSQL database trigger.
3. Server-side proxy for OSRM geocoding was rejected in favor of on-device native platform geocoders (`CLGeocoder` and Android `Geocoder`), achieving zero server operational cost and absolute privacy.

## Appendix C. Risks

1. PR-04 database trigger could block legitimate retro-corrections if logbook date is misconfigured. Mitigated by restricting trigger to concluded 12-week periods older than 84 days.
2. PR-12 secure storage could fail on older Android devices lacking hardware Keystore. Mitigated by using automatic fallback to AES encrypted shared preferences.
3. PR-15 mock location filter could affect simulator testing in development. Mitigated by bypassing check exclusively in debug and profile builds via `kDebugMode`.

## Appendix D. Links and reading list

1. Australian Taxation Office TR 97/11 on logbook car expense methods.
2. Income Tax Assessment Act 1997 Division 28 covering car expenses.
3. Cloudflare Security Audit Specification in `.agents/skills/security-audit/SKILL.md`.
4. Poteto Mode Playbook in `~/.agents/skills/poteto-mode/SKILL.md`.
5. Swarm Verification Methodology in `~/.agents/skills/swarm/SKILL.md`.
