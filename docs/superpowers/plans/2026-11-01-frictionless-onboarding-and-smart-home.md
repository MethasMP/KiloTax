# Frictionless Onboarding & Smart Home Discovery Plan

> **Goal:** Simplify onboarding down to 30 seconds (Permissions + Bluetooth) and shift Home Base and Odometer setup to passive, contextual discovery post-drive.

## Current State vs Target Architecture

| Feature | Current Implementation | Target Design (Industry Standard: Driversnote/MileIQ) |
|---|---|---|
| **Onboarding Friction** | Multi-step setup asking for manual odometer and vehicle details upfront | 3-step rapid setup: Location Permissions (Always) ➔ Vehicle Bluetooth Link ➔ Ready |
| **Home Base Setup** | None in onboarding (brittle string match or manual lat/lon) | Passive Discovery: Detects repetitive start/end coordinates post-drive, offering 1-tap `[ Save as Home Base ]` |
| **Odometer Tracking** | Rigid prompt during setup | Flexible Baseline: Optional initial reading; Day 1 official snapshot latches when Logbook starts |
| **Trip Classification** | Wall-of-text explanations and legal citations | Clean 1-Tap UI: Business / Personal with post-trip heavy tools checkbox |

## Implementation Steps

1. **Verify Onboarding Lean Flow:** Ensure vehicle setup flow defaults to frictionless Bluetooth pairing and skips manual Home input.
2. **Contextual Home Suggestion Card:** Add a passive discovery prompt on Dashboard when a cluster of trips starts/ends at the same coordinates.
3. **Flutter & Dart Code Review:** Run static analysis and automated test suite.
