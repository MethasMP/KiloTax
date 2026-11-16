# Top-three release blockers — 10 November 2026

## Scope

1. Restore clean analyzer and product test suite.
2. Account deletion must report server failure and preserve recoverable local records.
3. Exercise the primary guest journey, including correction, expense entry, persistence and export; attempt physical-device execution.

## Root causes and evidence

- Baseline `flutter analyze`: four unused declarations plus an undeclared direct `xml` test dependency. Removed unused imports/variable; declared the already-resolved xml 7.0.1 as a dev dependency. No lint suppression.
- Baseline suite: 518 passed, 11 failed. Failures referenced superseded UI: Notes vs Notes / Job; Fix now vs Review missing details; the old Home TaxReadinessCard vs the task-first review action; Bluetooth armed claims before background permission; a folded Record checklist; and a navigation test assuming single-line text and a creation button inside the destination bar. Updated tests to exercise current navigation, preserve evidence-review behavior, check permission gating, and verify complete, unclipped destination labels with working taps at 200% text. No product change restores unsupported armed claims.
- Deletion service swallowed RPC errors, attempted non-transactional table deletion that could not remove the auth account, then returned success. AppState ignored the boolean and wiped data in `finally`. Settings provided no failure outcome. `deletion-red.log` records failing cases before implementation. Removed fallback; only RPC acknowledgement enables cleanup. Failure preserves session, preferences and receipt files. A post-acknowledgement logout failure does not misreport the completed server deletion as a failure. Settings reports the returned result.
- A continuous primary-journey test exposed the custom Trip detail back button missing its accessibility name. Added the localized back tooltip; the same journey now uses the back control successfully.
- The first broad regression rerun exposed an outstanding startup restore in the new deletion test fixture. Fixed fixture lifecycle by tracking and awaiting actual restore futures before test actions/disposal; no delays or swallowed failures were added to production.

## Device investigation

- Simulator build reproduced the pre-existing MLImage link error: iOS objects linked into an iOS-simulator build. It is not treated as a successful device test.
- Restored device framework headers with the repository's `ios/patch_mlkit_sim.py --device` and ran `BUILD_FOR_DEVICE=1 flutter build ios --debug --no-pub`: signed device build succeeded.
- `flutter test` cannot launch this wirelessly connected iPad because it disables mDNS publication. Added the standard integration driver and switched to `flutter drive --publish-port`.
- The native journey uses a separate SharedPreferences prefix (`kilotax_release_smoke.`), so resetting its test records does not clear the user's normal records. It reloads native preferences before reconstructing AppState. It does not delete any live account or send exported files externally.

## Limits

The automated journey covers manual guest entry and a simulated app-state restart, not a process kill. Native camera/gallery acquisition, OAuth with real accounts, live Supabase account deletion, and real driving/background continuity require separate device checks. The deletion RPC response is simulated at the HTTP boundary in regression tests; no production account was deleted. Existing backend immutability triggers and receipt-storage cleanup still need live deletion verification before release.

## Final automated results

- Full product suite after fixture correction: 536 passed, zero failed (exit 0).
- Full analyzer: No issues found.
- Physical debug integration could not attach LLDB. Profile fallback was cancelled after the user reported that the iPad is unavailable for testing. No physical journey pass is claimed. The native test runner protects normal preferences and intercepts native telemetry to avoid draining real pending trips or replacing car pairing.

The normal app entry point was rebuilt successfully and installed back onto the paired iPad after cancelling the integration attempts. No launch or further test was performed. See `ios-normal-app-final.log` and `restore-normal-app.log`.
