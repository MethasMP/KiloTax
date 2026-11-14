import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/data/models/audit_evidence.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PR-06: Clear in-memory collections and storage on sign out', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('signOut clears _trips, _expenses, _vehicles, and _evidenceList in memory without wipe flag', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'v_user_1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANGER-1',
        initialOdometer: 15000.0,
      );
      await appState.addVehicle(vehicle);

      final trip = Trip(
        id: 't_user_1',
        vehicleId: vehicle.id,
        distanceKm: 60.0,
        date: DateTime(2026, 8, 1),
        purpose: 'Work commute',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      final expense = VehicleExpense(
        id: 'e_user_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 1),
        category: ExpenseCategory.fuel,
        amount: 85.0,
      );
      appState.recordExpense(expense);

      appState.recordAuditEvidence(
        AuditEvidence(
          id: 'ev_1',
          vehicleId: vehicle.id,
          evidenceType: EvidenceType.odometerStart,
          storagePath: '/mock/path/odo.webp',
          imageSha256: 'abc123hash',
          capturedAt: DateTime(2026, 8, 1),
        ),
      );

      // Verify populated memory state
      expect(appState.vehicles, isNotEmpty);
      expect(appState.trips, isNotEmpty);
      expect(appState.expenses, isNotEmpty);
      expect(appState.evidenceList, isNotEmpty);
      expect(appState.primaryVehicle, isNotNull);

      // Execute signOut without wipeLocalData
      await appState.signOut(wipeLocalData: false);

      // Verify all in-memory collections are cleared
      expect(appState.vehicles, isEmpty);
      expect(appState.trips, isEmpty);
      expect(appState.expenses, isEmpty);
      expect(appState.evidenceList, isEmpty);
      expect(appState.primaryVehicle, isNull);
    });

    test('signOut with wipeLocalData=true purges local storage and memory', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'v_wipe_1',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'DMAX-99',
        initialOdometer: 20000.0,
      );
      await appState.addVehicle(vehicle);

      final trip = Trip(
        id: 't_wipe_1',
        vehicleId: vehicle.id,
        distanceKm: 30.0,
        date: DateTime(2026, 8, 2),
        purpose: 'Site run',
      );
      appState.recordTrip(trip);

      await appState.signOut(wipeLocalData: true);

      expect(appState.vehicles, isEmpty);
      expect(appState.trips, isEmpty);
      expect(appState.expenses, isEmpty);
      expect(appState.evidenceList, isEmpty);
      expect(appState.primaryVehicle, isNull);

      // Also verify storage is wiped
      final reloadedTrips = storage.loadTrips();
      expect(reloadedTrips, isEmpty);
      final reloadedVehicles = storage.loadVehicles();
      expect(reloadedVehicles, isEmpty);
    });
  });
}
