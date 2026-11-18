# Phase 1: Noise Eradication & Hero Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eradicate cognitive noise across KiloTax's main interface by reducing navigation and screens down to the Steve Jobs "Holy Trinity" (Drive/Trips, 1-Tap Snap, Tax/Accountant), burying deep secondary workflows into contextual drawers/settings, and elevating "Send to Accountant" as the unmistakable Hero Action.

**Architecture:**
1. **The Pure 3+1 Bottom Bar:** Unify the polymorphic navbar into 3 crystal-clear destination hubs (`Trips`, `Tax`) with an elevated, prominent center `[ 📷 Snap ]` action button.
2. **Contextual Workflow Consolidation:** Relocate sprawling CPK, Compliance, and Raw Logbook audits into clean contextual action sheets accessible via the Tax & Trips tabs, eliminating duplicated clutter.
3. **Hero Accountant Action:** Standardize the primary hero interaction on the Tax screen to "Send to Accountant" with immediate visual readiness indicators.

**Tech Stack:** Flutter, Dart, Provider (`AppState`), `ScaffoldBottomNavBar`, `MainScaffoldScreen`.

---

## Global Constraints
- Preserve full backwards compatibility with `AppState` and all underlying persistence logic.
- Do not break existing automated journeys: `test/ui/main_menu_redesign_test.dart` and `test/ui/scan_navigation_test.dart` must pass 100%.
- Maintain polymorphic business logic: Cents-per-km (CPK) drivers must never see receipt-hoarding clutter, while Logbook drivers retain receipt evidence access directly from Snap & Tax.

---

## Review Focus
1. **Zero Dead Ends:** Every buried or collapsed sub-screen (CPK setup, Odometer audit) must still be reachable via clear contextual settings/overflow menus.
2. **Semantics & Accessibility:** Bottom bar items and the center scan action must maintain complete semantic labeling and tap-target compliance.
3. **Large Text Scaling:** Responsive layouts must not overflow when accessibility text scale reaches 1.5x.

---

## Tasks

- [x] **Task 1: Unify and De-noise `ScaffoldBottomNavBar`**
  - **Context:** The bottom bar currently shifts between 3 and 4 tabs with disparate icons and confusing naming. We strip the noise so every user gets an intuitive, focused surface.
  - **Deliverable:** Cleaned `lib/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart` with prominent center shutter button and pristine typography.
  - **Verification:** Unit tests in `test/ui/main_menu_redesign_test.dart` passing (12/12 passed).

- [x] **Task 2: Streamline `MainScaffoldScreen` Polymorphic Routing**
  - **Context:** `MainScaffoldScreen` switches between fragmented screen lists. Simplify the top-level indexed stack so Trips and Tax feel native, responsive, and unified.
  - **Deliverable:** Verified clean indexed stack transitions in `lib/ui/screens/home/main_scaffold_screen.dart` with zero visual jumps.
  - **Verification:** Navigation transitions test cleanly without state thrashing (`test/ui/scan_navigation_test.dart` 5/5 passed).

- [x] **Task 3: Elevate "Send to Accountant" in `TaxSummaryScreen`**
  - **Context:** Tradies use KiloTax to solve their tax audit anxiety. The "Send to Accountant" package must be the unmistakable Hero Action with instant clarity.
  - **Deliverable:** Polished primary action card and 56px hero button in `lib/ui/screens/tax/tax_summary_screen.dart` with "AUDIT-PROOF READY" badge.
  - **Verification:** `test/ui/tax_summary_readiness_test.dart` & `test/ui/pre_flight_review_screen_test.dart` pass 100% (22/22 passed across combined suite).
