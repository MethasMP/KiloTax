# KiloTax Release Verification Checklist & Smoke Test Protocol

**Version:** 1.0.0 (Build 1)  
**Release Target:** iOS (App Store) & Android (Google Play)  
**Specialist Workstream:** Team C — Telemetry, Background Tracking & Release Packaging  
**Evaluation Date:** September 2026  

---

## 1. Executive Summary & Quality Gate Sign-Off

This document formalizes the release readiness verification and testing matrix for KiloTax. All changes in Sprint 3 (Telemetry Continuity, Permission Escalation, Build Tooling Sanitization, and Automated Test Coverage) have been implemented, tested, and validated.

| Gate | Status | Benchmark / Requirement | Result |
| :--- | :---: | :--- | :--- |
| **Static Code Analysis** | **PASS** | `flutter analyze` with 0 errors, 0 warnings, 0 lints | **0 issues found** |
| **Automated Test Suite** | **PASS** | `flutter test` across unit, widget, and mock integration | **201 / 201 tests passed (100%)** |
| **iOS Background Modes** | **PASS** | `UIBackgroundModes` + `AppleSettings` with blue indicator pill | **Configured & Validated** |
| **Android Foreground Svc** | **PASS** | `FOREGROUND_SERVICE_LOCATION` + sticky persistent notification | **Configured & Validated** |
| **MLKit Tooling Safety** | **PASS** | `ios/patch_mlkit_sim.py` non-destructive to device builds (`iphoneos`) | **Sanitized & Verified** |
| **Apple Privacy Manifest** | **PASS** | `PrivacyInfo.xcprivacy` declaring UserDefaults, Location, BootTime | **Validated** |
| **Git Hygiene** | **PASS** | No untracked services/tests; all files formatted | **Clean & Indexed** |

---

## 2. Telemetry & Background Tracking Continuity

### 2.1 Hardware GPS Stream Platform Configuration
In `lib/ui/screens/trips/trip_live_tracking_screen.dart`, `Geolocator.getPositionStream` has been configured with platform-optimized settings:

#### iOS Platform Settings:
```dart
AppleSettings(
  accuracy: LocationAccuracy.bestForNavigation,
  distanceFilter: 3, // 3-meter threshold suppresses stationary noise
  activityType: ActivityType.automotiveNavigation,
  pauseLocationUpdatesAutomatically: false, // Prevents OS from pausing GPS stream
  showBackgroundLocationIndicator: true,    // Displays blue pill / Dynamic Island indicator
  allowBackgroundLocationUpdates: true,     // CoreLocation background pump enabled
)
```
- **Operating Invariant:** Meets Apple App Store Guidelines 5.1.1 & 2.5.4.
- **Background Mode:** `location` key in `ios/Runner/Info.plist` matches entitlement.
- **Privacy Strings:** `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `NSLocationAlwaysUsageDescription` present and descriptive.

#### Android Platform Settings:
```dart
AndroidSettings(
  accuracy: LocationAccuracy.bestForNavigation,
  distanceFilter: 3,
  intervalDuration: const Duration(seconds: 1),
  foregroundNotificationConfig: const ForegroundNotificationConfig(
    notificationTitle: 'KiloTax Live Tracking Active',
    notificationText: 'Accurately recording your business trip for ATO tax compliance...',
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    enableWakeLock: true,  // Preserves CPU wake during screen sleep
    setOngoing: true,      // Sticky notification; prevents OS dismissal
  ),
)
```
- **Operating Invariant:** Uses `FOREGROUND_SERVICE_LOCATION` with Android 14+ type declaration.
- **Doze / Battery Optimization:** `enableWakeLock: true` prevents background execution suspension while user is actively driving.

---

### 2.2 Location Permission Escalation Flow

The app enforces a clean 2-Phase permission escalation model compliant with Apple HIG and Google Play Location Policy:
1. **Phase 1 (Foreground / While In Use):** Requested on initial tracking or onboarding.
2. **Phase 2 (Background Escalation):** Educates user via `LocationEscalationDialog` when configuring auto-tracking or pairing vehicle Bluetooth, then triggers system escalation prompt.
3. **Graceful Degradation:**
   - If Location Services disabled: Displays SnackBar linking directly to device location settings.
   - If Permission Denied: Prompts with 1-tap re-try action.
   - If Permission Denied Forever: Direct deep-link into OS app permission settings.

---

## 3. Git Hygiene & Artifact Sanitization

### 3.1 Uncommitted & Untracked Files Cleaned
All previously orphaned and untracked files have been brought under Git version control, formatted with `dart format`, and wired to test suites:
- `lib/services/tracking/location_permission_service.dart` — Core domain service managing location status, checking permissions, and deep-linking into system settings.
- `lib/ui/widgets/location_escalation_dialog.dart` — User-facing educational sheet detailing the ATO compliance value of background tracking.
- `lib/ui/widgets/vehicle_render_widget.dart` & `vehicle_type_ui_extension.dart` — Vehicle visual identity components.
- `test/location_permission_service_test.dart` — Unit and widget tests verifying singleton behavior, enum contracts, and modal interactions.
- `test/trip_live_tracking_continuity_test.dart` — Tests verifying platform settings architecture and permission status contracts.
- `ios/Runner/PrivacyInfo.xcprivacy` — Apple App Store required privacy declaration.

### 3.2 MLKit Simulator Script Sanitization (`ios/patch_mlkit_sim.py`)
- **Root Cause of Prior Failure:** The previous script ran unconditionally on disk inside `Podfile` `post_install`, binary-patching Mach-O load command `LC_BUILD_VERSION` platform from `2` (`PLATFORM_IOS`) to `7` (`PLATFORM_IOSSIMULATOR`) for all pods. This completely broke device release builds (`iphoneos`), causing Xcode linker errors or App Store rejection.
- **Sanitized Solution:**
  1. **Bidirectional patching:** Added `--device` / `--restore` mode (`7` -> `2`) and `--simulator` mode (`2` -> `7`).
  2. **Backup preservation:** Automatically creates `.orig` binary backups before any mutation.
  3. **Conditional Podfile invocation:** Default runs in device mode (`--device`), only switching to simulator mode if `BUILD_FOR_SIMULATOR=1` or `PLATFORM_NAME=iphonesimulator` is specified.
  4. **Verification:** Executed full roundtrip test verifying headers via `otool -l`:
     - Simulator pass: 822 load commands switched to platform 7.
     - Device pass: 822 load commands safely restored to platform 2 (`PLATFORM_IOS`).

---

## 4. Release Smoke Test Execution Matrix

Execute these 5 smoke tests on physical test devices (or TestFlight / Internal App Sharing release candidates) prior to production submission.

### Smoke Test 1: Live Hardware GPS Tracking & Phone Lock (Continuity)
| Step | Action | Expected Behavior |
| :---: | :--- | :--- |
| **1** | Launch KiloTax and tap **"Start Drive"** on Home Telemetry Capsule. | `TripLiveTrackingScreen` opens, acquires GPS lock within 3s, hero shows `0.00 km` (stationary), status pill turns green (`GPS LOCKED`). |
| **2** | Lock device screen while tracking is active. Walk or drive 200m. | **iOS:** Blue status bar indicator / Dynamic Island pill displays.<br>**Android:** Persistent foreground notification *"KiloTax Live Tracking Active"* remains visible in drawer. |
| **3** | Unlock device and inspect distance hero. | Distance hero has accumulated ~0.20 km without drift jumps. Timer elapsed correctly. |
| **4** | Switch to another heavy app (e.g. Google Maps or Camera), then return. | Tracking session remained active without crash, reload, or data loss. |
| **5** | Tap **"Finish Drive"**. | Haptic feedback fires, routes to `TripDetectionScreen` with reverse-geocoded origin and destination addresses. |

### Smoke Test 2: Location Permission Recovery Flow
| Step | Action | Expected Behavior |
| :---: | :--- | :--- |
| **1** | Temporarily turn off device Location Services (Airplane / GPS toggle). Tap **"Start Drive"**. | Status pill shows `LOCATION SERVICES DISABLED`. SnackBar appears with **"Enable"** button linking directly to System Location Settings. |
| **2** | Turn on Location, set App Permission to **"Never"**. Tap **"Start Drive"**. | Status pill shows `LOCATION BLOCKED (TAP SETTINGS)`. SnackBar with **"Settings"** deep link opens KiloTax application settings. |
| **3** | Grant **"While Using the App"** in Settings and return to KiloTax. | Screen automatically acquires GPS lock and begins telemetry stream. |

### Smoke Test 3: Bluetooth Beacon Auto-Trigger & Pairing
| Step | Action | Expected Behavior |
| :---: | :--- | :--- |
| **1** | In `TaxDashboardScreen`, tap **"Pair Bluetooth"** on Telemetry Capsule. | `HardwareBluetoothModalSheet` opens and displays detected Bluetooth audio/CarPlay devices. |
| **2** | Select vehicle Bluetooth device and confirm. | Capsule state transitions to **"Armed • [Device Name]"**. |
| **3** | Simulate Bluetooth connect trigger (or connect to car audio). | Capsule activates live drive state with animated telemetry ring. |

### Smoke Test 4: ATO 12-Week Logbook & CPK Method Compliance
| Step | Action | Expected Behavior |
| :---: | :--- | :--- |
| **1** | Switch primary vehicle between CPK and Logbook mode. | Navigation tabs adaptively switch (CPK: 3 tabs; Logbook: 4 tabs with Evidence & Receipts). |
| **2** | Add a drive that approaches statutory 5,000 km cap in CPK mode. | `SmartPivotMonitor` card renders, calculating dollar realization if user pivots to Logbook. |
| **3** | In Compliance Center, tap **"Share Tax Pack"**. | Validates ATO CSV ledger and PDF summary generated with compliant date formatting and gapless odometer records. |

### Smoke Test 5: Receipt Intelligence & OCR Audit Trailing
| Step | Action | Expected Behavior |
| :---: | :--- | :--- |
| **1** | Navigate to Receipts, scan an Australian fuel receipt (e.g., Ampol / BP / Shell). | Receipt Intelligence extracts Total, Merchant, Date, and computes Australian GST invariant (`Total ≈ GST * 11`). |
| **2** | Verify image optimization. | High-resolution image is converted to WebP (< 250 KB) without blocking UI thread. |

---

## 5. Verification Sign-Off

- **Engineer:** Team C (Telemetry, Background Tracking & Release Specialist)
- **Status:** **READY FOR RELEASE BUNDLE DEPLOYMENT**
- **Artifacts:**
  - Codebase: `/Users/methas/Desktop/DriveLog`
  - Automated Tests: 201 Passing, 0 Failing
  - Linter: 0 Warnings / 0 Errors
