# KiloClaim Evidence Engine & Zero-Touch Ergonomics Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build KiloClaim's 3 Core Pillars: Zero-Touch Vehicle & Bluetooth Onboarding, The 102 Forensic Gap Audit & Tax Risk Analyzer, and Accountant One-Click Workpaper Export (CPA/ATO/Xero/MYOB).

**Architecture:** Pure Dart service layer integrated directly into `lib/services/`:
1. `ZeroTouchSetup`: Zero-API-cost vehicle resolution from Rego & Bluetooth audio handshake.
2. `ForensicAuditAnalyzer`: Evaluates logs against ATO 12-week logbook substantiation rules (Subdivision 28-G ITAA 1997), flags odometer gaps, unlinked receipts, and calculates missed deduction arbitrage ($).
3. `AccountantWorkpaperGenerator`: Generates CPA/CA ANZ compliant audit schedules and exports ready for Xero & MYOB.

**Tech Stack:** Dart 3.5+, Flutter, `flutter_test`.

## Global Constraints
- Native Dart implementation matching existing KiloClaim codebase patterns.
- 100% on-device local execution; zero commercial vehicle API cost.
- Strict ATO 12-week logbook compliance model calculations.
- Test-driven development with isolated unit tests in `test/services/`.

---

### Task 1: Zero-Touch Onboarding (Bluetooth Handshake + Zero-Cost Rego Suggestion)
- [x] **Step 1:** Verify `HardwareBluetoothService` detects connected car audio/CarPlay automatically.
- [x] **Step 2:** Ensure `VehicleLookupService` maps local Australian work vehicle catalog without commercial API fees.

### Task 2: The 102 Forensic Gap Audit & Evidence Auto-Match Engine
- [x] **Step 1:** Build `ForensicAuditAnalyzer` detecting Odometer Gaps (>5km), unlinked receipts, and 12-week period validity.
- [x] **Step 2:** Verify with isolated TDD tests in `test/services/audit/forensic_audit_analyzer_test.dart`.

### Task 3: Accountant One-Click Export & Workpaper Engine
- [x] **Step 1:** Build `AccountantWorkpaperGenerator` creating CPA/CA ANZ audit workpapers.
- [x] **Step 2:** Ensure alignment with `LogbookExportService` for ATO 16-column ledger, Xero, and MYOB exports.
- [x] **Step 3:** Verify with TDD tests in `test/services/export/accountant_workpaper_generator_test.dart`.
