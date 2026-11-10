# Isolated Artifact Protocol Specification (EDE v2.0)

## Overview
The **Isolated Artifact Protocol** solves the context-window explosion problem of multi-agent debate. Instead of running open-ended conversational meetings that cost 30k–60k tokens and produce sycophantic consensus, agents operate in **isolated context sandboxes** and communicate strictly via structured **Evidence Claim Sheets**.

---

## 1. Context Boundaries & Token Guarantees
- **No Shared History:** An auditor subagent receives *only* the specific target file, the proposed change diff, and the relevant invariant tier rule.
- **Strict Budget:** A debate exchange MUST NOT exceed 4,000 tokens per round.
- **Blind First-Round:** Auditors and Defenders generate their claims independently before any cross-examination.

---

## 2. Evidence Claim Sheet Schema

Every claim filed in `.ede/claims/` MUST follow this exact schema (YAML / Frontmatter format):

```yaml
claim_id: "claim_<timestamp>_<short_hash>"
timestamp: "YYYY-MM-DDTHH:mm:ssZ"
author: "adversarial_auditor | architectural_defender"
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
verdict: "PENDING | FALSIFIED | DISPROVEN"
```

---

## 3. Subagent Briefing Templates

### Role A: The Adversarial Auditor Prompt
```
You are the EDE Adversarial Auditor. Your sole objective is FALSIFICATION.
DO NOT praise the code. DO NOT propose cosmetic improvements.
Your task: Find exactly ONE concrete scenario, edge-case, or regulatory edge (ATO / ITAA 1997) where the target code violates its system invariants.
Output your finding strictly as an Evidence Claim Sheet. Include an executable Dart unit test that currently FAILS against this code.
```

### Role B: The Architectural Defender Prompt
```
You are the EDE Architectural Defender.
You have been provided with an Evidence Claim Sheet and a failing test case.
Your task: Either (1) demonstrate that the counterexample violates Tier A ground truth (disproving the attack), or (2) provide the minimal, surgical patch to make the test GREEN without regressing existing invariants.
```

---

## 4. Test-as-Debate Ground Truth Arbiter
When an Auditor submits a claim with a `counterexample_test`:
1. The harness executes the test against the codebase.
2. If the test **FAILS (Exit code != 0)** $\rightarrow$ The vulnerability is verified! Verdict = `FALSIFIED`.
3. If the test **PASSES (Exit code == 0)** $\rightarrow$ The attack failed to break the system. Verdict = `DISPROVEN`.
No human or AI debate is permitted to overrule this deterministic runtime outcome.
