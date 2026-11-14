# Evidence review and accountant handoff

## Intent

Help a driver resolve missing record details and share an honest, traceable evidence pack. Learn from optional written feedback without requiring interviews or uploading trip data to analytics.

The user explicitly delegates planning and implementation and opts out of questions. Design choices below are agent decisions, not separately approved product requirements.

## Completion predicate

A driver can open a vehicle and financial-year scoped review list, open an existing record editor, resolve the issue, and see it disappear. A tax pack contains readable PDF and CSV records, available receipt images with stable references, and explicit unresolved issues. Missing facts stay missing. A driver can prepare optional feedback with no attached locations, trips, or receipts. Regression tests and targeted analysis pass, and a fresh reviewer inspects the implementation.

## Constraints

- Preserve the existing dirty checkout and unrelated work. Capture a baseline before editing. Do not commit mixed existing changes, publish, or contact anyone.
- Keep current tax calculation semantics. This work checks record completeness, not legal eligibility or audit acceptance.
- Keep unknown, OCR-matched, and human-confirmed evidence distinct. A hash does not prove a transaction.
- Keep private routes out of exported records. Never export internal absolute file paths.
- Allow draft exports with disclosed issues. Preserve the existing odometer-gap safeguard.
- Use existing Flutter patterns, editors, and bundled fonts. Add only a direct declaration of the archive package already in the lockfile.

## Approaches

1. Extend every existing readiness check independently. This is small initially but would repeat inconsistent rules across the ledger, export, and compliance UI.
2. Use one typed evidence review report with adapters for UI and export. Reuse existing record editors. This is the selected approach because the same missing facts appear consistently in the list and handoff.
3. Introduce a new evidence graph, accountant portal, and analytics backend. Reject this because current records already carry the necessary links, and this task needs a finished local workflow.

## Shape

`EvidenceReviewService.evaluate` takes a vehicle, financial year, trip and expense lists, and receipt file states. It returns scoped records and typed issues. File inspection is asynchronous and separate from the deterministic evaluator. The review screen uses the report and existing record editors. No stored completeness score is added.

The pack builder accepts a scoped report and generated PDF and trip ledger. It packages receipt copies, an expense index, record provenance, and a review summary in a ZIP. Receipt identifiers map to files without disclosing device paths. Read failures become explicit missing-evidence entries.

Feedback is a local draft with a bounded note and fixed choices. The user previews the text and explicitly opens their mail composer or share sheet. No automatic telemetry or message sending is added.

## Verification

Use real temporary receipt files, including absent, empty, changed, and valid image files. Assert scope isolation, issue resolution, honest missing fields, private route masking, ZIP contents and file references, offline PDF creation, feedback persistence, and user-triggered sharing. Widget tests exercise navigation and editing. Runtime rendering checks include narrow screens and enlarged text.

## Risks

Existing readiness checks and exports contain unrelated tax assumptions. Avoid certifying them through new copy. Background tracking accuracy still needs device driving trials. Accountant acceptance and tax correctness require external review and are not completion claims.

## Design synthesis

Read both independent proposals at `/private/tmp/drivelog-evidence-design-a.md` and `/private/tmp/drivelog-evidence-design-b.md`. The shared typed review is the base. Graft the second proposal's immutable export snapshot, exact exported receipt hashes, unique temporary directory, and bundled font handling. The independent judgment at `/private/tmp/drivelog-evidence-design-judgment.md` supports the combination with those conditions. Reject duplicated readiness rules and a new generic report framework.

CPK records can include receipts for record keeping. These are not added again to the distance-based calculation. Vault-only expenses stay in the index with their excluded status and do not create completion tasks. Mixed stored trip methods are disclosed, not silently migrated. Feedback retains only one explicit local draft. No-record accounts never display complete evidence.
