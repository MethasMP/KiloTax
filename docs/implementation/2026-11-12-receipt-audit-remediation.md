# Receipt audit remediation implementation

User authorization: implement all five recommended audit stages, add free/open-source PaddleOCR, and fix the audit findings. Existing codex/mixed-receipt-sync checkout contains unrelated edits; preserve them and do not commit/publish.

Global constraints: no paid inference; ML Kit remains usable offline; external/self-hosted OCR explicitly configured and never silently uploads images. Do not claim real-world accuracy without a real labeled corpus. Paddle integration must run real pretrained inference, not a mock adapter. Preserve historical expense values and support legacy JSON. Documents, observations, revisions and approval are separate concerns. Unknown currency/date and unresolved mixed/duplicate receipts cannot bulk-confirm. Account deletion and backup include the new stores/files.

Tasks:
1. Models/parser/audit: add currency, invoice/ABN, original date and extraction lineage; robust mixed signals; field correction events and revision-bound confirmation; image decode/integrity checks.
2. OCR providers: common engine/block contract, ML Kit provider, opt-in self-hosted PaddleOCR provider plus runnable pinned service and benchmark tooling; run image inference smoke test where possible.
3. Transactional inbox: SQLite-backed durable documents, revisions and commit intents with legacy preferences migration; compatibility API; explicit retry/group/account ownership. Test with SQLite FFI.
4. Integration: shared validation service, inbox editing/grouping/retry/context, ledger bridge and crash reconciliation, backup/restore with images and account cleanup, complete accountant exports/sync fields.
5. Verification: reproduce and fix audit cases; labeled benchmark harness and honest synthetic/real corpus distinction; scoped independent review and tests.

Preflight shared-interface scan:
| Tasks | Interface | Resolution |
| 1 / 2 | Parser accepts text; engine returns text+blocks+version | Keep parser pure; attach engine metadata when producing audit |
| 1 / 3 | ReceiptDraft wraps VehicleExpense | Add optional model fields with legacy defaults; preserve constructor compatibility |
| 1 / 4 | Audit create accepts date/currency/previous values | Root integrates new optional arguments after model change |
| 2 / 4 | Engine factory and selectable Paddle endpoint | Endpoint opt-in; no network invocation when unset |
| 3 / 4 | Inbox synchronous load + async writes | SQLite opened asynchronously and cache provides synchronous reads; explicit stage/complete commit APIs |
| 4 / 5 | Test coverage | Tests assert desired safety outcomes, diagnostic probe updated after fixes |
| Each | Internal consistency | Existing branch used; no destructive migrations, no paid service, no invented accuracy |

Progress:
- [x] models/parser/audit
- [x] providers/Paddle/benchmark
- [x] transactional inbox
- [x] integration/backup/export
- [x] verification/review

Decision: keep existing dirty checkout and review scoped diffs instead of committing unrelated user changes. Paddle is a free self-hosted optional engine; mobile default remains local ML Kit. No user corpus is available; synthetic images test plumbing, not production accuracy.

Closeout (14 November): see docs/audits/2026-11-14-receipt-remediation-results.md. Code/benchmark infrastructure implemented; no production schema deployment or real-receipt corpus claim. Resumed checkout was main, so created codex/receipt-ocr-remediation without discarding or committing existing changes.
