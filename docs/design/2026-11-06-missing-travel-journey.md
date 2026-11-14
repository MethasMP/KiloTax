# Missing-travel journey delivery

## User path

Home or Logbook overview → **Review missing travel** → observed odometer range and unexplained distance → **Add missing trip** → confirm actual date, distance, route and purpose → **Save trip** → return to overview with the remaining gap updated.

The alternative **Leave unresolved for now** dismisses the sheet without changing records. Multiple trips can be entered progressively. A stale form checks that its range is still unrecorded immediately before save. If an export is attempted with unresolved travel, the UI offers **Review** and opens Logbook overview before any file-generation or native sharing call.

## Design decisions

- Actionable missing-travel card appears above the summary on Home and overview. It replaces competing readiness alerts on Home while odometer work is pending.
- The sheet explains observed readings and distance first, then explains uncertainty. It does not infer dates, addresses or personal/business classification from an odometer difference.
- Existing entry controls are reused instead of building a second classification form. Gap entries require the actual date to be explicitly confirmed; business entries require route fields. Remaining spans stay visible after partial entries.
- Business-use hero shows **Needs review** while odometer gaps remain. This does not change underlying tax calculations or certify the period.
- A route flagged by the existing commute check requires the user to choose **Review details** or **Save as personal**. The UI no longer silently overrides the user's selected type in this entry flow. The tax-policy logic itself was not rewritten.
- Shared tokens, Lucide icons, readable controls, a scrollable sheet and keyboard-aware footer are reused.

## State and side-effect map

| Action | Reads | Writes | Outcome |
|---|---|---|---|
| Ingest trip | Observed trip and vehicle | Only that trip; baseline only if previously unknown | No automatic personal trip is manufactured |
| Detect gaps | Non-deleted odometer ranges and recorded vehicle baseline | Nothing | Derived, vehicle-isolated list independent of insertion order |
| Open/leave review | First pending range | Nothing | No mutation on open, close or cancel |
| Save missing trip | Current range, confirmed date/type, entered distance/route | Manual trip, using existing persistence path | Partial gap reduces; latest odometer does not rewind |
| Review legacy inferred entry | Existing inferred trip and linked evidence | Same trip ID with confirmed fields and user-confirmed provenance | No duplicate trip; job/receipt links survive |
| Prepare pack with pending travel | Selected Logbook vehicle and derived gaps | Nothing | Review action offered before native export |

`getLastKnownOdometer` now uses the highest recorded reading rather than the last inserted item, so entering an older missing trip does not rewind the displayed latest reading. Overlap detection during ingestion no longer flags an otherwise valid non-overlapping historical insertion merely because it was added last. An explicit starting reading is retained; only an unknown baseline can be inferred from the first trip.

Known legacy automatic bridge markers are presented for confirmation without bulk-changing or deleting stored records. Explicitly user-entered bridge records are not relabelled as inferred. No database migration is needed: unresolved differences are derived from persisted records; confirmed missing travel uses the existing Trip model.

## Verification

- Main acceptance run: **75 passed** across gap-domain tests, full click-through gap/entry tests, existing automation regression and a 45-case visual matrix (five screens/states × 360/390/430dp × text scale 100/130/200%).
- Additional legacy-marker check distinguishes an old automatically created UI bridge from an explicitly entered bridge.
- Earlier integrity/journey run: 28 passed, including existing odometer integrity and CPK/Logbook routing tests.
- Targeted analyzer after the main run: **No issues found**.
- Broader export/privacy/photo/model run: 68 passed, one pre-existing mismatched assertion in `test/export_enhancements_compliance_test.dart:596`. It expects the CPK disclaimer in a Logbook CSV; the actual Logbook disclaimer differs correctly by method. Export-generator code and that assertion were not modified in this pass.
- Current widget-rendered [review sheet](../../tool/design_audit/logbook_2026_11_06/gap.png).

## Remaining work

This delivers the missing-travel journey. Period closing, period-vs-FY scope, batch receipts and a full export preview remain on the flow-audit roadmap. Existing raw export generators can still be called programmatically; the new guard is on the user-facing tax-pack preparation path. Physical-device testing, injected disk-write failures, restart recovery and independent accountant review have not been performed. This change does not establish tax deductibility or external acceptance.
