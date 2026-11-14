# Evidence handoff implementation plan

> **For agentic workers:** Use superpowers:executing-plans for root integration and focused delegates for independent implementation and review. The user requests autonomous execution.

**Goal:** Complete the review, evidence sharing, and optional feedback workflow.

**Architecture:** One typed completeness report feeds a review screen and an evidence pack builder. Existing editors persist corrections. Feedback stays on-device until the user explicitly shares it.

**Tech stack:** Flutter, Dart, existing storage, archive, PDF, native email and sharing.

**Spec:** docs/superpowers/specs/2026-11-07-evidence-handoff-design.md

## Global constraints

Preserve the dirty checkout. No tax algorithm changes. No automatic external messages or analytics. Private routes and device paths stay out of exports. Export incomplete records only with disclosed issues. No claims of audit acceptance.

## Workflow checklist

- [x] Read the Principles section of the poteto-mode skill.
- [x] Phase A: Frame.
- [x] Phase B: Design the workflow.
- [x] Phase C: Run the loop.
- [x] Phase D: Keep the audit trail.
- [x] Phase E: Verify and hand back.

## Task 1. Review report and correction flow

- [x] Write failing tests for vehicle and year isolation, missing purposes, unknown classification, missing or changed files, and confirmation that clears an issue.
- [x] Implement `EvidenceReviewService.evaluate` and asynchronous receipt inspection with typed report items.
- [x] Add a review entry to the ledger and a screen linking existing trip, expense, and gap editors.
- [x] Make receipt attachment and explicit human confirmation persist without overwriting OCR history.
- [x] Run domain and widget regression tests.

## Task 2. Honest portable evidence pack

- [x] Reproduce invented defaults and unconditional guarantees in export tests.
- [x] Preserve absent information and distinguish file presence, OCR state, and user confirmation.
- [x] Build a ZIP with PDF, ledgers, receipt index, available images, and unresolved issues.
- [x] Use bundled fonts so PDF export works offline.
- [x] Wire the existing export action to the ZIP and test real archive contents and dispatch payload.

## Task 3. Optional feedback

- [x] Test local draft round-trip and exact text with no tax records included.
- [x] Add a bounded feedback draft model and local storage.
- [x] Add a preview form reachable from settings and after export. Sharing requires an explicit tap.
- [x] Test persistence, cancellation, preview, and sharing payload.

## Task 4. Verification and review

- [x] Run targeted analysis, relevant regression tests, and rendering checks.
- [x] Compare failures with baseline and correct task regressions.
- [x] Have a fresh reviewer inspect code, comments, tests, archive, and decision trail.
- [x] Record tested outcomes and limitations in the delivery report.

## Throughput checkpoint

Two independent implementation streams own disjoint files after interface agreement. Root owns feedback, integration, verification, and review synthesis. Existing uncommitted work makes whole-file commits unsafe, so the deliverable stays reviewable in the current checkout with a saved baseline and task-only diff. No database migrations or new backend.

## Review focus

Cross-vehicle and year leakage, missing files after review, unclassified trips mislabeled personal, private details in exported records, and canceled email composers claimed as successful delivery. Each belongs in the owning task's behavior tests.
