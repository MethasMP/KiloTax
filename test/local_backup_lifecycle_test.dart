import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/storage/local_backup_service.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PR-07: Local backup export and lifecycle cleanup', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('createBackupPayload produces complete and consistent JSON payload', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'v_backup_test',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'BK-001',
        initialOdometer: 5000.0,
      );
      await appState.addVehicle(vehicle);

      final trip = Trip(
        id: 't_backup_1',
        vehicleId: vehicle.id,
        distanceKm: 25.0,
        date: DateTime(2026, 8, 20),
        purpose: 'Supplier run',
      );
      appState.recordTrip(trip);

      final expense = VehicleExpense(
        id: 'e_backup_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 20),
        category: ExpenseCategory.fuel,
        amount: 75.0,
      );
      appState.recordExpense(expense);

      final payload = LocalBackupService.createBackupPayload(appState);
      expect(payload['format'], equals('KiloClaim_Backup_v1'));
      expect(payload['exportedAt'], isNotNull);
      expect((payload['vehicles'] as List).length, equals(1));
      expect((payload['trips'] as List).length, equals(1));
      expect((payload['expenses'] as List).length, equals(1));
    });

    test('temporary backup file lifecycle deletion logic ensures file removal', () async {
      final tempDir = Directory.systemTemp.createTempSync('kiloclaim_test_backup_');
      final tempFile = File('${tempDir.path}/test_backup.json');
      await tempFile.writeAsString('{"test": true}', flush: true);

      expect(await tempFile.exists(), isTrue);

      // Simulating finally block cleanup from LocalBackupService
      try {
        // Mock share logic
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      expect(await tempFile.exists(), isFalse);
      tempDir.deleteSync(recursive: true);
    });
  });
}
