# Receipt integration gate — 14 November 2026

Historical pre-repair gate. The user subsequently authorized resolving the whole application backlog. See `2026-11-14-project-backlog-integration.md` for the final integration result.

## Service

The Mac-only PaddleOCR service is running on 127.0.0.1:8765. A managed startup,
status, real inference check, credential-file and safe shutdown interface was
added. Model warm-up succeeded against the synthetic receipt (12 text blocks).
No public endpoint, login daemon, paid host or production database change was
created. Runtime token/config/logs are private and Git-ignored.

## Main integration decision

**Do not merge the entire working tree into main yet.**

At inspection, main and codex/receipt-ocr-remediation both pointed to e885609;
there was no OCR feature commit to merge. The working tree held 159 modified
tracked files plus many new files. Receipt changes share AppState, data models
and exports with other uncommitted work (tracking, UI, vehicle assets, onboarding
and other features). A branch switch alone would not land these changes.

A full current-project run (`flutter test --concurrency=4`) produced 599 passed
and 20 failed executions. This is broader than the earlier receipt-focused
suites; those results must not be presented as a green whole-project release.

Six reported failures involved receipt integration fixtures affected by the new
contract/storage: tax pack share (2), audit test-double signature (1 file failed
compilation), manual category scroll interaction, unknown currency confidence,
and account cleanup's native-storage test environment. These were corrected and
are rerun as a scoped suite. Production safety checks were not relaxed.

The remaining reported failures concern trips/Bulky Tools, onboarding/release
journey, home telemetry/dashboard, vehicle rendering and CPK batch review. No claim
is made that these failures predate this work; the dirty shared tree does not
supply a clean baseline proving that. They must be triaged before a whole-project
merge. Do not silently stage or commit all 159 files as an OCR change.

## Commit boundary

Commit the standalone Python PaddleOCR service and its operating tests separately
on codex/receipt-ocr-remediation. Leave the mobile app changes and other shared
edits intact and unstaged while their dependency boundary is prepared. Do not
push or merge into main with a failing integration gate. In particular, do not
use `git add .`, a hard reset, or a stash that hides other ongoing work.

## Next integration steps

1. Resolve ownership/scope of the shared uncommitted application work and package
   receipt integration with its required model/storage dependencies.
2. Fix or explicitly isolate all full-project failures with before/after evidence.
3. Test the exact committed integration tree, then merge locally to main and test
   the merged result. Push/deploy is a separate action.
4. Apply the additive receipt schema migration to the chosen database only as part
   of that deployment; a local code merge does not apply database migrations.

For local operation use `tool/paddle_ocr/LOCAL_SERVICE.md`. Connection details are
in the private ignored runtime file, not in this report.


## Verified closeout

- Commit `04cbe62` on `codex/receipt-ocr-remediation` contains only 15 standalone
  Python service/fixture/operating-document files. No mobile application or
  unrelated working-tree changes were swept into it.
- Seven Python tests passed. Managed service start is idempotent, status confirms
  `modelLoaded: true`, and real inference returned 12 blocks from the synthetic
  fixture. Service remains running privately on this Mac.
- The five receipt-related test files affected by the new storage/audit contract
  now pass all 18 executions together. SQLite widget tests use the FFI factory
  without an isolate and keep persistent documents separate from temporary ZIPs;
  production data-safety rules were not weakened.
- Main remains at e885609. No push or main merge was performed. The full-project
  run preceding these scoped repairs reported 20 failures; six reported receipt
  integration failures were repaired, and the other reported areas remain an
  integration gate rather than being assumed green.
