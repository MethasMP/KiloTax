# Implementation Plan: Lean 3-Step Value-First Onboarding

> **Goal:** Reorganize onboarding into the industry-standard 3-step flow (Permissions ➔ Vehicle & Bluetooth ➔ Auth & Backup ➔ Dashboard) with zero friction.

## Architecture & Journey Breakdown

```
[Onboarding Lifecycle]
       │
       ▼
[Step 0]: Value Props & Permissions (Location: Always, Motion/Fitness)
       │
       ▼
[Step 1]: Vehicle Selection & Integrated Bluetooth Pairing (All-in-One)
       │
       ▼
[Step 2]: Value-First Auth Gate (Sign in with Apple/Google or Continue as Guest)
       │
       ▼
[Step 3]: Ready to Drive ➔ Main Dashboard
```

## Target Files

- `lib/ui/screens/onboarding/onboarding_flow_screen.dart`:
  - Re-order steps:
    - Step 0: Permission Primer & Enable Tracking (Requests Location Always + Motion).
    - Step 1: Vehicle setup with Bluetooth device pairing built-in.
    - Step 2: Value-first Auth Gate (`ValueFirstGateScreen` / Sign in with Apple/Google or Guest).
    - Step 3: Completion ➔ `MainScaffoldScreen`.
- `lib/ui/screens/vehicle/vehicle_setup_flow.dart`:
  - Ensure Bluetooth pairing is seamlessly integrated in the vehicle creation step rather than hidden in a sub-flow.
- `test/ui/onboarding_flow_test.dart`:
  - Unit & widget test verifying step progression.

## Verification
- `flutter analyze lib/ui/screens/onboarding/`
- `flutter test test/onboarding_auth_state_test.dart test/ui_screens_18_test.dart`
