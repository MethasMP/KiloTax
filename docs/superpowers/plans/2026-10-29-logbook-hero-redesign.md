# Implementation Plan: Redesign & De-slop Logbook Hero Widget (`tax_exemption_streak_hero.dart`)

**Goal**: Transform the cluttered, overflowing, panic-inducing Logbook Hero into a high-end, calm, audit-proof status card that adheres to the 8-point grid, resolves the 31px RenderFlex overflow, and provides clean progressive disclosure for Australian Tradies.

---

## 1. Context & Root Causes
- **File**: `lib/ui/screens/logbook/widgets/tax_exemption_streak_hero.dart`
- **Issue 1 (P0 Overflow)**: Line 691 `STATUTORY CONTINUITY EXCEPTIONS (ATO TR 97/11)` and `${3 - _usedShields.length}/3 Available` in an unconstrained `Row` causes 31px horizontal overflow on standard mobile screens.
- **Issue 2 (Cognitive Overload)**: Double progress trackers (Days logged vs % progress bar vs 5-stage stepper), aggressive red `$12,400 AT RISK`, and dev/ATO jargon (`Telemetry Baseline`, `Representative Travel Pattern`).
- **Issue 3 (Card-in-Card)**: Internal nested card inside the outer hero card creates visual claustrophobia.

---

## 2. Solution Design (Fintech Calm & Audit-Proof)
1. **Hero Header (Single Row)**:
   - Left: `ATO 12-WEEK LOGBOOK` badge (Emerald tint).
   - Right: `Day X of 84 • Week Y of 12` (Muted mono pill).
2. **Hero Core Metrics**:
   - Primary: `\$12,400 Protected` in confident white/positive text.
   - Status subtitle: `5-Year Tax Exemption in progress (ITAA 1997)`
   - Single clean, continuous progress bar (84 days) with soft glow.
3. **Statutory Grace Shields (Audit Defense)**:
   - Header with `Flexible` constraints: `TR 97/11 Continuity Protection` + `3/3 Active`.
   - 3 Clean Action Tiles (`Rained Out`, `Sick Day`, `Tool Recovery`) with tap interaction to log exception and view ATO legal notes via modal sheet.
4. **Progressive Disclosure**:
   - Tapping the progress track or an unobtrusive info icon opens the **Ute Evolution 5-Stage Roadmap** as a dedicated modal sheet, removing the bulky nested box from the main dashboard.

---

## 3. Tasks

- [ ] Task 1: Write widget test `test/tax_exemption_streak_hero_test.dart` to verify zero overflow, proper rendering of metrics, and grace shield taps.
- [ ] Task 2: Refactor `lib/ui/screens/logbook/widgets/tax_exemption_streak_hero.dart`:
  - Fix text overflow in headers using `Flexible` and truncation protection.
  - Simplify visual hierarchy: replace `$12,400 AT RISK` with calm, positive `$12,400 Protected`.
  - Remove nested card-in-card; streamline the 84-day progress bar.
  - Keep 5-stage evolution roadmap accessible via modal sheet when tapped.
- [ ] Task 3: Verify with `flutter test test/tax_exemption_streak_hero_test.dart test/ui_screens_18_test.dart`.
