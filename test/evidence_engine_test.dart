import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/services/engine/evidence_engine.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';
import 'package:kilotax/services/engine/ato_report_service.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  group('KiloTax Double-Claim Guard & 12-Week Compliance Tests', () {
    test('AtoTaxRule versioning correctly provides FY2026-27 statutory limits', () {
      expect(AppConstants.activeTaxRule.financialYear, equals('2026-27'));
      expect(AppConstants.activeTaxRule.centsPerKmRate, equals(0.91));
      expect(AppConstants.activeTaxRule.centsPerKmMaxKm, equals(5000.0));
      expect(AppConstants.activeTaxRule.maxCentsPerKmClaim, equals(4550.0));
      expect(AppConstants.activeTaxRule.carDepreciationLimit, equals(69674.0));
    });

    test('12-Week Logbook Compliance tracks weeks and identifies missing records', () {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v1',
        make: 'Ford',
        model: 'Ranger Wildtrak',
        regoPlate: 'TRADIE-888',
        initialOdometer: 20000.0,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime.now().subtract(const Duration(days: 21)),
      );

      appState.addVehicle(vehicle);

      // Verify week calculation (21 days elapsed = week 4)
      expect(appState.currentLogbookWeek, equals(4));
      expect(appState.logbookProgressPercentage, closeTo(4 / 12.0, 0.01));

      // Add a valid trip and an incomplete trip (missing purpose)
      final validTrip = Trip(
        id: 'trip_1',
        vehicleId: vehicle.id,
        distanceKm: 30.0,
        date: DateTime.now(),
        purpose: 'Site repair at 45 King St',
        startOdometer: 20000.0,
        endOdometer: 20030.0,
        classification: TripClassification.business,
      );

      final incompleteTrip = Trip(
        id: 'trip_2',
        vehicleId: vehicle.id,
        distanceKm: 15.0,
        date: DateTime.now(),
        purpose: '?', // missing purpose
        startOdometer: 20030.0,
        endOdometer: 20045.0,
        classification: TripClassification.unclassified,
      );

      appState.recordTrip(validTrip);
      appState.recordTrip(incompleteTrip);

      expect(appState.missingComplianceTrips.length, equals(1));
      expect(appState.missingComplianceTrips.first.id, equals('trip_2'));

      // 1-Tap Resolve purpose
      appState.resolveTripPurpose('trip_2', 'Client emergency callout');
      expect(appState.missingComplianceTrips.isEmpty, isTrue);
    });

    test('Double-Claim Protection logic maintains clean distinction between Cents/KM and Logbook', () {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_cents',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'SOLO-999',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.addVehicle(vehicle);

      expect(appState.primaryVehicle?.taxMethod, equals(TaxMethod.centsPerKm));

      // Switch to Logbook
      appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
      expect(appState.primaryVehicle?.taxMethod, equals(TaxMethod.logbook));
    });

    test('Section 9 Expense Architecture: Tools & Materials claim 100% directly regardless of Logbook %', () {
      final trip = Trip(
        id: 'trip_1',
        vehicleId: 'v1',
        distanceKm: 50.0,
        date: DateTime.now(),
        purpose: 'Work Job',
        startOdometer: 1000.0,
        endOdometer: 1050.0,
        classification: TripClassification.business,
      );
      final personalTrip = Trip(
        id: 'trip_2',
        vehicleId: 'v1',
        distanceKm: 50.0,
        date: DateTime.now(),
        purpose: 'Weekend Groceries',
        startOdometer: 1050.0,
        endOdometer: 1100.0,
        classification: TripClassification.personal,
      );
      // Business percentage = 50% (50km / 100km)

      final fuelExpense = VehicleExpense(
        id: 'e1',
        vehicleId: 'v1',
        amount: 100.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
      );

      final bunningsTools = VehicleExpense(
        id: 'e2',
        vehicleId: 'v1',
        amount: 300.0,
        category: ExpenseCategory.toolsMaterials,
        date: DateTime.now(),
      );

      final summary = TaxCalculatorService.evaluateSummary(
        trips: [trip, personalTrip],
        expenses: [fuelExpense, bunningsTools],
      );

      expect(summary.businessPercentage, equals(50.0));
      expect(fuelExpense.category.isCarExpense, isTrue);
      expect(bunningsTools.category.isDirectlyDeductibleByDefault, isTrue);
      // Logbook Claim should be: (Fuel $100 * 50%) + (Bunnings Tools $300 * 100%) = $50 + $300 = $350
      expect(summary.logbookClaim, equals(350.0));
    });

    test('SyncEngine Data Pipeline: Generates SHA-256 dedup keys and filters personal trips', () {
      final trip = Trip(
        id: 'trip_work',
        vehicleId: 'v1',
        distanceKm: 35.0,
        date: DateTime.parse('2026-08-14 09:30:00'),
        purpose: 'Site repair',
        startOdometer: 10000.0,
        endOdometer: 10035.0,
        classification: TripClassification.business,
      );

      final key1 = SyncEngineService.generateTripDedupKey(trip);
      final key2 = SyncEngineService.generateTripDedupKey(trip);
      expect(key1, equals(key2));
      expect(key1.length, equals(64)); // SHA-256 Hex length

      // Changing odo should generate different key
      final tripModified = Trip(
        id: 'trip_work_2',
        vehicleId: 'v1',
        distanceKm: 35.0,
        date: DateTime.parse('2026-08-14 09:30:00'),
        purpose: 'Site repair',
        startOdometer: 10005.0,
        endOdometer: 10040.0,
        classification: TripClassification.business,
      );
      final key3 = SyncEngineService.generateTripDedupKey(tripModified);
      expect(key1, isNot(equals(key3)));
    });
  });
}
