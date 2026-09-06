import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/services/engine/evidence_engine.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';
import 'package:kilotax/services/engine/ato_report_service.dart';
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
  });
}
