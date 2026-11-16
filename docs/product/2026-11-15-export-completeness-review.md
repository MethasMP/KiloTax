# Export completeness review

Reviewed 15 November 2026. Design review, not an implementation or ATO certification.

## Capability

Users need a readable accountant handoff and portable supporting evidence. Accountants need reconciled figures, editable detail and direct references to supporting documents. Required records must remain available for their applicable retention period. Two primary documents are a presentation preference, not a completeness rule.

## Constraints and source baseline

- ATO motor-vehicle record guidance identifies journey reasons, dates, kilometres and odometers; logbook period boundaries, period business percentage, vehicle details and subsequent-year odometers. Entity and vehicle eligibility determine which methods apply.
- ATO digital-storage guidance says entered supplier/date/amount/GST data does not replace the actual record; digital copies must be true and clear reproductions.
- Cents-per-kilometre and actual-cost/logbook evidence requirements differ. Do not require fuel receipts merely to substantiate the income-tax cents-per-kilometre calculation. Separate GST and other expense claims may still need evidence.
- Retention must follow the relevant record type and last year of reliance; do not implement a universal deletion five years after capture.

Sources checked:

- https://smallbusiness.taxsuperandyou.gov.au/record-keeping/motor-vehicle-deductions-records
- https://smallbusiness.taxsuperandyou.gov.au/record-keeping/digital-storage-of-paper-records
- https://smallbusiness.taxsuperandyou.gov.au/record-keeping/five-rules-for-record-keeping
- https://www.ato.gov.au/api/public/content/0-f4168ea2-73dc-4bb7-9fa4-9468254b86b1
- https://www.ato.gov.au/api/public/content/0-27f25397-ff76-467b-9b9a-90c639267d0e

ATO API content was available through search excerpts; direct retrieval of the business-method API page returned 403. The ATO education pages above were opened directly. This is a bounded recordkeeping review, not a review of all tax treatments.

## Current implementation findings

| Requirement | Observed implementation | Remaining gap |
| --- | --- | --- |
| Portable receipt evidence | TaxPackBuilder includes locally readable receipt page bytes and reports missing/changed pages | Does not download remote receipts; readability/authenticity not established by nonempty bytes or hashes |
| Owner identity | Workpaper builder receives `Not provided` for client and ABN | Pass appropriate taxpayer identity; ABN only where relevant |
| Annual odometers | AnnualVehicleOdometer model exists | TaxPackBuilder does not accept these records; PDF falls back to first/last trip readings, which do not establish annual boundaries |
| Logbook evidence | LogbookPeriod model exists | Builder does not accept a selected established period or certified percentage; summary computes ratio over supplied financial-year trips |
| Honest readiness | Review service checks classification, purpose, receipts and some setup/gaps | An empty issue list does not establish all statutory requirements |
| Honest PDF | PDF renders recorded figures | Template asserts a continuous 12-week logbook has been maintained without receiving evidence of that fact; D1 labels need entity-specific review |
| Mixed journey transparency | Internal allocation and decision metadata exist | Audit ledger has total distance and MIXED classification but no explicit per-row business/private kilometre columns; proposed workbook must expose them |
| Full supporting documents | Receipt attachments are packaged | No explicit builder contract for purchase, loan/lease, registration or depreciation schedules; identify required external documents and missing evidence |
| Format consolidation | ZIP contains many CSV/JSON/Markdown files; a separate service produces XLSX | No demonstrated consolidated PDF/XLSX output with equivalent evidence coverage |

## Proposed implementation contract

- Report PDF: owner, vehicle, reporting period, selected method/context, recorded versus proposed totals, actual logbook period and annual odometer summaries where relevant, unresolved issues, pack ID/version and receipt references. Never manufacture missing readings or assert eligibility from absence of application issues.
- Workbook: Summary, Trips, Expenses, Needs review; include both journey dates, odometers and their provenance, total/business/private or undecided km, purposes, job references, line allocations and document/page references. Add logbook/annual-odometer detail where relevant. Use one frozen calculation snapshot for all outputs.
- Supporting evidence: include all available relevant receipt pages and other supporting documents in an offline evidence folder for a full handoff. Report missing or unreadable evidence visibly. A summary-only share must clearly say evidence is omitted; it must not be labelled a complete evidence pack.
- Share one ZIP containing two primary documents plus evidence when requested/needed. Do not force an exactly-two-files constraint. Keep machine audit metadata out of the primary reading path without deleting retained history.
- Separate restorable user backup from accountant export; a report workbook is not an application backup.
- Preserve privacy in personal routes while retaining necessary distance/odometer denominators. Mixed business purposes need sufficient context without silently exposing private route details.

States: draft / application checks complete / supporting evidence missing / prepared / handed to external share app. None means ATO accepted, delivery confirmed or accountant approved.

## Non-goals

Tax lodgement, universal entity/vehicle eligibility, automatic GST or depreciation advice, and guaranteed audit acceptance.

## Acceptance and open questions

Before simplifying production output, reconcile every old field and receipt page to the new workbook/evidence location. Test representative-period versus annual-use calculations, reused prior-year logbooks, cross-year periods, annual odometers, mixed journeys, CPK caps, missing/multipage evidence and offline reopening. Reconcile preview/PDF/workbook totals and distinguish recorded facts from suggestions. Have an Australian registered tax agent review representative packs for the supported entity/vehicle scope and conduct an accountant task-based usability check.

Handoff: architecture and tax-treatment review first; do not remove existing evidence exports based solely on the two-document proposal. Existing focused tests verify portions of current behavior, not the proposed format or legal completeness.

## Implemented scope decision — 15 November 2026

The authorized implementation is a recorded vehicle-evidence handoff, not a complete tax-return preparation service. The app does not acquire new obligations to collect finance agreements, calculate depreciation, determine entity eligibility or lodge returns. Existing recorded trips, expenses, receipt allocations, jobs, review history, taxpayer identity and relevant saved annual/logbook context are presented without inventing missing facts.

The main share path now produces one ZIP:

- `Report.pdf`: neutral summary, recorded calculation basis, bounded review digest and scope. It uses bundled fonts and makes no D1/ATO-approval or completed-logbook assertion.
- `Details.xlsx`: Summary, Trips, Expenses, Receipt items, Review, plus saved Logbook records and Trip changes where relevant. Numeric amounts remain numeric; identifiers stay text. Headers freeze, tables filter and receipt paths link to the first included page after extraction. All included page paths are listed.
- `Receipts/`: original readable receipt bytes, stable per-document/page names; absent pages keep their original page number in metadata. No new cloud download dependency.
- `Supporting/record-history.json`: pack metadata, original/exported receipt hashes, extraction fields and allowlisted corrections. Raw OCR, arbitrary currentFields, local paths and private route geometry are not exported. This file is outside the routine reading path.

Root CSVs, duplicate receipt index, Markdown workpaper and separate README/manifest files are replaced by these locations. Backup/restore stays separate. The existing standalone legacy PDF/XLSX service is not the main share path and is unchanged by this slice.

Calculations remain aligned with the current recorded-year app summary. The report explicitly distinguishes that ratio from a representative logbook percentage and annual-odometer denominator. Stored percentages are exported separately rather than automatically changing tax calculations. Missing annual/logbook records or a differing stored percentage appear in Review for logbook exports. Saved expenses do not increase the CPK distance-based estimate; separate expense treatment remains visible for accountant review.

The review dialog explains the two primary files and permits PDF preview before sharing. Sharing or opening an email composer still does not confirm delivery. Application checks do not certify statutory completeness. External tax-agent acceptance remains useful validation of product scope, not a prerequisite added to the user for generating recorded-data exports.

## Verification outcome

- Focused final run: 20 tests passed (pack builder, trip/job/receipt workflow, actual share helper including preview/confirmation/cancel/cleanup, existing workbook builder).
- Analysis of the eight changed implementation/test files: no issues, exit 0.
- `flutter build bundle --debug`: exit 0.
- Independent OpenPyXL and PyPDF readers: sample has exactly two root documents, a two-page PDF, six workbook tabs, eight valid offline receipt targets, frozen/filterable headers, numeric two-decimal display, and no workbook warnings. Both PDF pages were rasterized and visually inspected.
- The representative sample contains 20 synthetic trips, 10 expenses and 8 available receipt files; 195 business km out of 400 recorded km. Missing records remain draft review items.
- Broader exploratory run: 23 passed, 2 UI tests failed before export (onboarding expects vehicle selection immediately after Get started; receipt editor expects an old Replace receipt control). Full-project analysis also found three unused-import warnings in unrelated receipt UI tests. These are not a claim of a green full-project suite. No unrelated product flows were changed to resolve them.

## Accountant-led swarm follow-up — 15 November 2026

Three coverage slices were run: primary ATO/legislation requirements, accountant PDF workflow and code/evidence consistency. All three produced written findings. The code worker reached its usage limit after saving its report; the parent independently checked those findings and implemented/verified the changes. The skill's default Grok model was unavailable, so workers used the available session model, locally, with separate report outputs. This was coverage, not a model race.

### Expert interpretation adopted

The observed business share of saved trips is not automatically the adopted annual business-use estimate. Equally, a stored 12-week percentage need not be applied unchanged in later years. Section 28-90 asks for the held-period annual percentage and a reasonable estimate informed by logbooks, odometers, variations in use and other relevant matters. A difference between percentages with different bases is informational, not automatically an invalid logbook.

The report now makes it possible to inspect recorded movement before considering a claim: reporting window versus actual saved-record dates; business, known-private and undecided km separately; saved annual readings, matched dated trips and signed residual; stored logbook boundaries, readings, percentage and app status. Residuals remain unreconciled amounts rather than being assigned to private use. Invalid/unclosed boundaries give no denominator. Overlapping comparisons are separate and flagged, never added. Matching is by the one recorded trip calendar date; no missing end timestamps are invented.

### Delivered changes

- Primary PDF no longer prints a logbook dollar illustration without an adopted annual estimate. The existing recorded-year scenario remains in the workbook and is explicitly distinguished from a final deduction. Actual-expense method is labelled separately and does not receive logbook-only requirements or an unsupported logbook formula.
- Expense category totals reconcile receipt gross, vault amounts, excluded private/unresolved/invalid allocation portions and the recorded running/direct basis. Split receipts are counted once. Source-file gaps are shown by document amount, not counted once per missing page, and are not called disallowed deductions.
- Foreign/unknown-currency or unusable-amount records remain in their original ledger but outside AUD totals; unsupported cost illustrations are suppressed. No FX or GST-credit calculation was added.
- Review digest groups checks per affected record while preserving detailed page checks in Excel. Human trip/receipt/odometer/logbook references match the ledger/context tables. Pending receipt counts are scoped to the selected vehicle and recorded financial year.
- Legacy private/unclassified trip links cannot leak inherited job/client/project metadata through expenses. Deliberately assigned expense job context remains available.
- Two primary documents and original receipts remain the reading path. No TFN, ceremonial signature, finance/depreciation workflow, lodgement or new eligibility promise was added.

### Verification

31 focused tests passed; scoped analysis reported no issues; debug bundle build exited 0. New regressions cover dated odometer matching, signed differences, invalid/overlapping boundaries, distinct undecided km, different percentage bases, actual-expense output, split/vault reconciliation, multipage evidence grouping, FX/unknown amounts, inherited private-job metadata and current-year inbox scope.

Independent OpenPyXL/PyPDF validation opened the synthetic export without workbook warnings, verified eight live offline receipt targets and checked figures shared by PDF/workbook. The sample has two PDF pages, eight workbook tabs and two root documents: 400 recorded km = 195 business + 185 known private + 20 undecided; saved odometer movement 700 km gives a 300 km unreconciled difference. Stored logbook percentage is 60%, observed recorded-trip ratio 48.75%; neither is adopted automatically. Recorded AUD expenses total 725, of which 540 has all saved files present and 185 has source-file gaps. Four review groups preserve six detailed checks. The previous 353.44 illustration is absent from the primary PDF.

### Primary sources and limits

- https://www.legislation.gov.au/C2004A05138/2026-07-01/2026-07-01/text/original/epub/OEBPS/document_1/document_1.html — ss 28-90, 28-120/125, 28-140, 28-150/155; opened directly. In particular, retention is not simply capture date plus five years.
- https://smallbusiness.taxsuperandyou.gov.au/record-keeping/motor-vehicle-deductions-records — ATO education record requirements; opened directly.
- https://smallbusiness.taxsuperandyou.gov.au/claiming-small-business-tax-deductions/calculating-motor-vehicle-expenses — representative use, annual odometers and distinct methods; opened directly.
- https://smallbusiness.taxsuperandyou.gov.au/record-keeping/digital-storage-of-paper-records — original/true-clear-copy evidence; opened during review.

Some main ATO pages returned 403, so source checking used accessible ATO education pages and directly opened legislation. This review establishes the bounded presentation/record contract, not taxpayer-specific eligibility or ATO approval. Existing data still lacks journey end timestamps and an explicitly adopted annual-use estimate/basis; these remain visible limitations rather than fabricated facts. An exact combustion-engine capacity in cc must come from the recorded vehicle specification, not a guessed conversion of a rounded marketing litre size. Broader unrelated UI failures noted in the earlier verification remain outside this focused follow-up.
