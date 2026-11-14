# Complete application backlog and main integration — 14 November

Authorization: user explicitly requested fixing the pending mixed application work, not merely stopping at OCR. Resolve whole-project tests and integrate application source into main after exact-tree verification. No production deployment or remote push requested.

Application commit scope: lib, app platform configuration, referenced assets/fonts, package manifests, tests/integration drivers, application scripts/schema and associated product/design/audit documentation. Preserve local skill imports, editor/agent runtime state, generated diagnostic captures and personal document exports outside application commits. Never add runtime OCR secrets/caches/venv.

Tasks:
- Home telemetry/review workflows: assigned home_backlog; 19 scoped tests passed, no product changes required.
- Trip/vehicle/CPK interactions: assigned trip_vehicle_backlog; 10 scoped tests passed, no product changes required.
- Onboarding and full guest-to-export/restart journey: root; aligning current actions, preserving real user decisions and stored identity assertions.
- Full tests/static analysis/iOS build; test exact committed application tree in an isolated managed worktree if required.
- Commit cohesive application changes and merge locally to main; test merged result. Do not push or deploy cloud schema automatically.

Progress and final evidence will be recorded in project integration report.
