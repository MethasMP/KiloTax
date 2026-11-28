import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/evidence/evidence_auto_match_engine.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Evidence Auto-Match Receipt Ingestion Integration Tests', () {
    late AppState appState;
    final primaryVehicle = Vehicle(
      id: 'veh_hilux_01',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'TRD-889',
      vehicleType: VehicleType.ute,
      taxMethod: TaxMethod.logbook,
    );

    final tripTime = DateTime(2026, 10, 24, 10, 30);
    final candidateTrip = Trip(
      id: 'trip_site_visit_1',
      vehicleId: 'veh_hilux_01',
      date: tripTime,
      distanceKm: 18.5,
      purpose: 'Emergency Plumbing Repair',
      classification: TripClassification.business,
      taxMethod: TaxMethod.logbook,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      appState = AppState(storageService: storage);
      await appState.init();
      await appState.addVehicle(primaryVehicle);
      appState.recordTrip(candidateTrip);
    });

    test('Ingested receipt automatically finds and binds to candidate work trip within time window', () {
      final receiptTime = tripTime.add(const Duration(minutes: 25)); // 10:55 AM
      final scannedExpense = VehicleExpense(
        id: 'exp_bunnings_01',
        vehicleId: 'veh_hilux_01',
        amount: 142.80,
        category: ExpenseCategory.toolsMaterials,
        date: receiptTime,
        notes: 'Bunnings Trade Supplies',
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: scannedExpense,
        candidateTrips: appState.trips,
      );

      expect(match, isNotNull);
      expect(match!.trip.id, equals('trip_site_visit_1'));
      expect(match.matchReason, contains('Matched work trip'));

      // Link in AppState when expense is committed
      final committedExpense = scannedExpense.copyWith(
        linkedTripId: match.trip.id,
      );
      appState.recordExpense(committedExpense);

      // Verify bidirectional linkage in AppState
      final storedExpense = appState.expenses.firstWhere((e) => e.id == 'exp_bunnings_01');
      expect(storedExpense.linkedTripId, equals('trip_site_visit_1'));

      final storedTrip = appState.trips.firstWhere((t) => t.id == 'trip_site_visit_1');
      expect(storedTrip.linkedExpenseIds, contains('exp_bunnings_01'));
    });

    test('User can unlink expense or change linked trip seamlessly in AppState', () {
      final trip2 = Trip(
        id: 'trip_site_visit_2',
        vehicleId: 'veh_hilux_01',
        date: tripTime.add(const Duration(hours: 1)),
        distanceKm: 12.0,
        purpose: 'Follow-up Inspection',
        classification: TripClassification.business,
        taxMethod: TaxMethod.logbook,
      );
      appState.recordTrip(trip2);

      final expense = VehicleExpense(
        id: 'exp_fuel_01',
        vehicleId: 'veh_hilux_01',
        amount: 88.00,
        category: ExpenseCategory.fuel,
        date: tripTime.add(const Duration(minutes: 15)),
        linkedTripId: 'trip_site_visit_1',
      );
      appState.recordExpense(expense);

      // Verify initial link
      expect(appState.trips.firstWhere((t) => t.id == 'trip_site_visit_1').linkedExpenseIds,
          contains('exp_fuel_01'));

      // 1. Change linked trip to trip2
      appState.linkExpenseToTrip(expenseId: 'exp_fuel_01', tripId: 'trip_site_visit_2');
      expect(appState.expenses.firstWhere((e) => e.id == 'exp_fuel_01').linkedTripId,
          equals('trip_site_visit_2'));
      expect(appState.trips.firstWhere((t) => t.id == 'trip_site_visit_1').linkedExpenseIds,
          isNot(contains('exp_fuel_01')));
      expect(appState.trips.firstWhere((t) => t.id == 'trip_site_visit_2').linkedExpenseIds,
          contains('exp_fuel_01'));

      // 2. Unlink expense
      appState.unlinkExpenseFromTrip(expenseId: 'exp_fuel_01');
      expect(appState.expenses.firstWhere((e) => e.id == 'exp_fuel_01').linkedTripId, isNull);
      expect(appState.trips.firstWhere((t) => t.id == 'trip_site_visit_2').linkedExpenseIds,
          isNot(contains('exp_fuel_01')));
    });
  });
}
