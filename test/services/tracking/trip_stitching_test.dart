import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';

Position createMockFix({
  required double lat,
  required double lon,
  required double speedKmh,
  required DateTime timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lon,
    timestamp: timestamp,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    accuracy: 3.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: speedKmh / 3.6,
    speedAccuracy: 0.1,
  );
}

void main() {
  group('Trip Stitching Buffer & Passenger Disambiguation Tests', () {
    test('Stitches consecutive trips starting within 5 minutes into a single unbroken trip', () async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_stitch_test',
        make: 'Toyota',
        model: 'Hilux',
        year: 2024,
        regoPlate: 'STITCH-01',
      );
      appState.addVehicle(vehicle);

      final now = DateTime(2026, 11, 13, 8, 0, 0);

      // First trip recorded
      final trip1 = Trip(
        id: 'trip_1',
        vehicleId: 'v_stitch_test',
        distanceKm: 5.0,
        date: now,
        purpose: 'Site visit leg 1',
        startOdometer: 10000.0,
        endOdometer: 10005.0,
      );
      appState.recordTrip(trip1);
      expect(appState.trips.length, equals(1));
      expect(appState.trips.first.distanceKm, equals(5.0));

      // Simulate trip 2 finalized 3 minutes later (within 5-min coffee stop buffer)
      final trip2 = Trip(
        id: 'trip_2',
        vehicleId: 'v_stitch_test',
        distanceKm: 3.5,
        date: now.add(const Duration(minutes: 3)),
        purpose: 'Site visit leg 2',
        startOdometer: 10005.0,
        endOdometer: 10008.5,
      );

      // Test AppState handleFinalizedAutonomousTrip
      appState.handleFinalizedAutonomousTrip(trip2);

      // Assert stitched result
      expect(appState.trips.length, equals(1)); // Stitched into single trip, no fragmentation!
      expect(appState.trips.first.distanceKm, equals(8.5));
      expect(appState.trips.first.startOdometer, equals(10000.0));
      expect(appState.trips.first.endOdometer, equals(10008.5));
    });

    test('Passenger Disambiguation: Marks trip as isPassengerUnverified when Bluetooth is unlinked', () {
      final tripWithoutBt = Trip(
        id: 'trip_unlinked',
        vehicleId: 'v_test',
        distanceKm: 12.0,
        date: DateTime.now(),
        purpose: 'Drive',
        isPassengerUnverified: true,
      );

      expect(tripWithoutBt.isPassengerUnverified, isTrue);

      final tripWithBt = tripWithoutBt.copyWith(
        isPassengerUnverified: false,
      );
      expect(tripWithBt.isPassengerUnverified, isFalse);
    });
  });
}
