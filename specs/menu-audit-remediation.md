# Menu audit remediation — EDE Tier 2

Objective: Resolve F01–F18 in docs/design/04-menu-audit-2026-11-08.md through presentation, navigation and local UI changes.

## Invariants
- Existing tax calculations, stored records, auth, export generation and scanner services are unchanged.
- Evidence status and review counts derive from the canonical review report for the same vehicle/FY. A score, amount or receipt path alone cannot assert readiness.
- View recorded trips navigates to recorded trips, not a creation form. Vehicle changes preserve semantic destinations or fall back to Home.
- Pending records are called draft wherever shared. File descriptions reflect the tax method.
- Unknown classification/payment data is not presented as confirmed personal/business data.
- Primary controls expose button/disabled/loading semantics, labels follow onPrimary, normal text contrast >=4.5.
- Audit capture matrix at 390/100% and 320/200% has zero render overflow and relevant framework warnings, without suppressing text scaling.
- Capture entry points explain actual scanner behavior. No cosmetic flash toggle.
- Existing working changes are preserved. No commits or publishing.

## Evidence contracts
- Convert the five failing tool/design_audit/menu_contract_audit_test.dart counterexamples to passing product regression tests.
- Re-run the 58-case capture harness, inspect images and require JSON error arrays empty. Retain before evidence separately.
- Run relevant navigation, evidence review, expense, logbook, scanner and onboarding tests, then the product test suite as feasible; report any existing failures rather than hiding them.
- flutter analyze lib and changed tests; no newly introduced issues.

## Scope decisions
Use a consistent UI-only active-vehicle/current-FY scope for Expenses/Trips, with explicit labels; retain vault records visible where applicable. Keep default Tax Summary routes but use the evidence review presentation as the status authority. Simplify overly dense form/status presentation rather than clamping text sizes.

## Verification — 2026-11-08
- 66 render cases, including navigation over the Trips page and both remaining onboarding steps: zero JSON errors.
- 54 affected-flow tests passed, followed by all 14 final product regression contracts (overlapping sets).
- Analyzer: no issues in lib and the new regression/capture harness files.
- Broad product suite: 450 passed, 10 failed; every remaining failure reproduced in an isolated copy of the pre-change UI/source. No new failures in that run. Final focused checks cover the later toolbar and Add-trip placement details.
- No tax engine, data model, persistence, auth service or export-generation changes. Device/assistive-technology checks remain unverified.
- Provenance, raw logs and before/after screenshots: .audit/menu-remediation-2026-11-08/.

Final visual inspection: large Logbook navigation reflows into two rows based on measured label width. Add trip uses an accessible toolbar control instead of covering ledger rows. Standalone ledgers and record checks listen for state changes after review.
