# EDE Hardening & Vulnerability Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 3 structural vulnerabilities in EDE (Auditor Poisoning, Context Slicing False Positives, and Execution Bottleneck) by embedding self-correcting mechanisms into EDE and integrating complementary skills (`contract-first`, `iterative-retrieval`, and `gateguard`).

**Architecture:** Strengthen the core EDE protocol via Tier A Citation Enforcement in Evidence Claims, Boundary-Aware Arbitrations, and an Automated Risk-Tier Gate script in `tool/ede/`. Ensure verification via deterministic test execution and invariant verification.

**Tech Stack:** Dart CLI, YAML schemas, Markdown Protocols, Git hooks / tooling scripts.

**Spec:** EDE v2.0 Protocol Hardening Specification.

## Global Constraints
- Token budget per claim round must remain under 4,000 tokens (`isolated-artifact-protocol.md`).
- Deterministic outcome: 1 reproducible failing test overrules consensus (`dissent-arbitration.md`).
- Invariant hierarchy Tier A -> B -> C -> D remains inviolable (`verify_ede_invariants.dart`).

## Review Focus
- Auditor claims lacking a concrete Tier A citation must be rejected automatically.
- Boundary check must prevent spurious dissent when inputs are sanitized at Tier B.
- Risk gate must accurately categorize changes without human intervention.

---

## File Structure Map
- **Modify:** `.agents/skills/ede/SKILL.md` — Incorporate hardened workflow, gatekeeper rules, and contract verification.
- **Modify:** `.agents/skills/ede/references/isolated-artifact-protocol.md` — Add mandatory `tier_a_citation` and `boundary_scope` to Evidence Claim Sheet schema.
- **Modify:** `.agents/skills/ede/references/dissent-arbitration.md` — Formalize Tier A Invalidation and Boundary Invalidation criteria.
- **Create:** `tool/ede/triage_risk_gate.dart` — Automated CLI tool to evaluate git diff and classify changes into Tier 1 (Full EDE) vs Tier 2 (Fast-Track).
- **Create/Modify:** `test/tool/ede_hardening_test.dart` — Unit tests verifying schema compliance, triage classifier, and invalidation rules.

---

## Tasks

### Task 1: Harden Evidence Claim Schema & Audit Rule (Vulnerability 1: "Who Audits the Auditor?")
**Files:**
- `.agents/skills/ede/references/isolated-artifact-protocol.md`
- `.agents/skills/ede/references/dissent-arbitration.md`

- [x] **Step 1: Write verification test for schema fields**
  Create test asserting that claim files require `tier_a_citation` with non-empty reference.
- [x] **Step 2: Update Claim Sheet Schema**
  Add mandatory fields to `.agents/skills/ede/references/isolated-artifact-protocol.md`:
  - `tier_a_citation: "Statute / Official Rule / Approved Spec clause"`
  - `boundary_level: "Tier A | Tier B | Tier C | Tier D"`
- [x] **Step 3: Update Dissent Arbitration with Auto-Discard Rule**
  Update `.agents/skills/ede/references/dissent-arbitration.md`:
  - If a claim lacks a valid Tier A citation or asserts an illegal rule, Defender files Tier A Invalidation -> Claim is automatically DISCARDED without code changes.
- [x] **Step 4: Verify test passes**
  Ensure test asserts claim validation logic accurately.

---

### Task 2: Boundary-Aware Defense & Retrieval Slicing (Vulnerability 2: Context Slicing False Positives)
**Files:**
- `.agents/skills/ede/references/isolated-artifact-protocol.md`
- `.agents/skills/ede/references/adversarial-falsification.md`

- [x] **Step 1: Define Boundary Defense Clause**
  Add System Boundary Rule in `dissent-arbitration.md`:
  - If an Auditor's test attacks a local function with inputs rejected by an upstream Tier B validator, Defender can claim "Boundary Sanitized" with proof of upstream validation -> Claim is ARCHIVED as Out-of-Scope.
- [x] **Step 2: Add Retrieval Context Guideline**
  In `isolated-artifact-protocol.md`, specify prompt packaging for Auditors:
  - Feed Target File + Immediate Boundary Contract (from `contract-first` / Schema) so Auditor knows incoming guarantees without needing full chat context.
- [x] **Step 3: Review and verify against sample claims**
  Run simulated boundary check to confirm boundary falsifications are properly arbitrated.

---

### Task 3: Automated Risk-Tier Gatekeeper (Vulnerability 3: Execution Bottleneck)
**Files:**
- `tool/ede/triage_risk_gate.dart`
- `.agents/skills/ede/SKILL.md`

- [x] **Step 1: Write test for Risk Gate classifier**
  Create `test/tool/triage_risk_gate_test.dart` to test file pattern matching:
  - `lib/services/engine/*` -> Tier 1 (High Stakes)
  - `lib/models/*` -> Tier 1
  - `lib/views/*`, `lib/widgets/*` -> Tier 2 (Low Stakes)
- [x] **Step 2: Implement `tool/ede/triage_risk_gate.dart`**
  Build CLI that checks `git diff --name-only` against critical path patterns and outputs triage verdict (`TIER_1` or `TIER_2`) with explanation.
- [x] **Step 3: Run tests and verify**
  Run `dart test test/tool/triage_risk_gate_test.dart` and confirm green.
- [x] **Step 4: Update `SKILL.md`**
  Document `dart run tool/ede/triage_risk_gate.dart` as the mandatory starting point to avoid friction.

---

### Task 4: End-to-End Verification of the Hardened EDE Workflow
**Files:**
- `tool/ede/verify_ede_invariants.dart`
- `.agents/skills/ede/SKILL.md`

- [x] **Step 1: Run complete invariant verification suite**
  Execute `dart run tool/ede/verify_ede_invariants.dart` to ensure no invariant regressions.
- [x] **Step 2: Cross-check against the 3 Vulnerabilities**
  Verify that:
  1. Spurious auditor tests without Tier A are rejected.
  2. Boundary-safe attacks are correctly dismissed.
  3. UI changes bypass the full debate bottleneck smoothly.
