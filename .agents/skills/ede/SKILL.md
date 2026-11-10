---
name: ede
description: >
  Use when designing or implementing critical features, financial/tax engines,
  architecture decisions, or high-stakes logic where multi-agent consensus is insufficient
  and independent falsifiable runtime evidence is required.
argument-hint: "[feature-name|audit|tier1|tier2]"
license: MIT
---

# EDE — Evidence-Driven Engineering (v2.0)

> "Never trust AI consensus alone. Demand independent, falsifiable runtime evidence."

EDE is an engineering workflow harness designed to eliminate the fundamental flaw of multi-agent coding: **shared model hallucinations and rubber-stamp approvals**. EDE v2.0 introduces the **Isolated Artifact Protocol**—delivering adversarial debate and dissent preservation at a fraction of the context cost (<4k tokens/round).

---

## The 5 Core Pillars of EDE

1. **From Multi-Agent to Multi-Evidence:**
   Independent evidence over shared opinions:
   - **Code Evidence:** Static analysis (`dart analyze`), 0 compiler warnings.
   - **Runtime Evidence:** Automated test executions, deterministic logs.
   - **Formal Invariant Evidence:** Strict Single Source of Truth across Tiers A $\rightarrow$ D.
   - **External Statutory Evidence:** ATO ITAA 1997 Division 28, TR 2021/1.

2. **From Reviewing to Adversarial Falsification:**
   Reviewers act as **Adversarial Auditors** armed with [references/adversarial-falsification.md](references/adversarial-falsification.md). Their sole task: *write an executable failing test proving the system invariants can be broken.*

3. **From Open Chatroom to Isolated Artifact Protocol:**
   Subagents operate in isolated context sandboxes communicating strictly via structured **Evidence Claim Sheets** (`.ede/claims/`). See [references/isolated-artifact-protocol.md](references/isolated-artifact-protocol.md).

4. **From Consensus to Dissent Preservation:**
   If an auditor produces an executable counterexample that breaks the system, **the majority vote is discarded**. The dissent remains blocking until resolved. See [references/dissent-arbitration.md](references/dissent-arbitration.md).

5. **Decision Provenance (Immutable Ledger):**
   Every architectural resolution is recorded in `.ede/ledger/` with the exact passing test evidence.

---

## Invariant Hierarchy (Single Source of Truth Rule)

1. **Tier A (External Statutory Truth):** ATO Tax Laws, ITAA 1997, TR 2021/1. Code can never alter Tier A.
2. **Tier B (Core Domain Entities):** `VehicleExpense`, `Trip`, `AuditRecord`. Enforces data structural integrity.
3. **Tier C (Authoritative Business Engine):** `TaxCalculatorService`, `ForensicAuditAnalyzer`. The Single Source of Truth for calculations.
4. **Tier D (Boundary Adapters, UI & Presentation):** UI views, PDF/Excel generators. **MUST NEVER duplicate calculation logic**; must delegate to Tier C.

---

## Tooling & Verification Automation

EDE v2.0 includes automated CLI tools in `tool/ede/`:

```bash
# Verify presentation layer purity (Ensures Tier D does not calculate tax directly)
dart run tool/ede/verify_ede_invariants.dart

# Run deterministic debate falsification on an auditor claim
dart run tool/ede/run_debate_falsification.dart .ede/claims/<claim-file>.yaml
```

---

## Risk-Based Gates

| Tier | Scope | Required EDE Pipeline |
| :--- | :--- | :--- |
| **Tier 1 (High Stakes)** | Tax engines, ledger calculations, money/payments, authentication, file export I/O, database migrations | **Full EDE Pipeline** (Isolated Auditor Claim Sheet + `run_debate_falsification.dart` + Invariant Check + Ledger Record). |
| **Tier 2 (Low Stakes)** | UI styling, copywriting, non-persisted local presentation | **Fast-Track EDE** (`verify_ede_invariants.dart` + `dart analyze`). |
