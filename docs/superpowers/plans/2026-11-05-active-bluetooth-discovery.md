# Precision Active Bluetooth Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Car Bluetooth discovery screen into an industry-leading "Tri-Layer Active Radar" that continuously discovers car audio routes, system paired devices, and live BLE broadcasts with intelligent vehicle brand heuristic matching.

**Architecture:**
- **Layer 1 & 2 (HardwareBluetoothService):**
  - Instant inspection of active `AudioSession` devices (CarPlay / Car Audio).
  - Immediate query of iOS/Android system paired/bonded devices.
  - Continuous active BLE stream without a short 4-second timeout while the view is mounted.
  - Intelligent filtering: strip anonymous MAC/empty device junk while prioritizing automotive names.
- **Layer 3 (Vehicle Brand Matching & UI Radar):**
  - Add `matchedScore(String vehicleMake, String deviceName)` to prioritize matched car names (e.g. "Toyota", "Ford SYNC", "CarPlay", "Car Multimedia").
  - Animated pulsing radar indicator displaying real-time scanning activity.
  - Instant auto-highlighting / badge for matched devices.
  - Safe lifecycle management: auto-stops scanning upon view dispose to protect battery.

**Tech Stack:** Flutter, Dart, `flutter_blue_plus`, `audio_session`.

---

### Task 1: Enhance `HardwareBluetoothService` with Continuous Stream & Smart Filtering

**Files:**
- Modify: `lib/services/tracking/hardware_bluetooth_service.dart`

**Detailed Steps:**
- [ ] Add `isAutomotiveCandidate(String name)` heuristic to filter out smart home/wearable clutter.
- [ ] Implement `activeRadarStream()` that:
  - Immediately yields active audio route devices.
  - Yields system bonded devices from `FlutterBluePlus.systemDevices([])`.
  - Maintains continuous BLE scanning loop with rolling results updates without prematurely timing out while subscribed.
- [ ] Add vehicle make matching helper `isMatchedWithVehicle(HardwareBluetoothDevice dev, String make)`.

---

### Task 2: Redesign Car Bluetooth Screen in `VehicleSetupFlow` into Active Radar UI

**Files:**
- Modify: `lib/ui/screens/vehicle/vehicle_setup_flow.dart`

**Detailed Steps:**
- [ ] Replace static 4s scan trigger with continuous subscription to `activeRadarStream()`.
- [ ] Implement a live pulsing radar visual animation when scanning is active.
- [ ] Sort discovered devices:
  1. Connected audio / CarPlay routes & Matched vehicle brand devices (top priority with "Recommended" badge).
  2. Other identified audio / vehicle Bluetooth systems.
  3. General Bluetooth devices.
- [ ] Add 1-tap select with instant tactile feedback.
- [ ] Ensure subscription is cleanly cancelled on view switch or dispose.

---

### Task 3: Verification & Analysis

**Files:**
- Verify with `flutter analyze lib/services/tracking/ lib/ui/screens/vehicle/`.
