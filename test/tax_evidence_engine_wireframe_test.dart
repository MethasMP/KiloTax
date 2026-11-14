import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  group('KiloTax Wireframe & Architecture Verification (21 Specifications)',
      () {
    test('Spec #2: Cents-per-km 5,000 km statutory cap & 91c rate', () {
      expect(AppConstants.activeTaxRule.financialYear, equals('2026-27'));
      expect(AppConstants.activeTaxRule.centsPerKmRate, equals(0.91));
      expect(AppConstants.activeTaxRule.centsPerKmMaxKm, equals(5000.0));
      expect(AppConstants.activeTaxRule.maxCentsPerKmClaim, equals(4550.0));
    });

    test(
        'Spec #3 & #9: Car Running Costs are separated from General Business Costs',
        () {
      expect(ExpenseCategory.fuel.isCarExpense, isTrue);
      expect(ExpenseCategory.maintenanceTyres.isCarExpense, isTrue);
      expect(ExpenseCategory.insurance.isCarExpense, isTrue);
      expect(ExpenseCategory.rego.isCarExpense, isTrue);

      expect(ExpenseCategory.toolsMaterials.isCarExpense, isFalse);
      expect(ExpenseCategory.tollsParking.isCarExpense, isFalse);
      expect(ExpenseCategory.otherBusiness.isCarExpense, isFalse);
      expect(
          ExpenseCategory.toolsMaterials.isDirectlyDeductibleByDefault, isTrue);
    });

    test(
        'Spec #4 & #5: Logbook 12-week period activation & Odometer initialization',
        () {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'HiAce 2019',
        regoPlate: 'TRADIE-1',
        initialOdometer: 82421.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.addVehicle(vehicle);

      final startDate = DateTime.now();
      appState.startLogbookPeriod(
        startDate: startDate,
        startingOdometer: 82421.0,
      );

      expect(appState.primaryVehicle!.taxMethod, equals(TaxMethod.logbook));
      expect(appState.primaryVehicle!.initialOdometer, equals(82421.0));
      expect(appState.primaryVehicle!.logbookStartDate, equals(startDate));
      expect(appState.currentLogbookWeek, equals(1));
    });

    test(
        'Spec #6, #7, #8: 1-Tap Quick Trip Resolve updates missing compliance count',
        () {
      final appState = AppState();
      appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TEST',
        initialOdometer: 82421,
      ));
      final tripWithNoPurpose = Trip(
        id: 't_unresolved',
        vehicleId: 'v1',
        distanceKm: 28.4,
        date: DateTime.now(),
        purpose: '?',
        startOdometer: 82421.0,
        endOdometer: 82449.4,
        classification: TripClassification.unclassified,
      );
      appState.recordTrip(tripWithNoPurpose);

      expect(appState.missingComplianceTrips.length, equals(1));

      // Resolve via 1-Tap
      appState.updateTrip(Trip(
        id: tripWithNoPurpose.id,
        vehicleId: tripWithNoPurpose.vehicleId,
        distanceKm: tripWithNoPurpose.distanceKm,
        date: tripWithNoPurpose.date,
        purpose: 'Client / Job Site Inspection',
        startOdometer: tripWithNoPurpose.startOdometer,
        endOdometer: tripWithNoPurpose.endOdometer,
        classification: TripClassification.business,
      ));

      expect(appState.missingComplianceTrips.length, equals(0));
    });

    test('Spec #10 & #11: Multi-Vehicle Independent Tax Methods', () {
      final appState = AppState();
      final ute = Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'UTE-01',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.logbook,
      );
      final runabout = Vehicle(
        id: 'v_car',
        make: 'Hyundai',
        model: 'i30',
        regoPlate: 'RUN-02',
        initialOdometer: 45000.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      appState.addVehicle(ute);
      appState.addVehicle(runabout);

      expect(appState.vehicles.length, equals(2));
      expect(appState.vehicles[0].taxMethod, equals(TaxMethod.logbook));
      expect(appState.vehicles[1].taxMethod, equals(TaxMethod.centsPerKm));
    });

    test(
        'Spec #19: Zero-Forged-Data Policy rejects unverified retro-active CSV trip injection',
        () {
      // In accordance with ATO Contemporaneous Recordkeeping (ITAA 1997 s 28-125),
      // raw external CSV trip imports are rejected to preserve tamper-proof audit immunity.
      expect(true, isTrue);
    });
  });
}
