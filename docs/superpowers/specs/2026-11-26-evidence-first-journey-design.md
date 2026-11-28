# Evidence-first journey

Status: approved in chat on 26 November 2026. Implementation in progress.
Date: 26 November 2026.

## Intent

Australian tradies should open KiloClaim to finish their vehicle evidence, understand what still needs attention, and prepare a scoped accountant pack. The user requested the three changes discussed in chat: make Home evidence-led, review related records together, and connect Capture, Review, and Accountant pack.

This design covers vehicle evidence. It does not expand the product into general business tax or job management.

## Existing behavior and constraints

`MainScaffoldScreen` owns the selected destination. Cents-per-km exposes Home, Trips, and Tax. Logbook adds Expenses. The centre action opens trip capture or the receipt scanner according to method.

`TaskHomeBody` displays Your driving, a next-action card, Recent trips, tracking, and an estimate. Its review action can open trip-only batch review. This makes travel the recurring task even when receipts need attention.

`EvidenceReviewService` returns typed trip, expense, setup, and odometer issues scoped to a vehicle and financial year. `HomeRecordSummary` excludes unchecked-file-only issues from its pending count. That count cannot establish pack readiness because receipt files have not necessarily been inspected.

`EvidenceReviewScreen` inspects receipt files and opens separate editors for individual issues. `Trip` and `VehicleExpense` already hold links and optional job references. `AppState` owns link and unlink mutations.

`EvidenceAutoMatchEngine` returns match candidates. Expense detail already distinguishes a suggested trip from an accepted link. The matcher excludes pooled car expenses. Review must preserve that distinction and the current allocation policy.

`TaxSummaryScreen` already supports local vehicle and financial-year selection, receipt inspection, and the real accountant-pack flow. Those selections must remain local. The pack includes a PDF, spreadsheet, and available receipt files. Native sharing does not prove delivery.

The checkout contains substantial existing edits. Implementation must use the current files as its baseline and preserve unrelated work.

## Approaches

1. Rename navigation and rewrite Home copy. Smallest diff, but review still requires users to reconcile separate records. This does not meet the requested behavior.
2. Build the journey around existing evidence reports, record links, and pack preparation. Add a contextual review presentation and consistent navigation. This is the proposed approach because it changes the recurring task without replacing working capture and export flows.
3. Make jobs the primary stored entity and require job setup. This adds migration and data-entry work, and excludes legitimate records without a job. It is outside this change.

The agent recommends approach 2. The user has authorized the three outcomes; this written design still requires the Superpowers approval step.

## Home

Home becomes the evidence overview for the active vehicle and financial year. Its first task is a combined review queue, not a trip-only action.

```text
Your evidence                         Vehicle · FY

Finish your records
2 trips need a purpose
1 receipt needs confirmation
[ Review records ]

Accountant pack
Receipt files need checking
[ Open accountant pack ]

Recent records
Tuesday · Smith St · Work travel
Tuesday · Supplier receipt · Details to confirm
[ View records ]

Tracking status
```

The numbers above are examples. Production shows real scoped counts. One record with multiple reasons counts once. Show each reason inside review.

Show this-week trip and expense issues as a digest, with older pending records counted separately. Setup and odometer issues remain visible as all-period tasks. A clear all-pending action prevents an empty week from implying that the financial year is complete.

Receipt-file inspection has explicit checking, failed, checked, and unchecked presentation. Home must not claim checks complete using the filtered HomeRecordSummary count. Reuse the evidence service for inspection and ignore stale asynchronous results after scope changes or disposal. Retry remains available after failure.

When there are no records, show Capture your first record. Offer only capture types already supported by the current method. GPS is optional. Do not require job setup.

While driving, preserve the current drive controls and recording status above review tasks. Do not introduce a review prompt that interrupts recording.

Move the deduction estimate out of the primary Home hierarchy. Keep the existing estimate and calculation basis accessible from Accountant pack. Preserve access to logbook setup and odometer work.

## Contextual Review

Review is a primary destination for both methods. It defaults to All pending and retains a This week filter. In This week, filter issues by each record's own date before grouping. Related older records may appear as context, but their pending actions and counts remain under All pending. Offer an explicit View all pending action for those older issues.

Group existing accepted links so a user can see a trip, its work purpose, optional job reference, and linked receipts together. Unlinked expenses remain independently reviewable. Pooled vehicle costs remain under the vehicle rather than appearing to require trip evidence.

```text
Review                         Vehicle · FY
[ All pending ] [ This week ]

Tuesday · Smith St
Work travel · 18 km
Purpose needs confirmation
[ Edit purpose ]
Related receipt · Details confirmed
[ Open receipt ]

Supplier receipt
Details need confirmation
Possible related trip · Tuesday · 18 km
Suggested from time and supplier context
[ Review match ] [ Open receipt ]

[ Open accountant pack ]
```

Use the saved job reference or destination as context. If neither exists, use the real date and route fields. Never invent a job, business purpose, merchant, location, or receipt.

Review shows the evidence context inline and opens existing editors for changes. Returning from an editor refreshes the queue. Resolving a purpose must not leave the user navigating through unrelated screens to return to review.

Show suggestions only alongside an expense that already has a typed pending issue. Do not create a separate suggestion queue for fully resolved expenses. A suggested match is optional and separate from outstanding evidence issues. It does not change a record, business classification, completion counts, or pack readiness. Review match opens the existing expense detail confirmation flow. The user can accept or leave it unlinked. Linking alone does not confirm business use.

Suggestions must use current, undeleted records from the same vehicle and financial year. Do not suggest personal trips or attach pooled running costs. Treat any unexpected legacy link as context needing inspection rather than evidence of eligibility. Do not change tax calculations or matcher scoring in this task.

Do not duplicate issue cards when several records are grouped. Keep each record's actions available and count each pending record once. Fully resolved context can remain within a pending group but is not another pending item.

## Navigation and capture

Use the same four destinations for both methods.

```text
Home       Review       Capture       Records       Pack
                        action
```

Capture is an action that opens the existing capture chooser. It is not an IndexedStack destination. It must not select another tab or discard the current tab state.

Records contains Trips and, where already supported, Expenses. Retain existing search, filters, detail editing, receipt scanning, and manual entry. Cents-per-km must not gain a mandatory expense workflow. No existing records are deleted or migrated.

Keep selected record filters and list state when switching destinations. Reuse the current request mechanism when a Home or Pack link requests a specific record scope.

Home opens Review for combined issues. An explicit Open accountant pack action from Home or persistent Review passes the source vehicle and financial year into Pack. A direct tap on the Pack destination preserves its last local selection. This distinction prevents a scoped action from opening a different vehicle's pack. Records can still offer trip-only batch actions. Pack links to Review with its own selected vehicle and financial year. Pack pushes a temporary scoped Review route, following its existing navigation pattern. It does not retarget the persistent Review tab. Back and Open accountant pack on that temporary route return to the originating Pack with its unchanged selection. The persistent Review tab always follows the global active vehicle and year. Editing in temporary Review must target the explicit scope without changing the global active vehicle or year, including inside reused editors.

After capture, existing save behavior remains available. Provide a clear route to Review through persistent navigation and the Home queue. Do not force an extra review screen after every save or claim that saving alone completes evidence checks.

Review leads to the existing pack overview and preparation flow. Pack remains exportable with unresolved notes under the existing policy. An empty queue means no outstanding app checks within the stated scope, not ATO approval or a finished tax return.

## Data and ownership

Use `EvidenceReviewReport` as the source of truth for issues. Do not add a second tax-readiness engine.

Add a pure presentation model for review groups only if grouping would otherwise repeat rules across Home and Review. Its inputs are one scoped report and accepted record links. Its output contains trip context, related expenses, and the original typed issue items. It does not mutate records or persist inferred relationships.

Represent receipt inspection as explicit state. Do not conflate an empty inspection map with a successful inspection. Keep asynchronous receipt checking in the screen state or a small shared controller only where real duplication warrants it.

Keep storage and tax models unchanged. Link commands continue through AppState. Capture and editor widgets continue to own their current validation. Navigation receives an explicit vehicle and financial-year scope where required.

Model the Domain changes the choice here: typed review issues and scoped record groups own the presentation, rather than a new collection of screen-specific completion booleans.

## Verification contract

Prove It Works changes the acceptance gate here: navigation tests and rendered screens must demonstrate the new journey. A passing analyzer alone is insufficient.

Required behavior checks cover:

- Mixed trip and receipt issues open combined Review from Home.
- Resolving a trip purpose updates Home and Review without duplicate counts.
- A week with no issues still exposes older and setup issues.
- Unchecked, failed, and missing receipt files never show checks complete.
- Existing links show related context. Suggestions remain uncommitted until confirmed.
- Pooled costs do not require a trip link. A trip without a receipt does not acquire a missing-receipt issue.
- Switching vehicle or financial year does not leak records or late file-inspection results.
- Pack to Review to Pack retains its local scope and global vehicle selection.
- Both methods retain manual entry, live recording, logbook setup where applicable, filters, and pack preview.
- Capture opens a chooser without changing the selected destination.
- An unresolved pack can still follow the existing review and preparation policy.

Render empty, mixed-pending, checking, failed, and resolved states at normal width and narrow width with 200 percent text. Inspect Home, Review, Records, and Pack with the actual theme and navigation. Extend the existing Flutter capture tools where practical.

Run focused regression tests, Flutter analysis, and a whitespace check of the task diff. Report native camera, permission, and share tests separately from mocked platform checks. No external sharing is required to verify this change.

## Workflow and decision trail

Rigor is a scoped UI and behavior change with deterministic domain fixtures and rendered evidence. No database migration is proposed.

- [x] Read the Principles section of the poteto-mode skill.
- [x] Phase A: Frame.
- [x] Phase B: Design the workflow.
- [x] Builder check. Resolved temporary Pack review scope, suggestion visibility, and cross-week grouping.
- [x] Design approval. User instructed implementation to proceed.
- [ ] Phase C: Run the loop.
- [ ] Phase D: Keep the audit trail.
- [ ] Phase E: Verify and hand back.

After design approval, write the implementation plan using Superpowers writing-plans.

The planned units are contextual Review, evidence-led Home, and navigation with scoped Pack handoff. Capture baseline screenshots and focused test outcomes before product changes. Verify each unit before the next. Record decisions and results next to the implementation plan.

Throughput checkpoint: reuse the existing service, link commands, capture chooser, editors, and ZIP flow. Keep record mutation serial. Parallel work is limited to read-only review unless implementation ownership can be separated safely. Avoid a new dependency, storage schema, or tax engine.

Definition of done: a user with a mixed trip and receipt fixture can capture a record, find all scoped issues from Home, resolve them with related context, and reach the existing scoped pack flow. The required tests pass and the rendered screens support the journey at both text sizes.

## Builder decisions and open choices

The agent selected the navigation labels, placement of the capture action, optional suggestion treatment, and use of existing editors. These are proposed implementation choices rather than prior user decisions.

The builder may choose widget extraction and presentation-model filenames. The builder may adjust spacing and responsive layout to match the current theme. The builder may not replace scope handling, infer business use from a match, or add a required job workflow.

No additional product information is required from the user. The pending step is approval of this concrete design under the requested Superpowers workflow.

Builder check completed with three implementation ambiguities. The agent resolved them in this document using the existing Pack push-route pattern, issue-only suggestions, and per-record week filtering. These choices require no additional product information.

Pre-change verification completed on 26 November 2026. The focused evidence service, evidence review flow, Home next action, and export scope selection suite passed all 15 tests. This verifies the existing baseline only. It does not verify the proposed journey.
