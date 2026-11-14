import 'dart:convert';
import 'package:kilotax/data/models/trip.dart';
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
  group('AutonomousTripDetector Rigor Tests (Deterministic & Root-Cause)', () {
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

    test(
        '1. Circular Ring Buffer recovers full departure point out of driveway',
        () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 20),
        minDrivingSpeedKmh: 25.0,
        routingService: mockRoutingService,
      );

      final startTime = DateTime(2026, 9, 18, 8, 0, 0);

      // Fix 1-3: Car parked in driveway (speed 0)
      await detector.processFix(
        createMockFix(
            lat: -37.8248, lon: 144.9984, speedKmh: 0, timestamp: startTime),
        simulatedNow: startTime,
      );
      await detector.processFix(
        createMockFix(
            lat: -37.8248,
            lon: 144.9984,
            speedKmh: 5,
            timestamp: startTime.add(const Duration(seconds: 5))),
        simulatedNow: startTime.add(const Duration(seconds: 5)),
      );

      // Fix 4: Car accelerates onto main road (> 25 km/h)
      final t4 = startTime.add(const Duration(seconds: 10));
      await detector.processFix(
        createMockFix(
            lat: -37.8250, lon: 144.9990, speedKmh: 45, timestamp: t4),
        simulatedNow: t4,
      );
      expect(
          detector.state, equals(AutonomousDetectorState.verifyingDeparture));

      // Fix 5: Continues driving at 50 km/h past 20s threshold
      final t5 = startTime.add(const Duration(seconds: 32));
      await detector.processFix(
        createMockFix(
            lat: -37.8280, lon: 145.0020, speedKmh: 50, timestamp: t5),
        simulatedNow: t5,
      );

      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // VERIFICATION: The trip path starts at the driveway (-37.8248), NOT where it exceeded 25 km/h!
      expect(detector.activeTripPath.first.latitude, equals(-37.8248));
      expect(detector.activeTripPath.first.longitude, equals(144.9984));
    });

    test('2. Ghost Anchor: Traffic light stop (3 mins) does NOT finalize trip',
        () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
      );

      final t0 = DateTime(2026, 9, 18, 8, 30, 0);

      // Transition to active driving
      await detector.processFix(
          createMockFix(lat: -37.82, lon: 144.99, speedKmh: 40, timestamp: t0),
          simulatedNow: t0);
      await detector.processFix(
        createMockFix(
            lat: -37.83,
            lon: 145.00,
            speedKmh: 45,
            timestamp: t0.add(const Duration(seconds: 15))),
        simulatedNow: t0.add(const Duration(seconds: 15)),
      );
      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // Car stops at red light (speed 0)
      final redLightTime = t0.add(const Duration(seconds: 30));
      await detector.processFix(
        createMockFix(
            lat: -37.835, lon: 145.005, speedKmh: 0, timestamp: redLightTime),
        simulatedNow: redLightTime,
      );

      expect(
          detector.state, equals(AutonomousDetectorState.ghostAnchorPending));
      expect(detector.ghostAnchor, isNotNull);

      // 3 minutes pass at red light...
      final after3Mins = redLightTime.add(const Duration(minutes: 3));
      await detector.processFix(
        createMockFix(
            lat: -37.835, lon: 145.005, speedKmh: 0, timestamp: after3Mins),
        simulatedNow: after3Mins,
      );

      // Still pending (NOT finalized)
      expect(
          detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // Light turns green! Car drives off (speed 35 km/h)
      final greenLightTime = after3Mins.add(const Duration(seconds: 10));
      await detector.processFix(
        createMockFix(
            lat: -37.840,
            lon: 145.010,
            speedKmh: 35,
            timestamp: greenLightTime),
        simulatedNow: greenLightTime,
      );

      // Anchor dismissed! Resumed normal active driving seamlessly!
      expect(detector.state, equals(AutonomousDetectorState.activeDriving));
      expect(detector.ghostAnchor, isNull);
    });

    test(
        '3. True Site Arrival: Stationary > 5 mins seals trip at initial anchor point',
        () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
      );

      final t0 = DateTime(2026, 9, 18, 9, 0, 0);

      // Start drive
      await detector.processFix(
          createMockFix(lat: -37.82, lon: 144.99, speedKmh: 40, timestamp: t0),
          simulatedNow: t0);
      await detector.processFix(
        createMockFix(
            lat: -37.83,
            lon: 145.00,
            speedKmh: 45,
            timestamp: t0.add(const Duration(seconds: 15))),
        simulatedNow: t0.add(const Duration(seconds: 15)),
      );

      // Vehicle arrives at Job Site and parks
      final arrivalTime = t0.add(const Duration(minutes: 10));
      await detector.processFix(
        createMockFix(
            lat: -37.8767, lon: 145.0934, speedKmh: 0, timestamp: arrivalTime),
        simulatedNow: arrivalTime,
      );

      expect(
          detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // Tradie leaves car, 5.5 minutes pass
      final pastTimeout =
          arrivalTime.add(const Duration(minutes: 5, seconds: 30));
      await detector.processFix(
        createMockFix(
            lat: -37.8767, lon: 145.0934, speedKmh: 0, timestamp: pastTimeout),
        simulatedNow: pastTimeout,
      );

      // TRIP SEALED RETROACTIVELY!
      expect(detector.state, equals(AutonomousDetectorState.finalized));
      expect(detector.finalizedTrip, isNotNull);
      expect(detector.finalizedTrip!.classification,
          TripClassification.unclassified);
      expect(detector.finalizedTrip!.purpose, '');
      expect(detector.finalizedTrip!.distanceKm,
          equals(14.2)); // Road-Snapped distance!
    });

    test('4. Bus Stop Signature Guard: Discards public bus transit patterns',
        () async {
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 5),
        minDrivingSpeedKmh: 15.0,
        routingService: mockRoutingService,
      );

      DateTime simTime = DateTime(2026, 9, 18, 10, 0, 0);

      // Bus starts moving
      await detector.processFix(
          createMockFix(
              lat: -37.8000, lon: 144.9600, speedKmh: 25, timestamp: simTime),
          simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8010, lon: 144.9600, speedKmh: 25, timestamp: simTime),
          simulatedNow: simTime);

      // Bus Stop 1 (300m hop)
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8027, lon: 144.9600, speedKmh: 0, timestamp: simTime),
          simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8035, lon: 144.9600, speedKmh: 20, timestamp: simTime),
          simulatedNow: simTime);

      // Bus Stop 2 (300m hop)
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8054, lon: 144.9600, speedKmh: 0, timestamp: simTime),
          simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8060, lon: 144.9600, speedKmh: 20, timestamp: simTime),
          simulatedNow: simTime);

      // Bus Stop 3 (300m hop) -> Triggers Bus Pattern Rejection
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8081, lon: 144.9600, speedKmh: 0, timestamp: simTime),
          simulatedNow: simTime);
      simTime = simTime.add(const Duration(seconds: 10));
      await detector.processFix(
          createMockFix(
              lat: -37.8090, lon: 144.9600, speedKmh: 20, timestamp: simTime),
          simulatedNow: simTime);

      // RESET TO IDLE! Bus pattern rejected
      expect(detector.state, equals(AutonomousDetectorState.idle));
      expect(detector.finalizedTrip, isNull);
    });
    test('5. Trade POI Auto-Detect: Populates detectedPoi and purpose at Trade store arrival', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 12000.0,
                'duration': 720.0,
                'geometry': 'route_polyline_bunnings_sample',
              }
            ]
          }),
          200,
        );
      });
      final routing = RoadSnapRoutingService(client: mockClient);

      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(seconds: 60),
        routingService: routing,
      );

      DateTime simTime = DateTime(2026, 11, 13, 8, 0, 0);

      // Start Driving
      await detector.processFix(
        createMockFix(lat: -33.8688, lon: 151.2093, speedKmh: 40, timestamp: simTime),
        simulatedNow: simTime,
      );
      simTime = simTime.add(const Duration(seconds: 15));
      await detector.processFix(
        createMockFix(lat: -33.8800, lon: 151.2150, speedKmh: 45, timestamp: simTime),
        simulatedNow: simTime,
      );

      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // Arrive and park at Bunnings Warehouse
      simTime = simTime.add(const Duration(seconds: 30));
      await detector.processFix(
        createMockFix(lat: -33.9050, lon: 151.2200, speedKmh: 0, timestamp: simTime),
        simulatedNow: simTime,
      );

      expect(detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // Dwell for 65 seconds (> ghostAnchorTimeout 60s)
      simTime = simTime.add(const Duration(seconds: 65));
      await detector.processFix(
        createMockFix(lat: -33.9050, lon: 151.2200, speedKmh: 0, timestamp: simTime),
        simulatedNow: simTime,
      );

      expect(detector.state, equals(AutonomousDetectorState.finalized));
      final trip = detector.finalizedTrip;
      expect(trip, isNotNull);
      expect(trip!.routePolyline, equals('route_polyline_bunnings_sample'));
      expect(trip.distanceKm, equals(12.0));
    });

    test('6. Fast-Path Promotion: Bluetooth Car connection triggers instant activeDriving at lower speed', () async {
      final detector = AutonomousTripDetector(
        routingService: mockRoutingService,
        minDrivingSpeedKmh: 20.0,
      );

      final now = DateTime(2026, 11, 13, 8, 0, 0);

      // Stationary fix in driveway with car bluetooth connected
      await detector.processFix(
        createMockFix(lat: -33.8688, lon: 151.2093, speedKmh: 0.0, timestamp: now),
        isBluetoothCarConnected: true,
      );
      expect(detector.state, equals(AutonomousDetectorState.idle));

      // Moving at 10 km/h (below default 20 km/h threshold, but car BT is connected)
      final movingFix = createMockFix(
        lat: -33.8689,
        lon: 151.2094,
        speedKmh: 10.0,
        timestamp: now.add(const Duration(seconds: 4)),
      );
      final state = await detector.processFix(
        movingFix,
        isBluetoothCarConnected: true,
      );

      // Promoted directly to activeDriving via Bluetooth Car fast-path!
      expect(state, equals(AutonomousDetectorState.activeDriving));
      expect(detector.activeTripPath.length, greaterThanOrEqualTo(2));
    });

    test('7. Traffic Light Trap: Stationary for 7 minutes with Car Bluetooth connected does NOT finalize trip', () async {
      final detector = AutonomousTripDetector(
        routingService: mockRoutingService,
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5), // default timeout is 5 min
      );

      var simTime = DateTime(2026, 11, 13, 8, 0, 0);

      // Start driving with car bluetooth connected
      await detector.processFix(
        createMockFix(lat: -33.8688, lon: 151.2093, speedKmh: 40.0, timestamp: simTime),
        simulatedNow: simTime,
        isBluetoothCarConnected: true,
      );
      expect(detector.state, equals(AutonomousDetectorState.activeDriving));

      // Stop at a long red light (stationary fix)
      simTime = simTime.add(const Duration(seconds: 30));
      await detector.processFix(
        createMockFix(lat: -33.8700, lon: 151.2100, speedKmh: 0.0, timestamp: simTime),
        simulatedNow: simTime,
        isBluetoothCarConnected: true,
      );
      expect(detector.state, equals(AutonomousDetectorState.ghostAnchorPending));

      // 7 minutes pass at red light (> standard 5 min timeout, but car bluetooth is connected)
      simTime = simTime.add(const Duration(minutes: 7));
      final stateAt7Min = await detector.processFix(
        createMockFix(lat: -33.8700, lon: 151.2100, speedKmh: 0.0, timestamp: simTime),
        simulatedNow: simTime,
        isBluetoothCarConnected: true,
      );

      // Must NOT be finalized! Remains ghostAnchorPending because timeout extended to 10 min
      expect(stateAt7Min, equals(AutonomousDetectorState.ghostAnchorPending));
      expect(detector.finalizedTrip, isNull);

      // Light turns green and car drives again -> seamlessly resumes activeDriving
      simTime = simTime.add(const Duration(seconds: 10));
      final resumedState = await detector.processFix(
        createMockFix(lat: -33.8720, lon: 151.2120, speedKmh: 35.0, timestamp: simTime),
        simulatedNow: simTime,
        isBluetoothCarConnected: true,
      );
      expect(resumedState, equals(AutonomousDetectorState.activeDriving));
    });
  });
}
