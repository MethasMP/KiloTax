# Test failure resolution — 8 November 2026

## EDE decision record

Decision: supplier heuristics supply context and cannot confirm tools carriage. The quick resolve sheet now initializes tools only from existing explicit trip evidence, and checks mounted state after the registration modal returns. Tax formulas and eligibility rules are unchanged.

Rejected: restore automatic tools confirmation or synthetic sample ledger entries solely to satisfy legacy tests. Those assertions encoded unsupported observations.

Independent falsification: the stateless EDE scientist produced three executable contracts. Before the source fix, two failed (address-only tools selection and fabricated tools marker); the explicit-existing-evidence contract passed. Raw red evidence is stored in `.audit/remaining-test-failures-2026-11-08/falsification-red.log`.

Legacy test corrections cover the real manual-drive entry callback, recorded-trip updates, current logbook setup labels and method confirmation, weekend decision semantics, supplier preset persistence, and actual interactive target sizes. Suggested-chip tests retain the unselected-state requirement.

Additional corrections: the tools chip has no invented default deduction; supplied estimates remain supported. The older visual capture harness no longer imports the removed Migration screen.

Verification results are recorded in `.audit/remaining-test-failures-2026-11-08/verification.json`. No unresolved technical dissent. Device-level camera/auth/accessibility verification remains outside these automated checks.

## Verified results

- Broad product suite: 478 passed, zero failed (exit 0).
- Final rerun of all six affected test files after the last chip change: 31 passed, zero failed (exit 0), including the additional no-invented-default contract.
- Full repository `flutter analyze --no-pub`: No issues found (exit 0).
