# CPK Tax Engine & Impeccable UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement audit-proof CPK ATO features (Bulky Tools 1-tap chip, Method Arbitrage insight, Multi-Vehicle Cap isolation, Tolls/Parking bypass, and Commercial Vehicle Guard) with an impeccable, non-slop ergonomic UI.

**Architecture:** Domain tax logic resides strictly in decoupled engines (`AtoTaxPeriodEngine`, `TaxCalculatorService`, `VehicleClassificationEngine`) with zero legal jargon in widgets. UI surfaces rely on progressive disclosure, tactile 1-tap chips, Emil Kowalski-inspired physics (`AppMotion`), and AAA WCAG-compliant design tokens (`AppColor`).

**Tech Stack:** Flutter / Dart, Supabase Postgres, Lucide Icons, Custom Design Tokens (`AppColor`, `AppMotion`, `AppTypography`).

---

### Task 1: Vehicle Commercial Classification Guard (Domain Engine)

**Files:**
- Create: `lib/services/vehicle/vehicle_classification_engine.dart`
- Test: `test/services/vehicle/vehicle_classification_engine_test.dart`
- Modify: `lib/data/models/vehicle.dart`

**Step 1: Write the failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/vehicle/vehicle_classification_engine.dart';
import 'package:kiloclaim/data/models/vehicle.dart';

void main() {
  test('correctly identifies commercial vehicles with payload over 1000kg', () {
    final uteOver1T = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'HiLux Single Cab',
      year: 2024,
      payloadKg: 1105,
      taxMethod: TaxMethod.actualExpenses,
    );
    expect(VehicleClassificationEngine.isOverOneTonnePayload(uteOver1T), isTrue);
    expect(VehicleClassificationEngine.isEligibleForCpk(uteOver1T), isFalse);
  });
}
```

**Step 2: Run test to verify it fails**
Run: `flutter test test/services/vehicle/vehicle_classification_engine_test.dart`
Expected: FAIL with compilation error (class or methods not found)

**Step 3: Implement minimal code**
Implement `VehicleClassificationEngine` that verifies payload against 1,000 kg cap and flags Section 8-1 actual expenses vs ITAA 1997 Division 28 Car definition.

**Step 4: Run test to verify it passes**
Run: `flutter test test/services/vehicle/vehicle_classification_engine_test.dart`
Expected: PASS

**Step 5: Commit**
Run: `git commit -m "feat(tax): add vehicle commercial classification guard for CPK eligibility"`

---

### Task 2: 1-Tap Bulky Tools Context Chip (UI Component)

**Files:**
- Create: `lib/ui/screens/trips/widgets/bulky_tools_toggle_chip.dart`
- Test: `test/ui/screens/trips/widgets/bulky_tools_toggle_chip_test.dart`
- Modify: `lib/ui/screens/trips/trip_quick_resolve_sheet.dart`

**Step 1: Write the failing widget test**
Verify that tapping the chip toggles state, fires `AppHaptic.select()`, scales subtly by `AppMotion.pressScale`, and immediately updates claim context without requiring text input.

**Step 2: Run test to verify it fails**
Run: `flutter test test/ui/screens/trips/widgets/bulky_tools_toggle_chip_test.dart`
Expected: FAIL

**Step 3: Implement minimal code**
Build `BulkyToolsToggleChip` using `AppColor.surface`, `AppColor.brandTint`, `AppColor.positiveInk` and smooth 160ms toggle transition.

**Step 4: Run test to verify it passes**
Run: `flutter test test/ui/screens/trips/widgets/bulky_tools_toggle_chip_test.dart`
Expected: PASS

**Step 5: Commit**
Run: `git commit -m "feat(ui): implement tactile 1-tap bulky tools toggle chip with haptics"`

---

### Task 3: Method Arbitrage Milestone Card (Progressive Disclosure)

**Files:**
- Create: `lib/ui/screens/dashboard/widgets/method_arbitrage_card.dart`
- Test: `test/ui/screens/dashboard/widgets/method_arbitrage_card_test.dart`
- Modify: `lib/ui/screens/dashboard/dashboard_screen.dart`

**Step 1: Write the failing test**
Ensure the card stays hidden when business distance is under 4,000 km, and slides into view with an encouraging, actionable comparison only when Logbook method yields higher financial return.

**Step 2: Run test to verify it fails**
Run: `flutter test test/ui/screens/dashboard/widgets/method_arbitrage_card_test.dart`
Expected: FAIL

**Step 3: Implement minimal code**
Build `MethodArbitrageCard` featuring dynamic savings delta, polite dismiss option, and 1-tap transition to Logbook evaluation modal.

**Step 4: Run test to verify it passes**
Run: `flutter test test/ui/screens/dashboard/widgets/method_arbitrage_card_test.dart`
Expected: PASS

**Step 5: Commit**
Run: `git commit -m "feat(dashboard): add contextual method arbitrage milestone card"`

---

### Task 4: Multi-Vehicle Independent Cap Allocator

**Files:**
- Modify: `lib/services/engine/tax_calculator_service.dart`
- Modify: `lib/ui/screens/cpk/widgets/multi_vehicle_cap_card.dart`
- Test: `test/services/engine/tax_calculator_service_multi_vehicle_test.dart`

**Step 1: Write the failing test**
Validate that having 2 active CPK vehicles calculates each vehicle with an independent 5,000 km cap (up to 10,000 km total).

**Step 2: Run test to verify it fails**
Run: `flutter test test/services/engine/tax_calculator_service_multi_vehicle_test.dart`
Expected: FAIL

**Step 3: Implement minimal code**
Update calculation logic to isolate `cappedKm` per `vehicleId`.

**Step 4: Run test to verify it passes**
Run: `flutter test test/services/engine/tax_calculator_service_multi_vehicle_test.dart`
Expected: PASS

**Step 5: Commit**
Run: `git commit -m "feat(tax): enforce independent statutory 5,000 km caps per vehicle"`
