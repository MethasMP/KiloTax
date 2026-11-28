import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  group('AppState - Scope tax calculation to vehicle and financial year', () {
    late AppState appState;

    final primaryVehicle = Vehicle(
      id: 'veh_primary',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'HILUX-01',
      initialOdometer: 10000.0,
      taxMethod: TaxMethod.logbook,
    );

    final secondaryVehicle = Vehicle(
      id: 'veh_secondary',
      make: 'Hyundai',
      model: 'i30',
      regoPlate: 'I30-02',
      initialOdometer: 30000.0,
      taxMethod: TaxMethod.centsPerKm,
    );

    final primaryCurrentFyTrip = Trip(
      id: 't_primary_current',
      vehicleId: 'veh_primary',
      distanceKm: 100.0,
      date: DateTime(2026, 8, 15),
      purpose: 'Client inspection',
      startOdometer: 10000.0,
      endOdometer: 10100.0,
      classification: TripClassification.business,
    );

    final primaryPriorFyTrip = Trip(
      id: 't_primary_prior',
      vehicleId: 'veh_primary',
      distanceKm: 250.0,
      date: DateTime(2025, 10, 10),
      purpose: 'Old job site',
      startOdometer: 9000.0,
      endOdometer: 9250.0,
      classification: TripClassification.business,
    );

    final secondaryCurrentFyTrip = Trip(
      id: 't_secondary_current',
      vehicleId: 'veh_secondary',
      distanceKm: 80.0,
      date: DateTime(2026, 9, 20),
      purpose: 'Secondary site',
      startOdometer: 30000.0,
      endOdometer: 30080.0,
      classification: TripClassification.business,
    );

    final primaryCurrentFyExpense = VehicleExpense(
      id: 'exp_primary_current',
      vehicleId: 'veh_primary',
      amount: 150.0,
      category: ExpenseCategory.fuel,
      date: DateTime(2026, 8, 20),
    );

    final primaryPriorFyExpense = VehicleExpense(
      id: 'exp_primary_prior',
      vehicleId: 'veh_primary',
      amount: 300.0,
      category: ExpenseCategory.fuel,
      date: DateTime(2025, 11, 5),
    );

    final secondaryCurrentFyExpense = VehicleExpense(
      id: 'exp_secondary_current',
      vehicleId: 'veh_secondary',
      amount: 90.0,
      category: ExpenseCategory.fuel,
      date: DateTime(2026, 9, 22),
    );

    setUp(() {
      appState = AppState();
      appState.addVehicle(primaryVehicle);
      appState.addVehicle(secondaryVehicle);
      appState.selectVehicle(primaryVehicle.id);

      appState.recordTrip(primaryCurrentFyTrip);
      appState.recordTrip(primaryPriorFyTrip);
      appState.recordTrip(secondaryCurrentFyTrip);

      appState.recordExpense(primaryCurrentFyExpense);
      appState.recordExpense(primaryPriorFyExpense);
      appState.recordExpense(secondaryCurrentFyExpense);
    });

    test('createEvidenceEngine isolates trips and expenses to primary vehicle and active FY', () {
      final engine = appState.createEvidenceEngine();

      expect(engine.vehicle.id, equals('veh_primary'));
      expect(engine.trips.length, equals(1));
      expect(engine.trips.first.id, equals('t_primary_current'));
      expect(engine.expenses.length, equals(1));
      expect(engine.expenses.first.id, equals('exp_primary_current'));
    });

    test('createEvidenceEngine allows targeting a specific historical financial year', () {
      final priorEngine = appState.createEvidenceEngine(financialYear: '2025-26');

      expect(priorEngine.vehicle.id, equals('veh_primary'));
      expect(priorEngine.trips.length, equals(1));
      expect(priorEngine.trips.first.id, equals('t_primary_prior'));
      expect(priorEngine.expenses.length, equals(1));
      expect(priorEngine.expenses.first.id, equals('exp_primary_prior'));
    });

    test('taxSummary isolates calculations strictly to primary vehicle and active FY', () {
      final summary = appState.taxSummary;

      // Only primaryCurrentFyTrip (100 km business, 100% business percentage)
      expect(summary.totalKm, equals(100.0));
      expect(summary.businessKm, equals(100.0));
      expect(summary.personalKm, equals(0.0));
      expect(summary.businessPercentage, equals(100.0));

      // Only primaryCurrentFyExpense ($150 fuel)
      expect(summary.totalRunningExpenses, equals(150.0));
      expect(summary.logbookClaim, equals(150.0));
    });

    test('switching vehicle isolates taxSummary to the new primary vehicle and active FY', () {
      appState.selectVehicle(secondaryVehicle.id);

      final summary = appState.taxSummary;

      // Only secondaryCurrentFyTrip (80 km)
      expect(summary.totalKm, equals(80.0));
      expect(summary.businessKm, equals(80.0));
      expect(summary.centsPerKmClaim, equals(72.8));
      // Only secondaryCurrentFyExpense ($90)
      expect(summary.totalRunningExpenses, equals(90.0));
    });

    test('FY boundary check on 30 June vs 1 July partitions correctly', () {
      final june30Trip = Trip(
        id: 't_june30',
        vehicleId: 'veh_primary',
        distanceKm: 50.0,
        date: DateTime(2026, 6, 30, 23, 59, 59),
        purpose: 'End of year run',
        startOdometer: 9500.0,
        endOdometer: 9550.0,
        classification: TripClassification.business,
      );

      final july1Trip = Trip(
        id: 't_july1',
        vehicleId: 'veh_primary',
        distanceKm: 60.0,
        date: DateTime(2026, 7, 1, 0, 0, 0),
        purpose: 'New year run',
        startOdometer: 9550.0,
        endOdometer: 9610.0,
        classification: TripClassification.business,
      );

      appState.recordTrip(june30Trip);
      appState.recordTrip(july1Trip);

      // In FY 2026-27, july1Trip is included, june30Trip is in 2025-26
      final activeEngine = appState.createEvidenceEngine();
      final activeTripIds = activeEngine.trips.map((t) => t.id).toList();
      expect(activeTripIds.contains('t_july1'), isTrue);
      expect(activeTripIds.contains('t_june30'), isFalse);

      final priorEngine = appState.createEvidenceEngine(financialYear: '2025-26');
      final priorTripIds = priorEngine.trips.map((t) => t.id).toList();
      expect(priorTripIds.contains('t_june30'), isTrue);
      expect(priorTripIds.contains('t_july1'), isFalse);
    });
  });
}
