# Implementation Plan: Sensor Fusion & iOS Background Telemetry Hardening

## Overview
Implement and verify the end-to-end 3-stage core tracking pipeline for KiloTax iOS First, ensuring zero battery drain, zero phantom distance accumulation at red lights, 100% background survival through CoreBluetooth State Restoration, and seamless EOD trip review.

## User Review Required
> [!IMPORTANT]
> The primary focus is **iOS First**: Hardening `KiloTaxBackgroundEngine.swift`, ensuring ZUPT stationary suppression passes 100%, and validating the data pipeline from dead-app state restoration to Flutter SQLite ledger and EOD Review UI.

---

## 3-Stage Core Journey Architecture

```
[ Stage 1: Vehicle Engine Start (Anchor) ]
  └── iOS CBCentralManager with State Restoration ('KiloTaxCarBeacon') wakes dead app.
  └── Low-memory native GPS pipeline activates (RAM < 2MB).
  └── Stationary anti-drift filter (ZUPT) engages (0.00 km accumulation while parked/idling).

[ Stage 2: Highway & Road Navigation (Precision Telemetry) ]
  └── WGS-84 Vincenty Geodesic computation (< 0.5mm geometric error).
  └── 1D Kalman Spatial Filter discards multipath jumps (> 7.0 m/s² or > 160 km/h).
  └── Road-Snap map matching snaps fixes onto Australian road networks.

[ Stage 3: Engine Shutdown & End-of-Day Review (Audit Proof) ]
  └── Bluetooth disconnect triggers trip finalization.
  └── OdometerGapReconciler reconciles delta with physical dashboard snapshot.
  └── Bulky Tools Exemption evaluator flags tool carriage from residence.
  └── Native Telemetry Bridge delivers trip to Flutter SQLite & shows 1-Tap EOD Review Sheet.
```

---

## Step-by-Step Implementation Tasks

### Task 1: Fix Stationary Jitter Filter in `SensorFusionTrackingEngine`
- **File:** `lib/services/tracking/sensor_fusion_tracking_engine.dart`
- **Issue:** `isStationary` condition (`sensorSpeedKmh < 3.0 && rawMeters < minMovementThresholdMeters`) leaks distance when cumulative rawMeters slightly exceeds 3.5m over multiple ticks while speed is 0.0.
- **Fix:** If `sensorSpeedKmh < 0.5` or `newFix.speed <= 0.0`, enforce ZUPT clamp to 0.00 km regardless of satellite micro-drift unless net movement from stationary anchor exceeds GPS 2-sigma radius.
- **Verification:** Run `flutter test test/geodesic_telemetry_rigor_test.dart` and confirm 0.00 meters phantom distance.

### Task 2: Verify and Harden Native Telemetry Bridge on iOS
- **Files:**
  - `ios/Runner/KiloTaxBackgroundEngine.swift`
  - `lib/services/tracking/native_hardware_telemetry_bridge.dart`
- **Changes:**
  - Ensure `KiloTaxBackgroundEngine` correctly stores in-flight trip coordinates into `UserDefaults` with atomic commit.
  - Expose `finalizeNativeTrip()` method via Flutter `MethodChannel('kilotax/hardware_telemetry')`.
  - Handle state restoration callback `centralManager(_:willRestoreState:)` so when Bluetooth beacon reconnects, location updates resume without launching full Flutter UI into foreground.
- **Verification:** Create unit test `test/services/tracking/native_telemetry_bridge_test.dart`.

### Task 3: Integrate Background Trips with EOD Review Flow
- **Files:**
  - `lib/state/app_state.dart`
  - `lib/ui/screens/dashboard/widgets/home_recent_activity.dart`
- **Changes:**
  - When Flutter app launches or resumes, call `fetchCompletedNativeTrips()` from bridge.
  - Auto-convert native trips into `Trip` records with `evidenceSource: 'native_ios_sensor_fusion'`.
  - Trigger `BulkyToolsSuggestionEngine.evaluate(trip)` and prompt 1-Tap confirmation in the EOD review sheet.
- **Verification:** Add widget/integration test `test/ui/eod_trip_review_integration_test.dart`.

### Task 4: Full Suite Regression Verification
- **Command:** `flutter test test/geodesic_telemetry_rigor_test.dart test/trip_live_tracking_continuity_test.dart test/hardware_bluetooth_service_test.dart test/services/odometer_gap_reconciler_test.dart`
- **Pass Criteria:** 100% green tests with zero failures.
