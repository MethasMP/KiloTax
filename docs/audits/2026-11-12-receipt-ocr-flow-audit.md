# Receipt OCR flow audit — 12 November 2026

Assessment: **the free, local-first foundation exists, but the flow is not yet a complete, trustworthy receipt-processing system.** Bulk confirmation is implemented; field provenance, mixed-receipt gating, backup/recovery and downstream data completeness need repair before broader rollout.

Scope: current working checkout, including uncommitted changes. This is an engineering audit, not a tax/compliance certification. Production code was not changed during this audit. The diagnostic probe under `tool/audit/` records current behavior; a passing probe does not mean the observed behavior is correct.

## 1. Engines actually in use

- Google ML Kit text recognition, configured for Latin text, is the only active OCR engine found in the receipt path.
- `pubspec.yaml:28` declares `google_mlkit_text_recognition`.
- `lib/ui/screens/expenses/receipt_inbox_screen.dart:94–99` recognizes an image, then passes **only `recognized.text`** to the local parser.
- PaddleOCR is **not integrated, not invoked as a fallback, and has not been benchmarked against ML Kit in this checkout**.
- Structured fields come from `ReceiptIntelligenceService` rules/regular expressions, not a trained receipt-understanding model. Improving the OCR engine alone will not repair the downstream problems below.

## 2. Current route, from input to handoff

1. Camera/native scanner (up to 20 pages) or gallery images.
2. Image optimization; normally WebP, default quality 78. Original and optimized image are not modeled as separate retained document versions.
3. Inbox copies the supplied image into `Documents/receipt_inbox/<account+vehicle hash>/` and stores a draft JSON record in SharedPreferences.
4. ML Kit recognizes each pending image while the inbox screen remains active. Leaving pauses work; reopening resumes **unprocessed** drafts. This is not an operating-system background job.
5. Parser proposes merchant, total, GST, ABN, date/time, category, heuristic confidence and evidence strings.
6. Gate checks some missing/conflicting facts and possible duplicates. User can correct a draft in the existing expense editor.
7. User selects rows and confirms together. Each receipt is written separately, with stable IDs and awaited saves. Partial failure/retry is supported.
8. Recorded expenses live in AppState and a separate SharedPreferences JSON list; optional cloud sync uploads images and expense metadata.
9. Active accountant handoff builds a ZIP containing recorded-data PDF, expense/trip CSVs, allocation CSV, receipt images and review issues. Pending inbox drafts are excluded.
10. Local application backup is a different JSON-only export; it does not bundle receipt images or inbox drafts.

## 3. Data contract we should use

These are product requirements for reliable capture and accounting handoff, not a universal statement of legal invoice requirements.

| Data | Current behavior | Required treatment |
|---|---|---|
| Document ID, pages and source | Image hash + account/vehicle creates draft/expense ID; one image = one receipt | Separate document ID from image hash; ordered pages; source and grouping decisions |
| Merchant | Extracted, editable, recorded | Retain observed name and corrected name separately |
| Purchase date/time | Extracted; missing/rejected uses a fallback date plus flag/evidence | Nullable purchase date, separate capture/import time; rejected observation retained |
| Total | Extracted and editable | Exact monetary amount in minor units, selected source evidence, alternatives/conflicts |
| Currency | No structured field; UI labels amounts AUD | Explicit extracted/assumed/confirmed currency; foreign/unknown currency needs review |
| GST | Nullable extraction, editable, stored and synced | Unknown distinct from zero; preserve observed and corrected values; validate by supported scenario |
| Supplier ABN | Extracted, kept in OCR audit metadata | Observed ABN plus validation state; reviewed value if used; not required for every captured draft |
| Receipt/invoice number | Not structured | Extract when present; useful for duplicate detection; absence need not block every receipt |
| Description / line items | No general OCR line-item extraction; manual allocations exist | Summary for simple receipts; item amounts and reconciliation for mixed receipts |
| Work/private/unresolved allocation | Manual model/editor exists | User/context decision with provenance; OCR product words must not establish business use |
| Vehicle/trip/job | Vehicle captured on inbox entry; optional links in expense model | Explicit context, stable ownership and recoverable corrections; suggestions separate from approvals |
| Fuel litres, unit price, discounts | Some words/discounts used as parser signals | Optional factual observations for reconciliation; do not force user entry on every receipt |
| Source image/text and locations | Retained image + flat raw OCR text | Page/block/bounding-box evidence, original/processed image relation, image quality outcome |
| Extraction lineage | Overall score + strings | Engine/parser versions, extraction time, per-field status and calibrated evaluation results |
| Corrections and approval | Current values, a few reason strings, latest review timestamp | Append-only field changes: old/new/source/who/when; revision bound approval and batch ID |
| Persistence/sync/export | Separate lists and operations | Explicit durable states, retry history, backup/restore inclusion and export traceability |

Keep OCR observations, category suggestions and user business-use decisions distinct. Do not ask OCR to decide tax eligibility.

## 4. Findings ordered by importance

### F1 — P1: mixed retail purchases can enter the ready-to-confirm group as wholly vehicle costs

Evidence: `receipt_intelligence_service.dart:108–150`; `receipt_inbox_screen.dart:100–115`.

`hasConflictingEvidence` detects fuel versus maintenance signals, not general groceries/private items. The readiness gate accepts a car category without actual line-item reconciliation. Its explanatory text asks users to inspect mixed items but does not enforce a decision.

Diagnostic: AMPOL receipt text with diesel 80 + chocolate 10, total 90, GST 8.18, valid date produced category `fuel`, confidence `0.98`, and **no batch gate issues**. These are synthetic text inputs, not a measured image OCR error rate. Conversely, the merchant phrase `SERVICE STATION` triggers the maintenance keyword `service`, causing unnecessary conflict review.

Fix: separate document total from vehicle/work subtotal, introduce mixed/unknown-item checks and explicit allocation resolution. Route unsupported cases to review. Validate the routing against a labeled corpus before treating a score threshold as safe.

### F2 — P1: currency is neither extracted nor validated

Evidence: `ReceiptOcrResult` at `receipt_intelligence_service.dart:3–25`; inbox amount labels at `receipt_inbox_screen.dart:319` onward.

Replacing `AUD` with `USD` in the diagnostic still produced total 90, category fuel and high confidence. There is no currency field to preserve the difference; the screen presents AUD. A different OCR engine cannot repair a missing field contract.

Fix: store currency and its source/status; require review for foreign or unknown currency. Any AUD default must remain an identified assumption.

### F3 — P1: editing a draft erases issue gates without a full re-evaluation, and correction history is incomplete

Evidence: `receipt_inbox_screen.dart:179–208`; `expense_detail_screen.dart:707–715`; `receipt_audit_service.dart:24–33`; `vehicle_expense.dart:79–108`.

The inbox editor receives an existing expense, not the original `ReceiptOcrResult`. Its save callback replaces the draft with `processed: true` and an empty issues list. It does not rerun duplicate, mixed-item or extraction checks. The audit service compares edits only when an OCR result is supplied. It has no original OCR date/currency fields and no old/new change events.

Diagnostic: changing total 90 to 110 with the existing audit preserved `ocrAmount: 90` but produced `correctionReasons: []`. The raw observation survives, but there is no explicit recorded event explaining the correction.

Fix: use one domain validation/review service after extraction, editing and before confirmation. Keep issue codes until explicitly resolved; append field-level correction events and bind approval to a document revision.

### F4 — P1: confirmation checks nonempty file bytes, not a decodable image or continuity with the extracted image

Evidence: `receipt_audit_service.dart:23–45,89–95`; `receipt_inbox_screen.dart:270–278`.

The audit service accepts any nonempty file bytes when a merchant and positive amount are supplied. Diagnostic: a `.jpg` containing only `[1,2,3]` received status `confirmed`. A file changed after extraction gets a new fingerprint at confirmation without an explicit conflict with the extraction fingerprint. A matching hash alone cannot establish legibility or factual correctness. The export's README correctly acknowledges this limitation.

Fix: check image decode/page readability separately; retain extraction-image hash and flag unexpected replacement. Human confirmation and image integrity are distinct states.

### F5 — P1: receipt inbox files are outside the existing account-deletion cleanup

Evidence: `receipt_inbox_service.dart:35–37`; `app_state.dart:2684–2694`; `local_storage_service.dart:231–232`; `evidence_vault_service.dart:78–95`; optimizer vault path at `receipt_image_optimization_service.dart:183` onward.

Inbox files are under `Documents/receipt_inbox/`; the account-deletion path clears preferences and calls cleanup for `Documents/evidence_vault/`. No cleanup of the new inbox directory was found. Thus preference indexes can be removed while copied receipt image bytes remain. This is supported by path/control-flow inspection, not a live account-deletion experiment.

Fix: make document storage ownership/cleanup explicit and shared across import, remove, account deletion and device-data removal. Do not delete bytes still referenced by recorded expenses.

### F6 — P1: application backup cannot recover the full receipt workflow

Evidence: `local_backup_service.dart:16–32`; `receipt_inbox_service.dart:43–55`; `tax_pack_share_helper.dart:38–55`.

Backup JSON contains vehicles, trips, recorded expenses and evidence metadata. It contains neither image bytes nor pending inbox drafts. Cloud sync operates on recorded expenses, not inbox drafts. The accountant ZIP intentionally excludes uncommitted drafts and is explicitly not a restorable app backup. Losing a device can therefore lose pending drafts and their images even when the user exported the JSON backup.

Fix: introduce a restorable archive with documents/images/drafts, schema versions and integrity manifest. Show the distinction between saved-on-device, backed-up and synced. Keep drafts out of accounting totals, but show their outstanding count before handoff.

### F7 — P2: storage is structured JSON, not a transactional receipt database

Evidence: `receipt_inbox_service.dart:43–74`; `local_storage_service.dart:106–122`; `app_state.dart:1747–1785`.

Both draft and recorded lists are rewritten as JSON in SharedPreferences. The image copy, draft index, expense write and draft removal are separate operations. Stable IDs and startup reconciliation are useful protections, and tested partial receipt-save retries do not append duplicate rows. However there is no single document-to-ledger transaction, persisted batch/commit journal, optimistic revision check or orphan-file recovery. `loadExpenses` converts a parse failure to an empty list, creating a separate data-recovery risk if later writes overwrite the unreadable payload.

Fix: move receipt/document workflow to a local transactional store with an explicit migration and recovery plan, while preserving historical recorded data. A free local database is sufficient; this does not require a paid AI service.

### F8 — P2: grouping and retry state are incomplete

Evidence: `receipt_inbox_screen.dart:88–90,153–159,324–335`; `receipt_inbox_service.dart:8–23`.

One photo is always one receipt. There is no combine-pages model. An OCR failure becomes `processed: true`, so the Resume reading action does not retry it; manual entry is the available recovery. Processing stops at screen lifecycle boundaries. Capture time is populated in the audit during OCR, not at original retention, so a deferred extraction can misrepresent capture timing.

Fix: explicit document/page grouping, captured/imported/extracted timestamps and states such as queued, reading, failed, needs review, ready and recorded; retry failures without overwriting later manual edits.

### F9 — P2: confidence and machine verification do not represent measured accuracy

Evidence: `receipt_intelligence_service.dart:69–92`; `receipt_audit_service.dart:35–38,71–79`; `vehicle_expense.dart:113–115`.

The score adds constants for populated fields and signal matches; 0.98 is not a demonstrated 98% accuracy probability. Machine output may receive the enum `verified`. The active evidence review correctly still requires `confirmed`, so do not misreport the accountant handoff as accepting machine confidence alone. Overall confidence does not identify which field is uncertain. Only flat recognized text is retained, not engine geometry/version.

Fix: reserve user confirmation for reviewed revisions, use field-specific observations/statuses, and measure false-ready rate on real receipts. Avoid marketing accuracy claims until measured.

### F10 — P2: validation rules are dispersed and do not share a single commit contract

Evidence: `receipt_pre_db_validator.dart:144–170,198–218`; `receipt_inbox_screen.dart:112–115,246–288`; `expense_detail_screen.dart:435–452,659–670`; `app_state.dart:1747–1765`.

The inbox gates on `isValid` and the vault recommendation; warnings are not generally gates. The expense editor consults the current primary vehicle's logbook start date, whereas the inbox uses a captured vehicle ID. Final persistence checks allocations and links but does not centrally recheck all core document facts. GST recommendations and tolerances appear in multiple layers. This audit does not certify their tax correctness.

Fix: one scenario-aware validation result with explicit errors/review requirements; stable vehicle context; central enforcement before commit. Preserve unknown GST as unknown and do not replace observed amounts merely to fit a formula.

### F11 — P2: accountant indexes omit important structured fields that were captured

Evidence: `tax_pack_builder.dart:312–357,359–394,448–461`.

`expenses.csv` includes date, category, total, business percentage, links, image status/hash and review/vault status. It omits structured merchant, receipt-level GST, ABN, currency, invoice number and correction history. Allocation CSV includes per-item GST only for explicit allocations. Image files permit manual recovery of some facts, but this moves work back to the accountant. Raw OCR/audit history is synced in expense metadata but is not exposed as a dedicated audit record in the accountant ZIP.

Fix: add merchant, currency, factual GST and supplier identifiers where available, document ID/revision, provenance and review timestamps, and an audit-events file with stable receipt links. Unknown values must remain blank/explicitly unknown.

### F12 — P2: account/vehicle scope does not yet cover draft discovery and transitions

Evidence: `receipt_inbox_service.dart:33–43`; `receipt_inbox_screen.dart:30–37,45–59`; `scan_receipt_screen.dart:126` onward.

Draft storage is scoped by account and vehicle, which is a useful isolation boundary. The resume action opens only the current primary vehicle's inbox. No guest-to-account draft migration or all-vehicle draft index was found. Changing context can make retained drafts hard to discover. Import work also spans async file operations; account checks are present in reading/editing/confirmation, but not at every import write boundary.

Fix: an account-owned document inbox with explicit vehicle assignment, migration/recovery for guest drafts, counts by vehicle, and identity checks around asynchronous writes.

## 5. What already works and should be preserved

- Local OCR without a paid OCR service; no PaddleOCR hosting requirement.
- Drafts do not become ledger entries merely because OCR finished.
- Missing/rejected dates are flagged in the new scanner route rather than silently considered extracted facts in the UI, although the model still carries a fallback date.
- Stable per-document IDs, awaited expense saves, startup reconciliation and partial-save retry behavior.
- Manual allocation model for work/private/unresolved items; cloud schema includes allocations and audit JSON.
- Sync uploads an available local receipt before its metadata; missing photos/upload failures are reported. Restore checks expected SHA-256 when provided.
- Active evidence review requires user confirmation, and the active ZIP includes actual available bytes, hashes and honest missing/changed-file issues.

## 6. Verification and limits

Executed:

```text
flutter test tool/audit/receipt_flow_probe_test.dart test/receipt_inbox_test.dart test/trip_job_receipt_workflow_test.dart test/receipt_audit_service_test.dart test/receipt_storage_service_test.dart
```

Result: 25 passing executions, including one diagnostic probe. After refining the merchant in the synthetic mixed-receipt example to avoid the separate `service` keyword conflict, reran the diagnostic alone: passed, with the observed unsafe results recorded above.

This proves the reported code-level behaviors and existing tested boundaries. It does **not** establish image OCR accuracy, device durability under process kill, large-batch performance, image legibility, applied cloud migrations/RLS behavior, actual deletion of an account, delivery to an accountant or current tax compliance. No real receipts were uploaded and no external OCR service was invoked.

## 7. Recommended sequence

1. Repair mixed/unknown currency gates, shared post-edit/pre-commit validation, complete correction events, and inbox file deletion/ownership. Keep bulk confirmation only for resolved revisions.
2. Define the document/observation/revision/expense contract and migrate persistence with recovery; implement a complete local backup and draft discovery.
3. Complete accountant exports and their traceability, keeping uncommitted drafts outside totals and showing pending counts.
4. Benchmark actual image-to-final-fields on a representative labeled receipt corpus. Measure exact total/date/currency accuracy, false-ready rate, correction time and batch completion/recovery.
5. Compare pretrained PaddleOCR as an offline development benchmark against the same images if errors remain at the character-recognition layer. Integrate only if the improvement justifies deployment/maintenance. Do not train a custom model or add paid inference as the default next step.
