import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/services/tracking/autonomous_trip_detector.dart';
import 'package:kiloclaim/services/tracking/road_snap_routing_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _createFix({
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Base Geofencing (TR 2021/1 & ITAA 1997)', () {
    late RoadSnapRoutingService mockRoutingService;

    // Melbourne Home Base Reference Point
    const homeLat = -37.8136;
    const homeLon = 144.9631;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 12500.0, // 12.5 km
                'duration': 720.0,
              }
            ]
          }),
          200,
        );
      });
      mockRoutingService = RoadSnapRoutingService(client: mockClient);
    });

    test('1. Trip starting within 200m of home sets isOriginHome = true via Geolocator.distanceBetween', () async {
      UserProfile userProfile = const UserProfile(
        homeAddress: '123 Collins St, Melbourne VIC',
        homeLatitude: homeLat,
        homeLongitude: homeLon,
        homeRadiusMeters: 200.0,
      );

      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
        userProfileProvider: () => userProfile,
      );

      final startTime = DateTime(2026, 11, 1, 7, 0, 0);

      // Start position: ~50m from home base (within 200m)
      // Lat difference of 0.0004 deg is ~44m
      final startPosLat = homeLat + 0.0004;
      final startPosLon = homeLon;

      // Ensure distance is within 200m
      final dist = Geolocator.distanceBetween(startPosLat, startPosLon, homeLat, homeLon);
      expect(dist, lessThanOrEqualTo(200.0));

      // Idle fixes
      await detector.processFix(
        _createFix(lat: startPosLat, lon: startPosLon, speedKmh: 0, timestamp: startTime),
        simulatedNow: startTime,
      );

      // Drive acceleration
      final t1 = startTime.add(const Duration(seconds: 5));
      await detector.processFix(
        _createFix(lat: startPosLat, lon: startPosLon, speedKmh: 35.0, timestamp: t1),
        simulatedNow: t1,
      );

      final t2 = startTime.add(const Duration(seconds: 16));
      await detector.processFix(
        _createFix(lat: -37.8300, lon: 145.0000, speedKmh: 50.0, timestamp: t2),
        simulatedNow: t2,
      );

      expect(detector.state, AutonomousDetectorState.activeDriving);

      // Arrive at work site (~5km away, far outside home geofence)
      const workLat = -37.8500;
      const workLon = 145.0200;
      final tStop = startTime.add(const Duration(minutes: 15));
      await detector.processFix(
        _createFix(lat: workLat, lon: workLon, speedKmh: 0, timestamp: tStop),
        simulatedNow: tStop,
      );
      expect(detector.state, AutonomousDetectorState.ghostAnchorPending);

      // Finalize trip after stationary timeout
      final tFinal = tStop.add(const Duration(minutes: 6));
      await detector.processFix(
        _createFix(lat: workLat, lon: workLon, speedKmh: 0, timestamp: tFinal),
        simulatedNow: tFinal,
      );

      expect(detector.state, AutonomousDetectorState.finalized);
      expect(detector.isOriginHome, isTrue);
      expect(detector.isDestinationHome, isFalse);
    });

    test('2. Trip ending within 200m of home sets isDestinationHome = true', () async {
      UserProfile userProfile = const UserProfile(
        homeAddress: '123 Collins St, Melbourne VIC',
        homeLatitude: homeLat,
        homeLongitude: homeLon,
        homeRadiusMeters: 200.0,
      );

      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
        userProfileProvider: () => userProfile,
      );

      final startTime = DateTime(2026, 11, 1, 17, 0, 0);

      // Origin: Job site (far from home)
      const jobLat = -37.8600;
      const jobLon = 145.0500;

      await detector.processFix(
        _createFix(lat: jobLat, lon: jobLon, speedKmh: 0, timestamp: startTime),
        simulatedNow: startTime,
      );

      final t1 = startTime.add(const Duration(seconds: 5));
      await detector.processFix(
        _createFix(lat: jobLat, lon: jobLon, speedKmh: 40.0, timestamp: t1),
        simulatedNow: t1,
      );

      final t2 = startTime.add(const Duration(seconds: 16));
      await detector.processFix(
        _createFix(lat: -37.8400, lon: 145.0100, speedKmh: 50.0, timestamp: t2),
        simulatedNow: t2,
      );

      // Destination: 80m from home
      final endLat = homeLat + 0.0006;
      final endLon = homeLon + 0.0004;
      final endDist = Geolocator.distanceBetween(endLat, endLon, homeLat, homeLon);
      expect(endDist, lessThanOrEqualTo(200.0));

      final tStop = startTime.add(const Duration(minutes: 20));
      await detector.processFix(
        _createFix(lat: endLat, lon: endLon, speedKmh: 0, timestamp: tStop),
        simulatedNow: tStop,
      );

      final tFinal = tStop.add(const Duration(minutes: 6));
      await detector.processFix(
        _createFix(lat: endLat, lon: endLon, speedKmh: 0, timestamp: tFinal),
        simulatedNow: tFinal,
      );

      expect(detector.state, AutonomousDetectorState.finalized);
      expect(detector.isOriginHome, isFalse);
      expect(detector.isDestinationHome, isTrue);
    });

    test('3. Non-home trip (>200m) does NOT trigger isOriginHome or isDestinationHome even if address contains no keywords', () async {
      UserProfile userProfile = const UserProfile(
        homeAddress: '123 Collins St, Melbourne VIC',
        homeLatitude: homeLat,
        homeLongitude: homeLon,
        homeRadiusMeters: 200.0,
      );

      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 10),
        minDrivingSpeedKmh: 20.0,
        ghostAnchorTimeout: const Duration(minutes: 5),
        routingService: mockRoutingService,
        userProfileProvider: () => userProfile,
      );

      final startTime = DateTime(2026, 11, 1, 12, 0, 0);

      // Origin: 800m from home (>200m boundary)
      const origLat = -37.8210;
      const origLon = 144.9631;
      expect(Geolocator.distanceBetween(origLat, origLon, homeLat, homeLon), greaterThan(200.0));

      // Destination: 15km from home
      const destLat = -37.9100;
      const destLon = 145.1000;
      expect(Geolocator.distanceBetween(destLat, destLon, homeLat, homeLon), greaterThan(200.0));

      await detector.processFix(
        _createFix(lat: origLat, lon: origLon, speedKmh: 0, timestamp: startTime),
        simulatedNow: startTime,
      );
      final t1 = startTime.add(const Duration(seconds: 5));
      await detector.processFix(
        _createFix(lat: origLat, lon: origLon, speedKmh: 30.0, timestamp: t1),
        simulatedNow: t1,
      );
      final t2 = startTime.add(const Duration(seconds: 16));
      await detector.processFix(
        _createFix(lat: origLat, lon: origLon, speedKmh: 45.0, timestamp: t2),
        simulatedNow: t2,
      );

      final tStop = startTime.add(const Duration(minutes: 25));
      await detector.processFix(
        _createFix(lat: destLat, lon: destLon, speedKmh: 0, timestamp: tStop),
        simulatedNow: tStop,
      );
      final tFinal = tStop.add(const Duration(minutes: 6));
      await detector.processFix(
        _createFix(lat: destLat, lon: destLon, speedKmh: 0, timestamp: tFinal),
        simulatedNow: tFinal,
      );

      expect(detector.state, AutonomousDetectorState.finalized);
      expect(detector.isOriginHome, isFalse);
      expect(detector.isDestinationHome, isFalse);
    });

    test('4. AppState.isPositionHome accurately evaluates coordinates against UserProfile geofence', () async {
      final appState = AppState();
      await appState.setHomeBase(
        latitude: homeLat,
        longitude: homeLon,
        address: '123 Collins St, Melbourne VIC',
        radiusMeters: 200.0,
      );

      // Within 200m (e.g. 100m away)
      expect(appState.isPositionHome(homeLat + 0.0008, homeLon), isTrue);

      // Outside 200m (e.g. 500m away)
      expect(appState.isPositionHome(homeLat + 0.005, homeLon), isFalse);
    });

    test('5. AppState.validateHomeToWorkCompliance enforces TR 2021/1 via coordinate geofence', () async {
      final appState = AppState();
      await appState.setHomeBase(
        latitude: homeLat,
        longitude: homeLon,
        address: '123 Collins St, Melbourne VIC',
      );

      // Origin inside home geofence without bulky tools -> non-compliant commute warning
      final (nonCompliant, warning) = appState.validateHomeToWorkCompliance(
        origin: '74 Industrial Ave', // Address text does NOT contain 'home', but GPS matches home base!
        destination: 'Work Site 9',
        purpose: 'Job Site',
        isBulkyToolsCarried: false,
        originLat: homeLat + 0.0005, // Inside 200m geofence
        originLon: homeLon,
      );

      expect(nonCompliant, isFalse);
      expect(warning, contains('heavy trade tools'));

      // Origin inside home geofence WITH bulky tools -> compliant claim
      final (compliant, compliantWarning) = appState.validateHomeToWorkCompliance(
        origin: '74 Industrial Ave',
        destination: 'Work Site 9',
        purpose: 'Job Site (Bulky Tools Carried)',
        isBulkyToolsCarried: true,
        originLat: homeLat + 0.0005,
        originLon: homeLon,
      );

      expect(compliant, isTrue);
      expect(compliantWarning, isNull);
    });
  });
}
