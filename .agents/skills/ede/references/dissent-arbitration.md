# Dissent Preservation & Arbitration Protocol

## Core Principle
> "Majority vote does not equal truth. In engineering, one reproducible failing test overrules ten approving reviews."

---

## 1. The Dissent Lifecycle
1. **Dissent Raised:** An Adversarial Auditor generates an Evidence Claim Sheet containing a valid failing unit test (`counterexample_test`), explicit `boundary_level`, and verifiable `tier_a_citation`.
2. **Deterministic Verification:** The test runner (`tool/ede/run_debate_falsification.dart`) executes the test.
   - If test fails $\rightarrow$ Dissent is evaluated for legitimacy.
   - If test passes $\rightarrow$ Dissent is **DISPROVEN & ARCHIVED**.
3. **Resolution Requirement:** A blocking dissent can ONLY be resolved in three ways:
   - **Code Fix:** Architectural Defender patches the code so the counterexample test turns GREEN without regressing other tests.
   - **Tier A Invalidation:** The Defender proves that the counterexample asserts an illegal premise, lacks a valid `tier_a_citation`, or violates statutory ground truth $\rightarrow$ Dissent is **DISCARDED**.
   - **Boundary Invalidation:** The Defender demonstrates that the attack scenario is impossible at runtime because inputs are already validated and sanitized by an upstream boundary (Tier B) $\rightarrow$ Dissent is **ARCHIVED AS OUT-OF-SCOPE**.

---

## 2. Permanent Dissent Ledger (`.ede/ledger/`)
When a critical decision is made or a debate is resolved, record the entry in `.ede/ledger/YYYY-MM-DD_<feature>.md`:

```markdown
# EDE Audit Decision Record

- **Date:** 2026-11-10
- **Feature:** Tax Calculator Multi-Vehicle Cap
- **Auditor Finding:** Claim #claim_20261110_abc123
- **Vulnerability:** Cap pooled across vehicles
- **Resolution:** Patched `tax_calculator_service.dart` to index cap per `vehicleId`.
- **Verified Evidence:** `test/services/engine/tax_calculator_service_multi_vehicle_test.dart` PASSED.
- **Dissent Status:** RESOLVED.
```
