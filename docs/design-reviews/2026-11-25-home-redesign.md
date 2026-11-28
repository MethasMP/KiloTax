# Home redesign — 25 November 2026

## Scope and hierarchy

The real Home route is EvidenceHomeScreen → CpkHomeBody/LogbookHomeBody →
TaskHomeBody. Both tax methods therefore use the same redesigned hierarchy:

1. Brand, notifications, account and vehicle context.
2. Active driving first, when recording. Otherwise one dark daily-task card:
   review pending records, add a first trip, add a vehicle or open the summary.
3. Recent trips, followed by idle automatic-recording setup.
4. A quieter financial summary, logbook details and backup options.

The welcome action is inside the card it explains. Existing review, capture,
tracking, sync retry, logbook and account callbacks are retained. No production
data or tax formulas were changed.

## Navigation and visual consistency

- Warm canvas, obsidian task card and terracotta action match the new login.
- Lower financial summary uses a light surface so it does not compete with the
  daily task. Estimate qualification and basis remain accessible.
- CPK navigation has four balanced slots: Home, Trips, Add trip and Tax.
  Logbook uses Home, Trips, Scan, Expenses and Tax. Navigation indices are
  unchanged; capture is a visually distinct labelled action.
- Removed the empty CPK spacer, floating overlap, gradient and shadow from the
  capture action. Labels scale and wrap rather than being clipped.

The navigation/action distinction is informed by
[Apple HIG: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
and [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars).
This is a custom Flutter implementation, not a native iOS tab bar.

## Review loop

The existing team resumed with separate file ownership for builder, reviewer
and QA. After agent usage limits interrupted their turns, the integrator
completed implementation and verification directly.

Rendered inspection uncovered an existing data-presentation bug: every recent
trip distance was labelled business, including personal and unclassified
trips. Rows now explicitly distinguish Work, Personal and Unclassified, and
remove a per-trip claim amount that used a mileage rate regardless of method.
Unknown route/purpose fields are described honestly instead of inventing a
job-site destination. A regression test covers all three classifications.

The active-recording integration test initially tried to wait for a perpetual
animation to settle; it now advances a bounded duration before checking live
distance and the finish action. Existing safe-export wording was preserved.

## Evidence

Capture harness: `tool/design_audit/home_capture_test.dart`, using AppTheme.light,
real Inter/icon fonts, seeded test-only records and iOS safe-area insets.
Cases: CPK populated, logbook empty, no vehicle, 320px at 2× text.
Historical screenshots are preserved in `home_captures/baseline`; they are not
claimed to represent the exact working-tree state before this iteration.

Final test and analysis results are recorded below after verification.

- Final combined task/batch/navigation/recent/capture suite: **24 tests passed**.
- Main-menu integration for CPK, logbook and actual expenses, including large
  text and vehicle-scope changes: **7 tests passed**.
- After replacing the unsupported route-arrow glyph with an inline icon,
  recent-activity regression and all four captures reran: **8 tests passed**.
  These overlap the previous suite; they are not 39 unique tests.
- Earlier unaffected Home model/capture-flow/telemetry checks also passed.
- Focused analysis of eight changed source/test files: **No issues found**.
- Actual rendered captures were visually inspected; no fake records were
  inserted into the running application. Flutter hot reload was sent to the
  current running app. Native Home navigation could not be inspected through
  computer use because Device Hub returned an accessibility error; the real
  Flutter Home route is covered by the main-menu integration tests instead.
- No production deployment or account changes were performed.
