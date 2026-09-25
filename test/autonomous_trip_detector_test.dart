import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/tracking/autonomous_trip_detector.dart';
import 'package:kilotax/services/tracking/road_snap_routing_service.dart';

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
  group('AutonomousTripDetector Rigor Tests (Monozukuri & Root-Cause)', () {
    late RoadSnapRoutingService mockRoutingService;

    setUp(() {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 14200.0, // 14.2 km
                'duration': 900.0,
              }
            ]
          }),
          200,
        );
      });
      mockRoutingService = RoadSnapRoutingService(client: mockClient);
    });

    test('1. Circular Ring Buffer recovers full departure point out of driveway', () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 20),
        minDrivingSpeedKmh: 25.0,
        routingService: mockRoutingService,
      );

      final startTime = DateTime(2026, 9, 18, 8, 0, 0);

      // Fix 1-3: Car parked in driveway (speed 0)
      await detector.processFix(
        createMockFix(lat: -37.8248, lon: 144.9984, speedKmh: 0, timestamp: startTime),
        simulatedNow: startTime,
      );
      await detector.processFix(
        createMockFix(lat: -37.8248, lon: 144.9984, speedKmh: 5, timestamp: startTime.add(const Duration(seconds: 5))),
        simulatedNow: startTime.add(const Duration(seconds: 5)),
      );

      // Fix 4: Car accelerates onto main road (> 25 km/h)
      final t4 = startTime.add(const Duration(seconds: 10));
      await detector.processFix(
        createMockFix(lat: -37.8250, lon: 144.9990, speedKmh: 45, timestamp: t4),
        simulatedNow: t4,
      );
      expect(detector.state, equals(AutonomousDetectorState.verifyingDeparture));

      // Fix 5: Continues driving at 50 km/h past 20s threshold
      final t5 = startTime.add(const Duration(seconds: 32));
      await detector.processFix(
        createMockFix(lat: -37.8280, lon: 145.0020, speedKmh: 50, timestamp: t5),
        simulatedNow: t5,
      );

      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // VERIFICATION: The trip path starts at the driveway (-37.8248), NOT where it exceeded 25 km/h!
      expect(detector.activeTripPath.first.latitude, equals(-37.8248));
      expect(detector.activeTripPath.first.longitude, equals(144.9984));
    });

    test('2. Ghost Anchor: Traffic light stop (3 mins) does NOT finalize trip', () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
      );

      final t0 = DateTime(2026, 9, 18, 8, 30, 0);

      // Transition to active driving
      await detector.processFix(createMockFix(lat: -37.82, lon: 144.99, speedKmh: 40, timestamp: t0), simulatedNow: t0);
      await detector.processFix(
        createMockFix(lat: -37.83, lon: 145.00, speedKmh: 45, timestamp: t0.add(const Duration(seconds: 15))),
        simulatedNow: t0.add(const Duration(seconds: 15)),
      );
      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // Car stops at red light (speed 0)
      final redLightTime = t0.add(const Duration(seconds: 30));
      await detector.processFix(
        createMockFix(lat: -37.835, lon: 145.005, speedKmh: 0, timestamp: redLightTime),
        simulatedNow: redLightTime,
      );

      expect(detector.state, equals(AutonomousDetectorState.ghostAnchorPending));
      expect(detector.ghostAnchor, isNotNull);

      // 3 minutes pass at red light...
      final after3Mins = redLightTime.add(const Duration(minutes: 3));
      await detector.processFix(
        createMockFix(lat: -37.835, lon: 145.005, speedKmh: 0, timestamp: after3Mins),
        simulatedNow: after3Mins,
      );

      // Still pending (NOT finalized)
      expect(detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // Light turns green! Car drives off (speed 35 km/h)
      final greenLightTime = after3Mins.add(const Duration(seconds: 10));
      await detector.processFix(
        createMockFix(lat: -37.840, lon: 145.010, speedKmh: 35, timestamp: greenLightTime),
        simulatedNow: greenLightTime,
      );

      // Anchor dismissed! Resumed normal active driving seamlessly!
      expect(detector.state, equals(AutonomousDetectorState.activeDriving));
      expect(detector.ghostAnchor, isNull);
    });

    test('3. True Site Arrival: Stationary > 5 mins seals trip at initial anchor point', () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
      );

      final t0 = DateTime(2026, 9, 18, 9, 0, 0);

      // Start drive
      await detector.processFix(createMockFix(lat: -37.82, lon: 144.99, speedKmh: 40, timestamp: t0), simulatedNow: t0);
      await detector.processFix(
        createMockFix(lat: -37.83, lon: 145.00, speedKmh: 45, timestamp: t0.add(const Duration(seconds: 15))),
        simulatedNow: t0.add(const Duration(seconds: 15)),
      );

      // Vehicle arrives at Job Site and parks
      final arrivalTime = t0.add(const Duration(minutes: 10));
      await detector.processFix(
        createMockFix(lat: -37.8767, lon: 145.0934, speedKmh: 0, timestamp: arrivalTime),
        simulatedNow: arrivalTime,
      );

      expect(detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // Tradie leaves car, 5.5 minutes pass
      final pastTimeout = arrivalTime.add(const Duration(minutes: 5, seconds: 30));
      await detector.processFix(
        createMockFix(lat: -37.8767, lon: 145.0934, speedKmh: 0, timestamp: pastTimeout),
        simulatedNow: pastTimeout,
      );

      // TRIP SEALED RETROACTIVELY!
      expect(detector.state, equals(AutonomousDetectorState.finalized));
      expect(detector.finalizedTrip, isNotNull);
      expect(detector.finalizedTrip!.distanceKm, equals(14.2)); // Road-Snapped distance!
    });

    test('4. Bus Stop Signature Guard: Discards public bus transit patterns', () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 5),
        minDrivingSpeedKmh: 15.0,
        routingService: mockRoutingService,
      );

      DateTime simTime = DateTime(2026, 9, 18, 10, 0, 0);

      // Bus starts moving
      await detector.processFix(createMockFix(lat: -37.8000, lon: 144.9600, speedKmh: 25, timestamp: simTime), simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8010, lon: 144.9600, speedKmh: 25, timestamp: simTime), simulatedNow: simTime);

      // Bus Stop 1 (300m hop)
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8027, lon: 144.9600, speedKmh: 0, timestamp: simTime), simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8035, lon: 144.9600, speedKmh: 20, timestamp: simTime), simulatedNow: simTime);

      // Bus Stop 2 (300m hop)
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8054, lon: 144.9600, speedKmh: 0, timestamp: simTime), simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8060, lon: 144.9600, speedKmh: 20, timestamp: simTime), simulatedNow: simTime);

      // Bus Stop 3 (300m hop) -> Triggers Bus Pattern Rejection
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8081, lon: 144.9600, speedKmh: 0, timestamp: simTime), simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(createMockFix(lat: -37.8090, lon: 144.9600, speedKmh: 20, timestamp: simTime), simulatedNow: simTime);

      // RESET TO IDLE! Bus pattern rejected
      expect(detector.state, equals(AutonomousDetectorState.idle));
      expect(detector.finalizedTrip, isNull);
    });
  });
}
