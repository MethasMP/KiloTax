import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  group('Odometer Photo Integrity & Anti-Fraud Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      final vehicle = Vehicle(
        id: 'test_veh',
        make: 'Toyota',
        model: 'HiAce',
        regoPlate: 'TRADIE-1',
        initialOdometer: 80000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(vehicle);
    });

    test('Saves Day 1 start odometer photo with hash and verified timestamp', () async {
      final captureTime = DateTime(2026, 7, 1, 8, 30);
      final (success, error) = await appState.saveOdometerPhotoWithIntegrity(
        isStart: true,
        photoPath: '/photos/day1_odo.jpg',
        imageHash: 'hash_day1_abc123',
        captureDate: captureTime,
      );

      expect(success, true);
      expect(error, isNull);
      expect(appState.primaryVehicle?.startOdometerPhotoPath, '/photos/day1_odo.jpg');
      expect(appState.primaryVehicle?.startOdometerImageHash, 'hash_day1_abc123');
      expect(appState.primaryVehicle?.startOdometerVerifiedAt, captureTime);
    });

    test('Rejects reusing identical photo hash for Day 84 (anti-fraud duplicate prevention)', () async {
      final day1Time = DateTime(2026, 7, 1, 8, 30);
      // Save Day 1
      await appState.saveOdometerPhotoWithIntegrity(
        isStart: true,
        photoPath: '/photos/day1_odo.jpg',
        imageHash: 'duplicate_hash_999',
        captureDate: day1Time,
      );

      // Attempt to reuse same image hash for Day 84
      final day84Time = DateTime(2026, 9, 23, 17, 0);
      final (success, error) = await appState.saveOdometerPhotoWithIntegrity(
        isStart: false,
        photoPath: '/photos/fake_day84.jpg',
        imageHash: 'duplicate_hash_999', // Identical hash
        captureDate: day84Time,
      );

      expect(success, false);
      expect(error, contains('already used'));
      expect(appState.primaryVehicle?.endOdometerPhotoPath, isNull);
    });

    test('Accepts distinct photo hash for Day 84 finish odometer', () async {
      await appState.saveOdometerPhotoWithIntegrity(
        isStart: true,
        photoPath: '/photos/day1_odo.jpg',
        imageHash: 'hash_day1_aaa',
        captureDate: DateTime(2026, 7, 1),
      );

      final (success, error) = await appState.saveOdometerPhotoWithIntegrity(
        isStart: false,
        photoPath: '/photos/day84_odo.jpg',
        imageHash: 'hash_day84_bbb',
        captureDate: DateTime(2026, 9, 23),
      );

      expect(success, true);
      expect(error, isNull);
      expect(appState.primaryVehicle?.endOdometerPhotoPath, '/photos/day84_odo.jpg');
      expect(appState.primaryVehicle?.endOdometerImageHash, 'hash_day84_bbb');
    });

    test('Home-to-work compliance validator produces unambiguous bulky equipment warning', () {
      final (compliant, warning) = appState.validateHomeToWorkCompliance(
        origin: 'Home - 12 Elm Street',
        destination: 'Commercial Job Site',
        purpose: 'Client / Job',
        isBulkyToolsCarried: false,
      );

      expect(compliant, false);
      expect(warning, contains('heavy or bulky equipment'));
    });
  });
}
