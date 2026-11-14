# Trip Detection Blind Spots Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the top 3 critical failure modes in Autonomous Trip Detection: Traffic Light Trap (extended red lights in arterial roads), 2-Minute Coffee Stop fragmentation (Trip Stitching Buffer), and Passenger Dilemma disambiguation.

**Architecture:**
1. Enhance `AutonomousTripDetector` with an Arterial Road Extension guard that doubles the Ghost Anchor timeout to 10 minutes when `isArterialRoad == true` or when vehicle Bluetooth remains connected with stationary fixes.
2. Introduce a `TripStitchingEngine` (or stitch buffer in detector) allowing trips terminated within the last 5 minutes to be resurrected and spliced seamlessly into a single unbroken trip when driving resumes within 5 minutes.
3. Add a Passenger Disambiguation flag in `AppState` / notification pipeline requiring explicit 1-tap confirmation when driving motion is detected without a verified Car Bluetooth connection.

**Tech Stack:** Flutter / Dart, Geolocator, AudioSession, FlutterBluePlus, SQLite / LocalStorageService.

**Spec:** Identified from real-world telemetry benchmarks and IEEE ITS automatic trip detection standards.

## Global Constraints
- ATO ITAA 1997 Division 28 & TR 2021/1: Logbook must maintain an unbroken, audit-proof chain of business travel with accurate start and end odometers.
- Zero battery drain regression: No high-frequency continuous background scanning without movement.
- Single Source of Truth: Invariant calculations remain in `AutonomousTripDetector` and `SensorFusionTrackingEngine`.

## Review Focus
- Red light duration > 5 minutes on highway/arterial road must NOT finalize trip prematurely.
- Quick stop <= 5 minutes at gas station or cafe must merge trip segments and keep original departure point.
- Passenger in colleague's car must be flagged with `isUnverifiedPassengerDrive == true` if no car Bluetooth is bonded.
- Monotonic odometer progression must be preserved across stitched trips.
- Dead reckoning fallback must preserve coordinates during brief GPS drops.

---

### Task 1: Traffic Light Trap (Dynamic Arterial Dwell Guard)

**Files:**
- Modify: `lib/services/tracking/autonomous_trip_detector.dart`
- Test: `test/autonomous_trip_detector_test.dart`

**Interfaces:**
- Consumes: `isBluetoothCarConnected`, `isArterialRoad`
- Produces: Dynamic `effectiveGhostAnchorTimeout` (default 5 min, extended to 10 min when car BT remains connected or on arterial road)

- [ ] **Step 1: Write the failing test**
```dart
test('7. Traffic Light Trap: Stationary for 7 minutes with Car Bluetooth connected does NOT finalize trip', () async {
  final detector = AutonomousTripDetector(
    routingService: mockRoutingService,
    ghostAnchorTimeout: const Duration(minutes: 5),
  );
  // Simulate active driving, then stationary for 7 minutes with car bluetooth connected
  // Expect state to remain ghostAnchorPending, NOT finalized
});
```

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/autonomous_trip_detector_test.dart`
Expected: FAIL with "Expected: ghostAnchorPending, Actual: finalized"

- [ ] **Step 3: Implement dynamic timeout in `AutonomousTripDetector`**
Extend ghost anchor timeout check in `autonomous_trip_detector.dart`:
```dart
final effectiveTimeout = isBluetoothCarConnected
    ? const Duration(minutes: 10)
    : ghostAnchorTimeout;
```

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/autonomous_trip_detector_test.dart`
Expected: PASS

---

### Task 2: Trip Stitching Buffer (Anti-Fragmentation for Quick 2-Minute Stops)

**Files:**
- Modify: `lib/services/tracking/autonomous_trip_detector.dart`
- Modify: `lib/state/app_state.dart`
- Test: `test/services/tracking/trip_stitching_test.dart`

**Interfaces:**
- Consumes: `Trip? finalizedTrip`, `DateTime? lastTripFinalizedTime`
- Produces: `canStitchWithPreviousTrip(DateTime newStartTime, Position newStartFix)`

- [ ] **Step 1: Write the failing test in `test/services/tracking/trip_stitching_test.dart`**
Verify that when a second trip starts within 300 seconds (5 minutes) of the last trip finalization and within 300m, the two trips stitch into one continuous trip preserving the initial trip's start point.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/services/tracking/trip_stitching_test.dart`
Expected: FAIL (file or class not found)

- [ ] **Step 3: Implement Trip Stitching logic in `AutonomousTripDetector` and `AppState`**
When `startLiveDrive` or `ingestAutonomousFix` triggers, inspect the most recently completed trip. If `now.difference(previousTrip.endTime) <= Duration(minutes: 5)`, re-open and stitch the path.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/services/tracking/trip_stitching_test.dart`
Expected: PASS

---

### Task 3: The Passenger Dilemma (Zero-Bluetooth Disambiguation Notification)

**Files:**
- Modify: `lib/state/app_state.dart`
- Modify: `lib/data/models/trip.dart`
- Test: `test/passenger_disambiguation_test.dart`

**Interfaces:**
- Consumes: `_isBluetoothLinked`, `isDriving`
- Produces: `trip.isPassengerUnverified` flag and notification prompt

- [ ] **Step 1: Write the failing test in `test/passenger_disambiguation_test.dart`**
Verify that a trip detected purely via GPS/Motion with NO vehicle Bluetooth linked has `isPassengerUnverified: true` and triggers a user resolution prompt.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/passenger_disambiguation_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `isPassengerUnverified` attribute on `Trip` and handle in `AppState`**
Add nullable boolean `isPassengerUnverified` on `Trip` model and set it in `ingestAutonomousFix` when starting drive without `_isBluetoothLinked`.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/passenger_disambiguation_test.dart`
Expected: PASS
