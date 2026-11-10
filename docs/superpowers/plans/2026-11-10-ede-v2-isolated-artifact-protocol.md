# EDE v2.0 & Isolated Artifact Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the Evidence-Driven Engineering (EDE) framework into a production-grade, low-context, audit-proof system by implementing the Isolated Artifact Protocol (Team A) alongside the EDE 4-Pillar Verification Harness (Team B).

**Architecture:** Two decoupled sub-systems sharing a common file-backed protocol contract:
1. **Team A (Protocol & Engine):** Pure, schema-enforced artifact generation (Evidence Claim Sheets + Test-as-Debate runner) residing in `.ede/` to keep context footprint below 4k tokens per debate round.
2. **Team B (Governance & Invariants):** Invariant hierarchy verification script (`verify_ede_invariants.dart`), TDD pressure-tested skill rules, adversarial catalog, and immutable dissent ledger.

**Tech Stack:** Dart (command-line verification & test automation), Markdown/YAML (schema contract), Git-backed persistent audit ledger.

**Spec:** EDE Framework Enhancement Proposal (Combining Anthropic Evaluator-Optimizer + Karpathy Bounded Loop + Isolated Multi-Agent Dissent).

---

## Global Constraints

- **Single Source of Truth:** Tier C engines (e.g. `TaxCalculatorService`) remain authoritative; Tier D (UI/PDF/Excel) must never duplicate formulas.
- **Context Boundary:** Subagents in debate rounds must NEVER share full conversation transcripts; they receive only the target file, spec diff, and compact claim schema.
- **Audit Persistence:** Dissents, evidence claims, and counterexamples must be saved to `.ede/claims/` and `.ede/ledger/` as reproducible artifacts.
- **Zero Flakiness:** All debate falsification tests must be deterministic executable unit tests in `test/ede/`.
- **Backward Compatibility:** Existing `test/services/` and flutter analyze checks must remain 100% green.

## Review Focus

1. **Context Leakage:** Subagents accidentally passing conversational bloat into claim sheets.
2. **Rubber-stamping in Isolated Subagents:** Subagents producing trivially passing claims (`expect(true, isTrue)`).
3. **Ghost Gaps:** Odometer reconciler or tax calculator invariants being violated by mock debate tests.
4. **File Leftovers:** Temporary test fixtures not properly scrubbed from `.ede/temp/`.
5. **Schema Divergence:** Team A's claim sheet structure diverging from Team B's verification validator.

---

## Team Allocation & File Structure

```
.agents/skills/ede/
├── SKILL.md                                 # Core EDE v2 Skill (Updated)
├── references/
│   ├── isolated-artifact-protocol.md        # Team A: Protocol Specification & Prompt Templates
│   ├── adversarial-falsification.md         # Team B: ATO Tax & System Attack Vectors Catalog
│   └── dissent-arbitration.md               # Team B: Dissent Ledger & Resolution Rules
tool/ede/
├── verify_ede_invariants.dart               # Team B: Automated Invariant & Schema Checker
└── run_debate_falsification.dart            # Team A: Subagent Debate Test Harness
.ede/
├── claims/                                  # Structured Claim Sheets (.yaml/.md)
└── ledger/                                  # Permanent Audit Trail (Dissent & Invariant Log)
test/ede/
├── protocol_schema_test.dart                # Team A Unit Tests
└── invariant_engine_test.dart               # Team B Unit Tests
```

---

## Phase 1: Shared Contract Definition (Interface-First)

### Task 1: Define the Structured Evidence Claim Schema & Storage Spec
- [ ] Create `.ede/claims/.gitkeep` and `.ede/ledger/.gitkeep`
- [ ] Define the exact YAML/Markdown specification for the `Evidence Claim Sheet` in `.agents/skills/ede/references/isolated-artifact-protocol.md`:
  - `claim_id`: UUID/hash
  - `target_invariant`: Tier A/B/C/D
  - `target_file`: Absolute or relative path
  - `vulnerability`: Max 100 words description
  - `counterexample_test`: Path to runnable `.dart` test or embedded snippet
  - `verdict`: `PENDING` | `FALSIFIED` | `DISPROVEN`
- [ ] Write unit test `test/ede/protocol_schema_test.dart` to validate parsing of standard claim sheets.
- [ ] Run `dart test test/ede/protocol_schema_test.dart` and confirm failure (RED).
- [ ] Implement parser logic in `tool/ede/verify_ede_invariants.dart` to make test pass (GREEN).
- [ ] Commit: `feat(ede): define evidence claim schema and parsing contract`

---

## Phase 2: Team A Execution — Isolated Artifact Protocol (Context-Saver Engine)

### Task 2: Build the Subagent Isolated Briefing & Prompt Templates
- [ ] Draft prompt templates in `.agents/skills/ede/references/isolated-artifact-protocol.md` for 2 distinct roles:
  - **Adversarial Auditor:** Role-blind, given only target code + invariant rules, strictly tasked with writing a failing test.
  - **Architectural Defender:** Tasked with defending or applying the minimal patch to satisfy the invariant.
- [ ] Enforce the **Blind First-Round Rule**: Template forbids passing previous conversation history.
- [ ] Commit: `docs(ede): add isolated subagent prompt templates and protocol guide`

### Task 3: Build the "Test-as-Debate" Test Runner Tool
- [ ] Create `tool/ede/run_debate_falsification.dart`:
  - Accepts a claim sheet with an embedded test case.
  - Injects the test into a temporary test sandbox (`test/ede/generated/`).
  - Executes `flutter test <temp_test>`.
  - Parses exit code:
    - Exit code != 0 (RED) -> Vulnerability confirmed! Debate Won by Auditor.
    - Exit code == 0 (GREEN) -> Attack failed! Invariant holds.
- [ ] Write integration test validating `run_debate_falsification.dart` with a mock failing and passing case.
- [ ] Commit: `feat(ede): implement deterministic test-as-debate runner tool`

---

## Phase 3: Team B Execution — EDE 4-Pillar Evolution & Invariant Checker

### Task 4: Implement the Tier Invariant Verification Script
- [ ] Create `tool/ede/verify_ede_invariants.dart` supporting:
  - Check Tier C -> Tier D formula purity: Regex scan ensuring UI screens (`lib/ui/`) do NOT contain manual tax arithmetic (e.g. `* 0.85` or raw business percentage math).
  - Check Multi-Vehicle CPK Invariant: Ensures `TaxCalculatorService` strictly caps at 5,000 km per vehicle, not per taxpayer.
- [ ] Add CLI flag `--check-all` to run in CI / pre-commit.
- [ ] Add unit test in `test/ede/invariant_engine_test.dart` verifying that invariant breaches are flagged.
- [ ] Commit: `feat(ede): add automated tier invariant verification script`

### Task 5: Build the Adversarial Attack Vectors Catalog & Dissent Ledger
- [ ] Create `.agents/skills/ede/references/adversarial-falsification.md`:
  - Catalog 10 critical ATO & Tradie failure modes (e.g., GPS drift near Bunnings, Null GST trade supplies, Odometer rollover at 999,999 km, Concurrency during background location ping).
- [ ] Create `.agents/skills/ede/references/dissent-arbitration.md`:
  - Define the Dissent Preservation Protocol: If 1 agent produces a valid failing test case, consensus is blocked until either the test is fixed or the invariant is proven invalid.
- [ ] Commit: `docs(ede): document adversarial attack catalog and dissent ledger protocol`

---

## Phase 4: Integration, TDD Pressure Test & Verification

### Task 6: Skill TDD Pressure Test (Watching an Agent Comply)
- [ ] Update `.agents/skills/ede/SKILL.md` to incorporate v2.0 workflow:
  - Embed the Isolated Artifact Protocol.
  - Link to `references/` for heavy prompts to preserve context.
  - Add the Invariant Verification Script invocation steps.
- [ ] Run a simulated pressure test:
  - Prompt a subagent with a high-pressure scenario ("Quickly approve this tax formula change without testing").
  - Verify that EDE v2 blocks the action and demands an Evidence Claim Sheet + Test run.
- [ ] Commit: `feat(ede): publish EDE v2.0 skill with integrated artifact protocol`

### Task 7: Full Suite Sanity & Regression Check
- [ ] Run `dart analyze lib/ test/ tool/` -> ensure 0 errors.
- [ ] Run `flutter test test/services/` -> ensure all 90 existing core tests pass.
- [ ] Run `dart run tool/ede/verify_ede_invariants.dart --check-all` -> ensure all invariants pass.
- [ ] Verify `.ede/claims/` and `.ede/ledger/` directory health.
- [ ] Commit: `chore(ede): verify full integration and test compliance`
