# Isolated Artifact Protocol Specification (EDE v3.0)

## Overview
The **Isolated Artifact Protocol** solves the context-window explosion problem of multi-agent debate. Instead of running open-ended conversational meetings that cost 30k–60k tokens and produce sycophantic consensus, agents operate in **isolated context sandboxes** and communicate strictly via structured **Evidence Claim Sheets**.

Under **EDE v3.0**, we integrate:
1. **Multi-Model Blind Testing:** The Auditor and Implementer run on separate models/subagents to prevent shared cognitive bias.
2. **Deterministic Red $\rightarrow$ Green Falsification:** A claim is verified ONLY when its test demonstrably fails before the patch and passes after.
3. **Debt Ledger:** Any deferred technical debt is formally recorded with TTL.

---

## 1. Context Boundaries & Token Guarantees
- **No Shared History:** An auditor subagent receives *only* the specific target file, the proposed change diff, and the relevant invariant tier rule.
- **Strict Budget:** A debate exchange MUST NOT exceed 4,000 tokens per round.
- **Blind First-Round:** Auditors and Defenders generate their claims independently before any cross-examination.

---

## 2. Evidence Claim Sheet Schema

Every claim filed in `.ede/claims/` MUST follow this exact schema:

```yaml
claim_id: "claim_<timestamp>_<short_hash>"
timestamp: "YYYY-MM-DDTHH:mm:ssZ"
author: "tax-lawyer | cso | edge-breaker | concurrency"
model_used: "model-identifier (e.g. gemini-pro, codex, claude)"
target_invariant: "Tier A | Tier B | Tier C | Tier D"
target_file: "path/to/target/file.dart"
vulnerability: >
  Concise explanation of the potential bug, regulatory breach, or invariant violation.
  Maximum 100 words. No boilerplate.
severity: "CRITICAL | MAJOR | MINOR"
counterexample_test: |
  void main() {
    test('Falsification counterexample', () {
      // Minimal test case proving the vulnerability
    });
  }
verdict: "PENDING | FALSIFIED | DISPROVEN | RESOLVED"
```

---

## 3. Subagent Briefing Templates & Model Routing

### Strategy: Blind Cross-Model Routing
- **Implementer (Feature author):** Primary coding model (e.g., Gemini / Claude).
- **Auditor (Adversary):** Different model family or fresh isolated subagent context with adversarial temperature.

### Subagent Prompt (Auditor):
```
You are the EDE Adversarial Auditor [Role: <tax-lawyer|cso|edge-breaker>].
Your sole objective is FALSIFICATION of the target file.
DO NOT praise the code. DO NOT suggest cosmetic refactoring.
Find ONE concrete, reproducible scenario that violates statutory rules (Tier A) or engine integrity (Tier C).
Deliver your output as an Evidence Claim Sheet containing an executable Dart test that currently FAILS.
```

---

## 4. Test-as-Debate Ground Truth Arbiter
When an Auditor submits a claim with a `counterexample_test`:
1. **Red Phase (`--mode=falsify`):**
   ```bash
   dart run tool/ede/run_debate_falsification.dart .ede/claims/<claim>.yaml
   ```
   - Must return exit code 0 (`FALSIFIED`), meaning the test successfully broke the current implementation.
2. **Patch Phase:** Implementer writes minimal surgical fix.
3. **Green Phase (`--mode=verify-fix`):**
   ```bash
   dart run tool/ede/run_debate_falsification.dart .ede/claims/<claim>.yaml --mode=verify-fix
   ```
   - Must return exit code 0 (`RESOLVED`), confirming test passes cleanly.
