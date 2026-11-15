# Trip → Job → Receipt → Accountant pack

Status: core workflow implemented and cloud schema deployed on 12 November 2026. OCR changes are deferred. Physical-device background tracking and tax-professional acceptance remain release validation, not claims established by application tests.
Owner audience: Australian sole trader tradies and their accountants. Reviewed 11 November 2026.
Input: founder document https://docs.google.com/document/d/1P7ncruby5STCOTGOkJ3iknPWgQ5f7ylXRcRD7HHtBB8/edit

## Outcome and boundaries
Capture driving automatically, associate relevant jobs and receipts with explainable suggestions, resolve missing facts once, and export a reproducible accountant evidence pack. Reduce missing evidence and correction work; do not promise fewer audits, guaranteed deductions, or ATO approval. Start with sole traders; employee, partnership, company and trust tax treatment must remain distinct. A ute is not automatically a car for tax-method eligibility: collect vehicle carrying/passenger capacity and ownership before offering methods. No automatic tax lodgement or accountant messaging.

## Existing implementation and gaps
- AutonomousTripDetector already creates unclassified trips. Physical-device reliability, background termination, denied permissions and battery behavior still need field validation.
- JobSiteGeofenceEngine enriches free-text jobReference and purpose; that is inferred context, not confirmation. Stable job identity, geofence suggestion metadata, editable job records and explicit trip review are now implemented.
- TripConfidenceClassifier previously promoted merchant/site strings into preselected work batches and inferred tools/callouts. This change routes these trips to individual review and removes invented tool facts. The trip review records business distance, allocation basis, confirmation timestamp and decision history. These facts do not prove a commute exception; high-confidence batching stays disabled until evidence-backed authorization exists.
- Receipt storage, allocation, synchronization and accountant generators exist. They need end-to-end validation together before claiming this capability is complete.
- AccountantHandoffService currently contains D1-specific labels, public receipt URL construction, default GST inference and categorical materials/100% claims. Review these before adopting it as the sole-trader handoff. OCR verification is not legal deductibility verification.

## User journey
1. Set up vehicle and taxpayer context; explain location permission with a visible tracking health status. Save locally before synchronization.
2. Capture → detected → needs review. Show route/time/distance and capture source; signal GPS gaps. Allow manual recovery without inventing missing telemetry or measured odometers.
3. Suggest a job from saved site/time context, displaying why. One tap confirms a specific job and purpose; reject or change without changing other records. A merchant visit is a suggestion only.
4. Review with Business / Personal / Mixed / Not sure. Preserve not-sure items and exclude them from claim-ready totals. Confirm business purpose, not just the destination. Ask exception questions only when relevant.
5. Scan receipt → extract → suggest trip/job → confirm allocation. Keep source image and extracted text separate from corrections. Linking does not make an expense deductible. Fuel may relate to a period rather than one trip; do not force artificial links.
6. Weekly inbox groups missing purpose, uncertain allocation, duplicates, odometer gaps and missing documents. Open the exact unresolved item; preserve edits offline; provide undo.
7. Preview a dated accountant pack: method and taxpayer context, recorded vs proposed claim amounts, trips, jobs, receipt index, allocation basis, unresolved items and change history. Export a draft even with gaps, visibly labelled. Share only by an explicit user action.

## Classification policy (product policy informed by ATO, not an ATO algorithm)
Business context and claim eligibility are separate. GPS, work hours, client labels, repeated routes and merchant names cannot alone establish deductibility. Working on weekends is possible; weekdays are not proof of business use.

| Situation | Default handling | Facts needed |
| --- | --- | --- |
| Ordinary home ↔ regular workplace | Flag commute; do not auto-claim | Taxpayer context and whether a supported exception applies |
| Job ↔ job or business supply collection | Suggest business; ask confirmation | Actual business purpose and job, personal detours |
| Home-based business ↔ customer | Review under business rules | Whether home is genuinely a business base and reason for travel |
| Employee bulky equipment exception | No prefilled yes answers | Essential bulky equipment, necessity of transport and lack of secure storage; accountant review when uncertain |
| Work route with private detour | Mixed review | Business/private legs, distance source and user-confirmed allocation |
| Unknown purpose or broken tracking | Needs review | User explanation or supporting record; never silently zero the private portion |
| Personal | Exclude claim | Keep distance needed for usage denominator; hide private route details from shared views by default |

Employee commute exceptions must be verified against current ATO guidance before building a question-based eligibility rule. Sole-trader rules cannot be inferred from employee guidance. Reimbursements, ownership, method eligibility and GST require separate treatment; an allowance is not the same as reimbursement.

## Data and lifecycle contract
- Trip: stable id, vehicle, start/end instants and timezone, captured distance, distance source, odometer readings/source, review state. Keep classification separate from a tax-treatment decision.
- Job: stable id, customer/site, optional project code; archive without breaking historical links. Many trips and receipts may relate to a job.
- Decision: actor, timestamp, rule/source version, confirmed facts, business/private allocation, explanation, prior decision. Suggested, confirmed and accountant-adjusted values remain distinguishable.
- Mixed journey: retain one original captured trip and its original odometers. Store confirmed business kilometres and the allocation basis separately; private kilometres are the remainder. This avoids manufacturing intermediate odometer readings or counting parent and legs twice. Keep decision history when reclassifying. Route addresses are masked in shared mixed-trip records.
- Receipt: immutable original, extracted fields, correction history, duplicate fingerprint, monetary line allocations, allocation basis and confirmed business proportion. Cross-job allocations cannot exceed the receipt total. Separate vehicle running costs, direct expenses and capital items; never infer GST solely by dividing by 11.
- All links must belong to the same account. Cross-vehicle links require deliberate correction. Local transactions and sync retries must be idempotent; deletes/unlinks must not leave orphan evidence.
- Existing historical classifications stay unchanged by this first safeguard. Adding review states requires a versioned migration; do not turn old records into user-confirmed evidence.
- Export takes a frozen snapshot and identifies its rules, period, account and vehicle. A later correction creates a new pack, not a silent replacement. Use portable attachments or authorized receipt access, never fabricate public URLs. Record export success/failure without logging private routes or receipt contents.

## ATO evidence baseline and sources
Checked through ATO published search content and ATO education pages on 11 November 2026. Main ato.gov.au pages returned 403 to full-page retrieval; this is not a complete legal review. Exact exceptions and current-year rates remain release gates.

- [ATO motor vehicle deductions records](https://smallbusiness.taxsuperandyou.gov.au/record-keeping/motor-vehicle-deductions-records): retain journey reasons, dates, distances, odometer evidence and period information; company/trust actual-cost treatment differs. Design implication: a map trace alone is insufficient.
- [ATO logbook education](https://smallbusiness.taxsuperandyou.gov.au/ride-sourcing-income-expenses-and-gst/the-logbook-method): representative continuous 12-week period, business proportion and expense evidence. This page addresses ride-sourcing; validate final tradie-specific guidance before release.
- [ATO trips you can and cannot claim](https://www.ato.gov.au/individuals-and-families/income-deductions-offsets-and-records/deductions-you-can-claim/cars-transport-and-travel/trips-you-can-and-can-t-claim): employee travel and commute/exception guidance; do not apply wholesale to business owners.
- [ATO business motor vehicle expenses](https://www.ato.gov.au/businesses-and-organisations/income-deductions-and-concessions/income-and-deductions-for-business/deductions/deductions-for-motor-vehicle-expenses): verify entity, vehicle and method eligibility before calculation.

## Delivery order and acceptance
1. **Completed first safeguard:** heuristic-only trips cannot enter a preselected work batch; tools and emergency callouts are not invented. Regression tests cover merchants, sites, home in both directions, weekends, nights and personal visits.
2. **Implemented:** stable job identity plus persisted suggestion/confirmation metadata, then business/personal/not-sure review with clear purposes. Verify save/restart/offline/sync and account isolation before widening automation.
3. **Implemented mixed travel:** allocation metadata, migrations and review UI; verify distance conservation and no duplicate claims. Unknown allocation remains unresolved.
4. **Connected existing receipt editor:** confirmed monetary allocations and reversible job/trip matching; verify duplicate scans and retries, no automatic 100% materials claim or assumed GST.
5. **Connected pack:** one canonical calculation feeds preview/PDF/workbook; year/vehicle/method filters agree, private details stay hidden everywhere including linked receipts, all documents open offline or through authorized access. Unresolved evidence appears consistently.
6. **Pilot:** measure missed/false trips on real iOS/Android devices against a contemporaneous drive diary. Run end-of-day review and pack handoff with tradies and an accountant; record completion time and rework. Rendering tests cannot establish background reliability or accountant usability.

Target hypotheses, not current claims: routine confirmed-job review under 30 seconds per day; less than 5% of submitted items returned for missing context. Set tracking recall targets after a measured pilot. No audit-frequency metric is promised.

## Open decisions and handoff
Tax professional validation of exception questions, GST/reimbursement treatment, retention policy and capital expenses remains required before advertising tax eligibility automation. The next engineering slice can proceed with evidence capture/review metadata independently. Do not enable automatic business claiming until confirmed facts and an explicit reusable user rule exist; expire such rules when job/site/vehicle context changes and always allow correction.

## Implementation verification — 12 November 2026

Entry points: Trips toolbar workflow icon and Tax Summary → Trip → Job → Receipt → Pack.

- Job editor supports name/client/reference, archive/restore and an optional explicit current-location capture for future geofence suggestions. Jobs without coordinates do not participate in geofencing.
- Trip editor supports Business / Personal / Mixed / Not sure; rejects empty business reasons and invalid distances; persists user decision revisions before returning. Reviewed trips opened through legacy quick actions redirect to this editor.
- Receipt editor now waits for local persistence before closing. A link editor offers same-vehicle trips ordered by date proximity and optional job assignment. Existing broken legacy links can be retained while correcting receipt details; they are flagged in the pack instead of silently removed. Expense-owned links reconstruct the trip index after restart/restore.
- ZIP adds job-connections.csv and trip-review-history.csv to the existing PDF, ledgers, receipt index and actual receipt files. Review screen permits explicitly labelled draft sharing when gaps remain; older direct-share entry points retain their gap safeguard.
- Cloud schema includes jobs with owner-only RLS, optional local identity, trip job/review fields and expense job fields. Unclassified trips no longer become personal on sync. Application and database calculations agree on mixed business distance.
- Automated coverage includes full capture → mixed review → receipt link → local reload → real ZIP export, JSON/cloud round trips, invalid allocations, cross-vehicle rejection, archived job preservation, unlinking, existing receipt correction and sharing. A debug Flutter asset bundle was built successfully. These checks do not prove device GPS recall or accountant acceptance.

Final verification evidence:
- 72 focused workflow/tracking/receipt/link/export/sync tests passed in the final run.
- Two visual checks passed at 100% and 200% text scaling; captures are under `tool/design_audit/workflow/`.
- `flutter analyze`: no issues. `flutter build bundle --debug`: exit 0.
- Hosted database verification: mixed 20/15 → 15 business km, personal/undecided → 0; jobs RLS enabled with four owner policies; anonymous jobs read denied; accountant view remains security-invoker. Both workflow migrations were applied and column presence verified.
- Security advisor findings concern existing keepalive/auth/share-token functions, pg_net placement and password protection, not the new jobs table or business-distance function. Follow up separately using the [Supabase security advisor guidance](https://supabase.com/docs/guides/database/database-linter).
- An exploratory whole-repository test run did not complete green. Two onboarding tests outside this flow still refer to older setup labels (`What do you drive?` / `Save vehicle and continue`). This work does not claim a passing full-repository suite or a production mobile release.

## Current accountant handoff format — 15 November 2026

This section supersedes the older CSV/Markdown package layout described above. The main share path creates one ZIP with two primary documents:

- `Report.pdf`: recorded-data overview, reporting window and actual saved-record date ranges; separate business/private/undecided distance; dated odometer reconciliation and saved logbook context; expense categories, gross-to-recorded-basis reconciliation, source-file exposure and grouped review checks.
- `Details.xlsx`: Summary, Trips, Expenses, Receipt items, Review and Expense summary, with Logbook records, Odometer comparison and Trip changes where applicable. These are frozen exported values, not a live tax calculator. Amounts remain numeric and identifiers remain text. Headers freeze, tables filter and receipt hyperlinks resolve to included files after extracting the ZIP. Preserve the extracted workbook/Receipts folder relationship.
- `Receipts/`: original locally available receipt bytes, including all saved pages. Missing, changed and unrecognized files remain visible review issues; a source-file gap does not by itself establish that an expense is disallowed.
- `Supporting/record-history.json`: pack metadata, receipt hashes and allowlisted extraction/correction history outside the normal reading path. Raw OCR and local paths are not shared. The accountant pack remains distinct from a restorable application backup.

No logbook deduction amount is printed in the primary PDF without an adopted annual business-use estimate, which the current model does not capture. The workbook's recorded-trip-ratio scenario is labelled separately. A stored logbook percentage and a recorded-year ratio have different bases; a difference alone is not an error and neither is silently adopted. Odometer differences are signed and unclassified; they are never converted to private kilometres. Invalid/overlapping/unclosed boundaries are flagged without inventing a denominator. Trip matching uses the one stored calendar date; journey end timestamps remain unavailable. Prior-year original logbook detail is not implied by exporting its saved period metadata.

Actual-expense method is labelled explicitly and does not inherit logbook-only requirements. Foreign/unknown-currency or unusable-amount records stay visible in their original ledger but outside AUD totals; unsupported cost illustrations are suppressed. No automatic FX, GST-credit, depreciation, finance-document collection, eligibility or lodgement workflow is added. Private/unclassified trips cannot disclose inherited job metadata through an expense link. Pending receipt counts use the selected vehicle and recorded financial year.

Source basis: [ITAA 1997 s28-90 and record provisions](https://www.legislation.gov.au/C2004A05138/2026-07-01/2026-07-01/text/original/epub/OEBPS/document_1/document_1.html), [ATO motor vehicle records](https://smallbusiness.taxsuperandyou.gov.au/record-keeping/motor-vehicle-deductions-records), and [ATO digital source records](https://smallbusiness.taxsuperandyou.gov.au/record-keeping/digital-storage-of-paper-records). Recordkeeping evidence and a usable handoff do not constitute an ATO approval or a final taxpayer-specific claim.

Integration verification: the isolated export topic was based on local main, with only the export implementation, contract and associated tests copied from the shared checkout. Full `flutter test` passed 642 tests; whole-project `flutter analyze` reported no issues. Shared UI/sync work in the original checkout was preserved outside this commit. This is a local integration, not a remote push or deployment.
