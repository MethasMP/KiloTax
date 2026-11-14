# Evidence handoff delivery

The driver can review missing details for one vehicle and financial year, correct existing records, and share a portable evidence pack. Optional product feedback stays on the phone until the driver explicitly previews and shares it.

## Delivered behavior

- Review evidence opens from the Trips Ledger, the home review card, and the tax summary. It lists missing trip details, receipt problems, and unexplained odometer travel. Existing editors update the original record. Deleted records and other vehicles or financial years do not enter the queue.
- An empty business purpose stays empty after saving. The editor does not invent a job, destination, procurement activity, or legal explanation to complete it. Personal travel remains separate.
- Receipts support attachment and replacement. Explicit human confirmation is separate from an OCR match. Editing reviewed fields resets pending confirmation. Saving an unchanged confirmed record preserves the previous confirmation. Replacing an image preserves the expense ID and its links. Saving is disabled during attachment work.
- A single ZIP contains summary.pdf, a recorded-data workpaper, trips.csv, expenses.csv, a receipt index, record-sources.csv, review-issues.csv, README.txt, manifest.json, and available receipt files. The source table links original trip IDs to the corresponding ledger data rows. Missing, changed, unsupported, or unconfirmed evidence stays visible. The pack never invents cloud URLs.
- Private and unclassified routes are masked in both trip ledgers and linked expense references. Raw OCR and free-form expense notes are not exported. Receipt image contents themselves are not redacted. The review dialog explains that files require review before sharing.
- PDF generation uses bundled Inter fonts and does not download fonts during export.
- Product feedback has topic, accountant response, and a bounded note. A local draft can be restored, previewed, and explicitly opened in email or system sharing. No trips, locations, receipt images, or automatic analytics accompany the draft.

## Verification

Run `bash scripts/verify_evidence_handoff.sh` from the repository root.

The final run passed 114 behavior and regression tests, followed by three rendering and navigation tests. The tests cover real temporary receipt files, actual ZIP contents, exact receipt bytes, privacy sentinels, mixed file states, concurrent pack directories, editor confirmation and replacement, draft cancellation, the odometer-gap safeguard, and the native mail-channel payload. These channels are mocked. The tests do not establish native email delivery or receipt readability by a person.

Targeted analysis of the 38 changed Dart files found no issues. Full repository analysis still reports seven existing issues in unrelated scanner, button, old test, and removed migration-screen references. The baseline had eight issues. An unused variable was removed from a touched test.

The debug iOS simulator build failed while linking the existing MLImage framework because an object targets iOS rather than the simulator. Native simulator execution and real driving accuracy remain unverified. This work does not claim accountant acceptance, tax eligibility, or readiness for an App Store release.

## Design and review decisions

Model the Domain led to one typed review report shared by UI and packaging. Laziness Protocol kept the existing editors and removed synthesized purposes rather than adding another editing framework. Sequence Work into Verifiable Units kept corrections paired with behavior tests. Prove It Works required decoding the generated ZIP, inspecting PDF and rendered screens, and exercising the real helper at a mocked platform boundary. Never Block on the Human kept reversible decisions local under the user's explicit autonomous instruction.

An independent gpt-6.1-terra reviewer found linked private-route disclosure, invented cloud URLs, conflated OCR and human confirmation, stale merchant metadata, and outdated UI assertions. The fixes have regression coverage. A later pass corrected fingerprint wording and escaped user text in Markdown tables. The root review additionally reproduced and fixed the empty-purpose fallback.

Three reviewed narration or unsupported certification comment blocks were removed from the workpaper module. No suppression was introduced. No code was published, no external messages were sent, and no mixed pre-existing changes were committed.

## Evidence

- Plan: `docs/superpowers/plans/2026-11-07-evidence-handoff.md`.
- Design: `docs/superpowers/specs/2026-11-07-evidence-handoff-design.md`.
- Final verification: `.audit/evidence-handoff/verification.log`.
- Targeted analysis: `.audit/evidence-handoff/targeted-analyze.log`.
- Full analysis: `.audit/evidence-handoff/final-analyze.log`.
- Native build limitation: `.audit/evidence-handoff/ios-build.log`.
- Independent review: `.audit/evidence-handoff/independent-review.md`.
- Decision trail: `.audit/evidence-handoff/decisions.tsv`.
- Task-only source diff against the saved starting files: `.audit/evidence-handoff/task.patch`.
- Example generated pack: `.audit/evidence-handoff/sample-pack.zip`.
- Rendered review screen: `.audit/evidence-handoff/review-evidence.png`.
- Rendered feedback screen: `.audit/evidence-handoff/product-feedback.png`.

The sample pack uses synthetic test data. It demonstrates the incomplete-record path and includes explicit review issues.

## Follow-up: automatic trips and weekly review

New automatic GPS and native Bluetooth trips start unclassified, without an invented business purpose. Interrupted-trip recovery also requires classification review. Existing historical records are not reclassified.

Review evidence offers This week and All pending within the selected vehicle and financial year. Weeks use local calendar boundaries from Monday through Sunday. The current-year ZIP still includes the full financial-year record set, even when the weekly filter is selected.

On opening or resuming the app, unresolved completed-week trip and receipt checks can generate one in-app reminder per vehicle and calendar week. Sunday includes the ending week. Deduplication persists across app restarts. Tapping the notification in either notification UI opens that vehicle's review. This does not schedule operating-system push notifications while the app is closed.

The follow-up passed 38 focused tests covering detection, week boundaries, persisted reminder deduplication, both notification entry points, record correction, navigation, live tracking, and launch persistence. Evidence is in `.audit/weekly-review/final-tests.log`. Focused analysis is recorded in `.audit/weekly-review/final-analyze.log`.
