# Reports and export — 26 November 2026

## Niche research

Primary product documentation checked for this iteration:

| Source | Relevant pattern | Application in KiloClaim |
| --- | --- | --- |
| [Driversnote: create a report](https://driversnote.helpscoutdocs.com/article/54-creating-a-report) | Scope, summary, preview, PDF/Excel and sharing | Display actual vehicle/FY scope and explain the existing pack contents |
| [MileIQ: create a report](https://support.mileiq.com/hc/en-us/articles/203531259-How-to-create-a-Report) | Classify trips before creating a report | Keep review status/action prominent before handoff |
| [Everlance: generate a data export](https://help.everlance.com/hc/en-us/articles/45326306698779-How-to-Generate-a-Data-Export) | Simple export entry, secondary advanced options, bottom action | A clear primary action with detailed checks and estimate options deferred |

These sources support interaction patterns, not a claim to have inspected every
current competitor screen. The updated flow selects vehicle and financial year
locally without changing the app's primary vehicle or active year.

## New design

- **Hierarchy:** Reports & export → vehicle/FY → dark accountant-pack overview
  → record-check status → included documents → secondary details.
- **Consistency/noise:** warm canvas, obsidian overview and terracotta primary
  action match the current product. One export entry point, no competing amount
  hero. The estimate remains available under a disclosure.
- **Progressive disclosure:** per-record checks are inside Record checklist;
  estimate/comparison and advanced report routes open on request. Empty screens
  explain what a future pack will contain without inventing a balance or files.
- **Thumb zone:** fixed SafeArea primary action above persistent navigation.
  Short “Prepare pack” label and concise helper remain usable at 2× text.

## Truthfulness and real behavior

- Actual pack files are Report.pdf, Details.xlsx and available receipt files,
  confirmed against TaxPackBuilder and the existing archive tests.
- Removed “verified ATO” and “ACCOUNTANT READY” claims. “Checks complete” refers
  only to the existing finished inspection with no outstanding app checks.
- No receipt-file count is inferred from expense count. The overview explicitly
  labels trip/expense counts and says available attachments only.
- Prepare pack is disabled without a selected vehicle and at least one trip or
  expense in the selected year. Empty reports offer View records; no capture CTA.
- Receipt-check failure/retry and pending-file states remain visible.
- Export uses the real ZIP builder, review/preview, then native sharing on iOS
  and Android. Save a copy opens the platform document destination picker.
  Installed apps determine the available share targets. Selecting a target is
  not reported as email delivery. No email composer is preferred automatically.
- Existing session cancellation, draft review items, cleanup and duplicate-
  export protections were retained. Historical exports use exact-year rules;
  missing rules disable preparation instead of substituting the current rate.

## Cross-platform follow-up

Flow: choose year and vehicle → Prepare pack → review missing items / preview
PDF → Share pack (system chooser) or Save a copy (system document picker).
The ZIP contains PDF, Excel and available attachments. Partial records can be
exported with review notes; one record does not imply tax completeness.

Platform references: [share_plus](https://pub.dev/packages/share_plus),
[Android sharing](https://developer.android.com/develop/ui/compose/sharing/send),
[Apple activity views](https://developer.apple.com/design/human-interface-guidelines/activity-views),
[file_picker](https://pub.dev/packages/file_picker).

Regression tests inspect the real ZIP for a non-primary vehicle and historical
year, and exercise native share/save contracts for both platform targets.
Platform calls in these tests are mocked; they do not prove delivery through
every installed mail app.

Latest verification: 35 UI/scope/navigation tests passed before the save-copy
addition; the final share/save and real ZIP review suite passed all 13 tests.
Focused analysis of eight files reports no issues. A concurrent native build
overwrote test shader assets on the first attempt; the clean retry passed.
Native device delivery and document-provider behavior still require device QA;
no Android device or emulator is attached in this environment.
Android debug build was attempted but stopped after an abnormally long run
without a completion result; only existing plugin/Java warnings were emitted.
Do not treat this attempt as a passing Android build. A new iOS simulator app
artifact exists from the concurrent run, but native handoff was not exercised.

## Review loop and evidence

Real Inter/icons/AppTheme.light captures cover empty, ready, needs-review,
check-failure, missing vehicle, narrow 2× text and landscape 2× text, including
the real bottom-navigation component. Capture tests also verify fixed action
position and that a busy preparation cannot be triggered twice.

Visual review caught excessive footer height from the longer button label at
2× text; shortened it and tightened the informational file rows. Existing
readiness tests were adjusted to scroll to the now-secondary estimate while
still proving records and retry are available after inspection failure.

PNG evidence: `test/goldens/export/`. Final test/analysis results below.

- Final UI/readiness/busy/copy/main-navigation suite: **24 tests passed**.
- Existing real ZIP handoff suite: **5 tests passed**, checking attachment
  contents, review-before-send, cancellation cleanup and account-session changes.
  Mail/share dispatch is mocked in tests; no real emails were sent.
- Focused analysis: **No issues found**; diff whitespace check passed.
- Final empty/ready/narrow renders inspected after shortening the footer label
  and tightening the file rows. Hot reload sent to the running Flutter app.
