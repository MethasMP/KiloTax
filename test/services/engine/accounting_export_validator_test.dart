import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/annual_odometer.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/engine/accounting_export_validator.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountingExportValidator - Pre-flight Export Gate (Task C1)', () {
    late AppState emptyState;
    const validator = AccountingExportValidator();

    setUp(() {
      emptyState = AppState();
    });

    tearDown(() {
      emptyState.dispose();
    });

    test('blocks export when no trips in logbook period', () async {
      final vehicle = Vehicle(
        id: 'v-logbook-1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE01',
        initialOdometer: 50000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2026, 1, 1),
      );
      await emptyState.addVehicle(vehicle);

      // Record annual closing odometer so only NO_TRIPS is failing
      emptyState.recordAnnualOdometer(AnnualVehicleOdometer(
        id: 'annual_v1',
        vehicleId: 'v-logbook-1',
        financialYear: emptyState.activeTaxRule.financialYear,
        openingDate: DateTime(2025, 7, 1),
        openingOdometer: 50000,
        closingDate: DateTime(2026, 6, 30),
        closingOdometer: 62000,
      ));

      final result = validator.validate(emptyState);
      expect(result.canExport, isFalse);
      expect(result.errors.any((e) => e.code == 'NO_TRIPS'), isTrue);
    });

    test('blocks export when closing odometer not set', () async {
      final state = AppState();
      addTearDown(state.dispose);

      final vehicle = Vehicle(
        id: 'v-logbook-2',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANGER02',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2026, 1, 1),
      );
      await state.addVehicle(vehicle);

      // Record a valid trip in period, but NO closing odometer
      state.recordTrip(Trip(
        id: 't-1',
        vehicleId: 'v-logbook-2',
        date: DateTime(2026, 1, 15),
        distanceKm: 25.0,
        purpose: 'Site visit',
        startOdometer: 10000,
        endOdometer: 10025,
        taxMethod: TaxMethod.logbook,
      ));

      final result = validator.validate(state);
      expect(result.canExport, isFalse);
      expect(result.errors.any((e) => e.code == 'NO_CLOSING_ODOMETER'), isTrue);
    });

    test('warns when logbook period < 12 weeks', () async {
      final state = AppState();
      addTearDown(state.dispose);

      final vehicle = Vehicle(
        id: 'v-short',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'DMAX03',
        initialOdometer: 20000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2026, 1, 1),
      );
      await state.addVehicle(vehicle);

      // Trips covering only 6 weeks
      state.recordTrip(Trip(
        id: 't-short-1',
        vehicleId: 'v-short',
        date: DateTime(2026, 1, 5),
        distanceKm: 30.0,
        purpose: 'Work commute with bulky tools',
        startOdometer: 20000,
        endOdometer: 20030,
        taxMethod: TaxMethod.logbook,
      ));

      // Complete a short 6-week period (42 days < 84 days)
      state.completeLogbookPeriod(
        completionDate: DateTime(2026, 1, 1).add(const Duration(days: 42)),
      );

      final result = validator.validate(state);
      expect(result.warnings.any((w) => w.code == 'SHORT_LOGBOOK'), isTrue);
      expect(result.errors, isEmpty);
      expect(result.canExport, isTrue); // warning only, not error
    });

    test('passes validation with zero errors or warnings when fully compliant (Logbook)', () async {
      final state = AppState();
      addTearDown(state.dispose);

      final vehicle = Vehicle(
        id: 'v-compliant',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'GOOD01',
        initialOdometer: 30000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2026, 1, 1),
      );
      await state.addVehicle(vehicle);

      state.recordTrip(Trip(
        id: 't-comp-1',
        vehicleId: 'v-compliant',
        date: DateTime(2026, 1, 10),
        distanceKm: 45.0,
        purpose: 'Site visit',
        startOdometer: 30000,
        endOdometer: 30045,
        taxMethod: TaxMethod.logbook,
      ));

      // 12 weeks = 84 days
      state.completeLogbookPeriod(
        completionDate: DateTime(2026, 1, 1).add(const Duration(days: 84)),
      );

      final result = validator.validate(state);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.canExport, isTrue);
    });

    test('CPK mode validates without SHORT_LOGBOOK warning', () async {
      final state = AppState();
      addTearDown(state.dispose);

      final vehicle = Vehicle(
        id: 'v-cpk',
        make: 'Mitsubishi',
        model: 'Triton',
        regoPlate: 'CPK001',
        initialOdometer: 40000,
        taxMethod: TaxMethod.centsPerKm,
      );
      await state.addVehicle(vehicle);

      state.recordTrip(Trip(
        id: 't-cpk-1',
        vehicleId: 'v-cpk',
        date: DateTime.now(),
        distanceKm: 50.0,
        purpose: 'Site inspection',
        startOdometer: 40000,
        endOdometer: 40050,
        taxMethod: TaxMethod.centsPerKm,
      ));

      state.recordAnnualOdometer(AnnualVehicleOdometer(
        id: 'annual_cpk',
        vehicleId: 'v-cpk',
        financialYear: state.activeTaxRule.financialYear,
        openingDate: DateTime(2025, 7, 1),
        openingOdometer: 40000,
        closingDate: DateTime(2026, 6, 30),
        closingOdometer: 45000,
      ));

      final result = validator.validate(state);
      expect(result.errors, isEmpty);
      expect(result.warnings.any((w) => w.code == 'SHORT_LOGBOOK'), isFalse);
      expect(result.canExport, isTrue);
    });
  });
}
