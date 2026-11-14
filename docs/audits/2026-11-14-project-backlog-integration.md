# Application backlog integration — 14 November 2026

The user authorized resolving the pending mixed application changes and integrating locally into main. This expands the earlier receipt-only boundary. The earlier receipt integration gate records the failing pre-repair state; it is not the final application result.

## Changes and scope

- Integrated receipt inbox, review, storage, backup/recovery, export and optional local PaddleOCR with the pending trip, vehicle, onboarding and UI source they share.
- Updated stale UI tests to exercise current visible actions, explicit classifications and persisted results. CPK review remains an explicit user decision. The full guest journey uses Logbook, whose navigation includes expenses; CPK has its own scoped coverage.
- Added stable merchant/amount input keys after the supplier/invoice fields changed form order. Fixed the receipt currency dropdown to fit the available width.
- Closed workflow-save races with backup restore and account transitions. Delayed-storage tests prove exclusion and persistence order.
- Kept imported skill caches, generated diagnostic captures, personal documents and OCR runtime credentials/dependencies outside the application commit. Included the single EDE Dart template that the committed risk-gate test imports.

## Verification

The isolated application run passed all 623 tests. Whole-project `flutter analyze` reported no issues. Seven standalone Python service tests passed. A strengthened persistence regression and final exact-tree checks follow before landing. Native ML Kit and real HTTP PaddleOCR were previously checked against one synthetic receipt; this does not establish accuracy on real receipt populations.

## Operation

PaddleOCR is an optional free local test service on this Mac. Its health endpoint reported the model loaded. The iPhone Simulator can use `http://localhost:8765/ocr`; a physical phone needs a reachable secured endpoint, which is outside this local integration. Connection credentials remain in the ignored runtime file in the original checkout. No production schema migration, public service, remote push or cloud deployment is performed by a local merge.

The shared source checkout changed branches during verification. Application files were copied to a managed isolated worktree, preserving the original dirty files. The final verified application checkout is `/Users/methas/.codex/worktrees/drivelog-project-integration/DriveLog`.
