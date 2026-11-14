# Hybrid Smart Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorder onboarding journey steps so that Location/GPS permission request follows immediately after vehicle setup, making Bluetooth setup completely optional, and positioning Value Gate (Sign-in / Guest) as the final step before the dashboard.

**Architecture:**
- Update `OnboardingFlowScreen` step flow:
  - Step 0: Onboarding Slides
  - Step 1: Vehicle Setup Flow (Add Vehicle)
  - Step 2: GPS Primer Screen (Immediate tax-guard framing & GPS request)
  - Step 3: Value-First Gate Screen (Sign-in or Continue as Guest / Start Driving)
- Enhance copy on GPS Primer Screen with ATO Tax Guard framing ($0.88/km audit-proof defense).
- Ensure Vehicle Setup Flow makes Bluetooth pairing clearly optional and skip-friendly so users aren't stalled in home environments.

**Tech Stack:** Flutter, Dart, Provider (AppState), Geolocator.

## Global Constraints
- Do not remove any existing auth, guest mode, or GPS tracking logic.
- Preserve Apple Guideline 5.1.1(v) guest login escape hatch.
- Maintain seamless navigation to `MainScaffoldScreen`.

---

### Task 1: Update OnboardingFlowScreen Step Navigation Order & Transitions

**Files:**
- Modify: `lib/ui/screens/onboarding/onboarding_flow_screen.dart`

**Detailed Steps:**
- [ ] In `OnboardingFlowScreen`:
  - When `VehicleSetupFlow` completes (`onVehicleCreated`), set step directly to `_step = 2` which will now be `_buildGpsPermissionAndReadyScreen()`.
  - When GPS screen completes (either permission granted or "Add trips manually instead"), if user is authenticated, go to `_goToMainScreen()`; if not authenticated, proceed to `_step = 3` (`ValueFirstGateScreen`).
  - In `ValueFirstGateScreen`, on sign-in success or "Continue as Guest", invoke `_goToMainScreen()`.
- [ ] Update state tracking in `_handleEnableTracking` to route to step 3 (Value Gate) or main screen depending on auth status.

---

### Task 2: Polish GPS Primer Screen Framing & Loss-Aversion Copy

**Files:**
- Modify: `lib/ui/screens/onboarding/onboarding_flow_screen.dart`

**Detailed Steps:**
- [ ] Update headline and subtext in `_buildGpsPermissionAndReadyScreen`:
  - Headline: "Never lose an $0.88/km tax claim"
  - Subtitle: "ATO requires verified trip routes for logbook compliance. We track silently in the background so every deduction is 100% audit-proof."
  - Primary button label: "Enable Automatic Tracking"
  - Secondary button: "I'll add trips manually"
- [ ] Keep trust badges ("Low battery impact", "Private & device-stored").

---

### Task 3: Verify and Ensure Smooth Bluetooth Optionality in VehicleSetupFlow

**Files:**
- Modify: `lib/ui/screens/vehicle/vehicle_setup_flow.dart`

**Detailed Steps:**
- [ ] Ensure Bluetooth step in `VehicleSetupFlow` is clearly labeled as optional ("Optional - Connect later in car") with a prominent "Skip for now" / "Continue" button so users in living-room context don't get stuck.

---

### Task 4: Verification and Smoke Testing

**Files:**
- Run flutter analyze / tests to ensure zero compilation or navigation errors.
