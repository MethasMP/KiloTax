import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/in_flight_trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InFlightTrip Model & Persistence Tests', () {
    test('InFlightTrip serializes and deserializes accurately', () {
      final now = DateTime.now();
      final trip = InFlightTrip(
        id: 'inflight_123',
        vehicleId: 'veh_test_01',
        purpose: 'Client Inspection',
        startedAt: now.subtract(const Duration(minutes: 25)),
        lastUpdatedAt: now,
        distanceKm: 14.85,
        startLatitude: -33.8688,
        startLongitude: 151.2093,
        lastLatitude: -33.8750,
        lastLongitude: 151.2150,
        originAddress: 'Sydney CBD',
        lastAddress: 'Surry Hills Site',
        startOdometer: 85200.0,
      );

      final json = trip.toJson();
      final reconstituted = InFlightTrip.fromJson(json);

      expect(reconstituted.id, 'inflight_123');
      expect(reconstituted.vehicleId, 'veh_test_01');
      expect(reconstituted.distanceKm, 14.85);
      expect(reconstituted.startLatitude, -33.8688);
      expect(reconstituted.originAddress, 'Sydney CBD');
      expect(reconstituted.startOdometer, 85200.0);
    });

    test('LocalStorageService saves, loads, and clears InFlightTrip', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();

      expect(storage.loadInFlightTrip(), isNull);

      final now = DateTime.now();
      final trip = InFlightTrip(
        id: 'inflight_999',
        vehicleId: 'veh_ute',
        purpose: 'Bunnings Run',
        startedAt: now,
        lastUpdatedAt: now,
        distanceKm: 6.2,
        startLatitude: -37.8136,
        startLongitude: 144.9631,
        lastLatitude: -37.8200,
        lastLongitude: 144.9700,
        startOdometer: 42000.0,
      );

      await storage.saveInFlightTrip(trip);
      final loaded = storage.loadInFlightTrip();
      expect(loaded, isNotNull);
      expect(loaded!.id, 'inflight_999');
      expect(loaded.distanceKm, 6.2);

      await storage.clearInFlightTrip();
      expect(storage.loadInFlightTrip(), isNull);
    });
  });

  group('AppState Antifragile Crash/Kill Resurrection Tests', () {
    test('Resurrects orphaned trip upon AppState init and allows 1-tap claim',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();

      // Seed vehicle
      final testVehicle = Vehicle(
        id: 'veh_hilux_01',
        make: 'Toyota',
        model: 'Hilux Work Ute',
        regoPlate: 'VIC-999',
        initialOdometer: 50000.0,
        isPrimary: true,
      );
      await storage.saveVehicles([testVehicle]);

      // Seed an interrupted in-flight trip (Simulating iOS process kill mid-drive)
      final interruptedDrive = InFlightTrip(
        id: 'inflight_killed_drive',
        vehicleId: 'veh_hilux_01',
        purpose: 'Site Visit',
        startedAt: DateTime.now().subtract(const Duration(minutes: 40)),
        lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        distanceKm: 22.4,
        startLatitude: -37.8136,
        startLongitude: 144.9631,
        lastLatitude: -37.8300,
        lastLongitude: 144.9900,
        originAddress: 'Depot',
        startOdometer: 50000.0,
      );
      await storage.saveInFlightTrip(interruptedDrive);

      // App re-boots from clean slate
      final appState = AppState(storageService: storage);
      await appState.init();

      // Verify resurrected state
      expect(appState.orphanedInFlightTrip, isNotNull);
      expect(appState.orphanedInFlightTrip!.id, 'inflight_killed_drive');
      expect(appState.orphanedInFlightTrip!.distanceKm, 22.4);

      // 1-Tap claim: Save to Logbook
      await appState.rescueOrphanedTrip(
        saveToLogbook: true,
        resolvedOrigin: 'Depot Yard',
        resolvedDestination: 'Building Site B',
      );

      // Verify that orphaned trip is cleared from memory and persistent disk
      expect(appState.orphanedInFlightTrip, isNull);
      expect(storage.loadInFlightTrip(), isNull);

      // Verify that the rescued trip has been officially added to the ledger
      final trips = appState.trips;
      expect(trips.any((t) => t.distanceKm == 22.4), isTrue);
      final rescuedTrip = trips.firstWhere((t) => t.distanceKm == 22.4);
      expect(rescuedTrip.evidenceSource, 'rescued_crash_continuity');
      expect(rescuedTrip.originAddress, 'Depot Yard');
      expect(rescuedTrip.destinationAddress, 'Building Site B');
    });

    test('Discards orphaned trip when user chooses to discard', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();

      final falseTrip = InFlightTrip(
        id: 'inflight_accidental',
        vehicleId: 'default_vehicle',
        purpose: 'Personal',
        startedAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        distanceKm: 1.2,
        startLatitude: 0,
        startLongitude: 0,
        lastLatitude: 0,
        lastLongitude: 0,
        startOdometer: 1000.0,
      );
      await storage.saveInFlightTrip(falseTrip);

      final appState = AppState(storageService: storage);
      await appState.init();

      expect(appState.orphanedInFlightTrip, isNotNull);

      await appState.discardOrphanedTrip();

      expect(appState.orphanedInFlightTrip, isNull);
      expect(storage.loadInFlightTrip(), isNull);
      expect(appState.trips.any((t) => t.id.contains('inflight_accidental')),
          isFalse);
    });
  });
}
