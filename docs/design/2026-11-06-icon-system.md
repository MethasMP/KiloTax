# Icon system update

Lucide remains the existing dependency; no new package or version upgrade was required. `AppIcons` provides shared semantic mappings and `AppIconSize` defines 16/20/24/32dp roles. Navigation uses a consistent outline glyph with a tinted selection state and retains its selected semantics and callbacks.

Migrated explicit Material icon references on Logbook, shared navigation, quick capture, Trips ledger, Home header/recent activity, Expenses and Tax surfaces. Existing unrelated source changes remain intact. This is a UI change, with no changes to tax or evidence calculations.

Validation: the visual matrix, adaptive navigation and hero regression command passed **47 tests**. The matrix includes four screens at 360/390/430 logical pixels and text scale 100/130/200%, plus keyboard positioning for entry/setup. The Home screenshot now includes the shared Logbook navigation. Targeted analyzer: **No issues found**.

The broader initial test run exposed two existing mismatches: `home_recent_activity_test.dart` still passes the removed `onSimulateDrive` parameter, and the onboarding render test expects the old `Just drive` copy. That compile failure also produced a compiler-exit report for the visual harness; rerunning the harness separately passed. These unrelated tests were not changed to hide the failures.

Current widget-rendered preview: [Home and navigation](../../tool/design_audit/logbook_2026_11_06/home.png). Physical-device and screen-reader testing was not performed.
