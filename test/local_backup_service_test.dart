import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/storage/local_backup_service.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBackupService - Data Export & Backup Integrity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('createBackupPayload generates complete structured JSON schema', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'veh_test_1',
        make: 'Toyota',
        model: 'Hilux SR5',
        regoPlate: 'VIC-TRADIE',
        taxMethod: TaxMethod.logbook,
        initialOdometer: 10000.0,
      );
      await appState.addVehicle(vehicle);

      final trip = Trip(
        id: 'trip_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 9, 15, 8, 0),
        startOdometer: 10000.0,
        endOdometer: 10050.0,
        distanceKm: 50.0,
        purpose: 'Site inspection',
        originAddress: 'Richmond',
        destinationAddress: 'Hawthorn',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      final expense = VehicleExpense(
        id: 'exp_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 9, 15),
        category: ExpenseCategory.fuel,
        amount: 120.50,
        notes: 'BP Petroleum',
      );
      appState.recordExpense(expense);

      final payload = LocalBackupService.createBackupPayload(appState);

      expect(payload['format'], equals('KiloTax_Backup_v1'));
      expect(payload['exportedAt'], isNotNull);
      expect(payload['primaryVehicleId'], equals(vehicle.id));

      final stats = payload['stats'] as Map<String, dynamic>;
      expect(stats['totalVehicles'], equals(1));
      expect(stats['totalTrips'], equals(1));
      expect(stats['totalExpenses'], equals(1));

      final vehicles = payload['vehicles'] as List;
      expect(vehicles.length, equals(1));
      expect(vehicles.first['model'], equals('Hilux SR5'));

      final trips = payload['trips'] as List;
      expect(trips.length, equals(1));
      expect(trips.first['purpose'], equals('Site inspection'));

      final expenses = payload['expenses'] as List;
      expect(expenses.length, equals(1));
      expect(expenses.first['amount'], equals(120.50));
    });
  });
}
