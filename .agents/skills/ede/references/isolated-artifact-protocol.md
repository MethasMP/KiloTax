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
boundary_level: "Tier A | Tier B | Tier C | Tier D"
tier_a_citation: "Statute clause / Official Tax Ruling / Approved Architecture Spec Section"
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
verdict: "PENDING | FALSIFIED | DISPROVEN | DISCARDED"
```

> **Mandatory Rule on `tier_a_citation`:** Any Auditor claim submitted without an explicit, verifiable `tier_a_citation` clause or claiming violations outside system invariants MUST be immediately marked as `DISCARDED` without requiring code modifications.

---

## 3. Subagent Briefing Templates

### Role A: The Adversarial Auditor Prompt
```
You are the EDE Adversarial Auditor. Your sole objective is FALSIFICATION.
DO NOT praise the code. DO NOT propose cosmetic improvements.
Your task: Find exactly ONE concrete scenario, edge-case, or regulatory edge (ATO / ITAA 1997 / Statutory Rule) where the target code violates its system invariants.
Constraint: You MUST cite the exact Tier A statutory clause or specification contract in `tier_a_citation`.
Output your finding strictly as an Evidence Claim Sheet. Include an executable Dart unit test that currently FAILS against this code.
```

### Role B: The Architectural Defender Prompt
```
You are the EDE Architectural Defender.
You have been provided with an Evidence Claim Sheet and a failing test case.
Your task:
1. Verify `tier_a_citation`: If invalid, fabricated, or unsupported by statutory truth, declare Tier A Invalidation (`verdict: DISCARDED`).
2. Verify `boundary_level`: If the attack targets a function whose inputs are guaranteed sanitized by upstream Tier B models/validators, declare Boundary Defense (`verdict: DISCARDED`).
3. Otherwise, provide the minimal, surgical patch to make the test GREEN without regressing existing invariants.
```

### 3.1 Context Slicing & Boundary Contract
To prevent token explosion (<4,000 tokens) while avoiding false-positive dissents from isolated auditors:
- Subagent dispatch MUST feed: (1) Target file diff, (2) Immediate Schema / Input Boundary contract (Tier B), and (3) Target Tier Invariant statement.
- Do NOT feed entire historical conversational logs.

---

## 4. Test-as-Debate Ground Truth Arbiter
When an Auditor submits a claim with a `counterexample_test`:
1. The harness executes the test against the codebase.
2. If the test **FAILS (Exit code != 0)** $\rightarrow$ The vulnerability is verified! Verdict = `FALSIFIED`.
3. If the test **PASSES (Exit code == 0)** $\rightarrow$ The attack failed to break the system. Verdict = `DISPROVEN`.
No human or AI debate is permitted to overrule this deterministic runtime outcome.
