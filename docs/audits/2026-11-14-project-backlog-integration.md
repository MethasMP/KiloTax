# Application backlog integration — 14 November 2026

The user authorized resolving the pending mixed application changes and integrating locally into main. This expands the earlier receipt-only boundary. The earlier receipt integration gate records the failing pre-repair state; it is not the final application result.

## Changes and scope

- Integrated receipt inbox, review, storage, backup/recovery, export and optional local PaddleOCR with the pending trip, vehicle, onboarding and UI source they share.
- Updated stale UI tests to exercise current visible actions, explicit classifications and persisted results. CPK review remains an explicit user decision. The full guest journey uses Logbook, whose navigation includes expenses; CPK has its own scoped coverage.
- Added stable merchant/amount input keys after the supplier/invoice fields changed form order. Fixed the receipt currency dropdown to fit the available width.
- Closed workflow-save races with backup restore and account transitions. Delayed-storage tests prove exclusion and persistence order.
- The exact-commit rerun exposed a late cloud-restore lifecycle race. Added captured-session/request-lifetime guards and deterministic dispose/sign-out regressions; the focused follow-up passed 21 tests.
- Kept imported skill caches, generated diagnostic captures, personal documents and OCR runtime credentials/dependencies outside the application commit. Included the single EDE Dart template that the committed risk-gate test imports.

## Verification

The initial isolated application run passed 623 tests. The exact-commit rerun exposed one late restore lifecycle failure, repaired in `042ce38`. Final full-suite verification of that committed application code passed **627 tests** (`/tmp/drivelog-final-full.log`), with no failures. Whole-project `flutter analyze` reported no issues (`/tmp/drivelog-final-analyze.log`). Seven standalone Python service tests passed. The iOS Simulator debug build succeeded; post-merge verification is recorded below. Native ML Kit and real HTTP PaddleOCR were previously checked against one synthetic receipt; this does not establish accuracy on real receipt populations.

## Operation

PaddleOCR is an optional free local test service on this Mac. Its health endpoint reported the model loaded. The iPhone Simulator can use `http://localhost:8765/ocr`; a physical phone needs a reachable secured endpoint, which is outside this local integration. Connection credentials are in the ignored `tool/paddle_ocr/.runtime/connection.txt` in the verified worktree. The local environment and model cache reuse the existing installation through ignored local links. The service was restarted from this worktree and real inference returned 12 blocks; the original token was preserved. No production schema migration, public service, remote push or cloud deployment is performed by a local merge.

The shared source checkout changed branches during verification. Application files were copied to a managed isolated worktree, preserving the original dirty files. The final verified application checkout is `/Users/methas/.codex/worktrees/drivelog-project-integration/DriveLog`.

## Local landing result

Application source was committed as `9740bbd`, followed by lifecycle correction `042ce38` and verification documentation `21daeed`. Main was fast-forwarded locally to the same tested tree. Post-merge lifecycle/workflow smoke tests passed 21/21 (`/tmp/drivelog-main-smoke.log`) and the final main iOS Simulator debug build succeeded (`/tmp/drivelog-main-ios-build.log`). The managed PaddleOCR service remains running with its model loaded. No remote push or production migration was performed. The original shared checkout and its pending local files remain intact; use the isolated worktree for the verified main checkout.
