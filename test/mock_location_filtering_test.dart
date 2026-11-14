import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilotax/services/tracking/autonomous_trip_detector.dart';
import 'package:kilotax/services/tracking/sensor_fusion_tracking_engine.dart';

Position createTestPosition({
  required double latitude,
  required double longitude,
  double speed = 15.0,
  bool isMocked = false,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 1.0,
    isMocked: isMocked,
  );
}

void main() {
  group('PR-15: Mock Location Filtering in Tracking Engines', () {
    test('SensorFusionTrackingEngine discards fixes where isMocked is true', () {
      final engine = SensorFusionTrackingEngine();

      final authenticFix = createTestPosition(
        latitude: -37.8136,
        longitude: 144.9631,
        speed: 10.0,
        isMocked: false,
      );

      final update1 = engine.processFix(authenticFix, allowMockLocations: false);
      expect(update1.isAnomalousJumpDiscarded, isFalse);

      final mockedFix = createTestPosition(
        latitude: -37.8150,
        longitude: 144.9650,
        speed: 15.0,
        isMocked: true,
      );

      // In production / non-debug mode (or when allowMockLocations is false)
      final update2 = engine.processFix(mockedFix, allowMockLocations: false);
      // Since it's mocked, distanceDelta should be 0.0 and flagged
      expect(update2.distanceDeltaKm, equals(0.0));
    });

    test('AutonomousTripDetector ignores mocked fixes and does not start driving state', () async {
      final detector = AutonomousTripDetector();
      expect(detector.state, equals(AutonomousDetectorState.idle));

      final mockSpeedFix = createTestPosition(
        latitude: -37.8136,
        longitude: 144.9631,
        speed: 25.0, // Exceeds 20 km/h threshold
        isMocked: true,
      );

      final state = await detector.processFix(
        mockSpeedFix,
        allowMockLocations: false,
      );

      // Remains idle because mock fix is ignored
      expect(state, equals(AutonomousDetectorState.idle));
    });

    test('Authentic fixes advance AutonomousTripDetector state normally', () async {
      final detector = AutonomousTripDetector();
      expect(detector.state, equals(AutonomousDetectorState.idle));

      final realSpeedFix = createTestPosition(
        latitude: -37.8136,
        longitude: 144.9631,
        speed: 25.0,
        isMocked: false,
      );

      final state = await detector.processFix(
        realSpeedFix,
        allowMockLocations: false,
      );

      expect(state, equals(AutonomousDetectorState.verifyingDeparture));
    });
  });
}
