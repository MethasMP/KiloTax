import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kiloclaim/data/models/trade_persona.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/services/tracking/autonomous_trip_detector.dart';

void main() {
  group('FLAW-2 & FLAW-7 Fix Verification Tests', () {
    test('FLAW-7: Departure odometer is captured at departure time, not finish time', () async {
      double currentOdo = 50000.0;

      final detector = AutonomousTripDetector(
        odometerProvider: () => currentOdo,
        vehicleIdProvider: () => 'ute_1',
        minDrivingSpeedKmh: 10.0,
      );

      final startTime = DateTime(2026, 11, 17, 8, 0, 0);

      // 1. First departure fix at 50,000 km
      await detector.processFix(
        Position(
          longitude: 144.9631,
          latitude: -37.8136,
          timestamp: startTime,
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 12.0, // > 10 km/h, triggers departure
          speedAccuracy: 0.0,
        ),
        isBluetoothCarConnected: true,
      );

      // Verify it transitioned to active driving
      expect(detector.state, AutonomousDetectorState.activeDriving);

      // 2. Simulate external odometer changes during driving (e.g. user updated state or another call)
      currentOdo = 50250.0;

      // 3. Complete the trip
      final arrivalTime = startTime.add(const Duration(minutes: 20));
      await detector.processFix(
        Position(
          longitude: 144.9700,
          latitude: -37.8200,
          timestamp: arrivalTime,
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      // Ghost anchor arrives
      expect(detector.state, AutonomousDetectorState.ghostAnchorPending);

      // Advance simulated time past ghost timeout
      await detector.processFix(
        Position(
          longitude: 144.9700,
          latitude: -37.8200,
          timestamp: arrivalTime.add(const Duration(minutes: 6)),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        simulatedNow: arrivalTime.add(const Duration(minutes: 6)),
      );

      expect(detector.state, AutonomousDetectorState.finalized);
      final trip = detector.finalizedTrip;
      expect(trip, isNotNull);

      // Crucial test: Start odometer MUST be the 50,000.0 from departure, not the mutated 50,250.0!
      expect(trip!.startOdometer, 50000.0);
    });

    test('FLAW-2: Home to Trade POI requires Bulky Tools to auto-classify as business', () async {
      // Setup user profile at Melbourne CBD home
      const cbdLat = -37.8136;
      const cbdLon = 144.9631;

      // Non-bulky persona: otherSoleTrader
      final nonBulkyProfile = UserProfile(
        homeLatitude: cbdLat,
        homeLongitude: cbdLon,
        homeRadiusMeters: 300.0,
        tradePersona: TradePersona.otherSoleTrader,
      );

      final detector = AutonomousTripDetector(
        userProfileProvider: () => nonBulkyProfile,
        vehicleIdProvider: () => 'car_1',
        odometerProvider: () => 10000.0,
      );

      final startTime = DateTime(2026, 11, 17, 9, 0, 0);

      // Start from Home CBD
      await detector.processFix(
        Position(
          longitude: cbdLon,
          latitude: cbdLat,
          timestamp: startTime,
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 15.0,
          speedAccuracy: 0.0,
        ),
        isBluetoothCarConnected: true,
      );

      // Drive and stop at Bunnings
      final arrivalTime = startTime.add(const Duration(minutes: 15));
      await detector.processFix(
        Position(
          longitude: 145.0000,
          latitude: -37.8200,
          timestamp: arrivalTime,
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );

      await detector.processFix(
        Position(
          longitude: 145.0000,
          latitude: -37.8200,
          timestamp: arrivalTime.add(const Duration(minutes: 6)),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        simulatedNow: arrivalTime.add(const Duration(minutes: 6)),
      );

      expect(detector.state, AutonomousDetectorState.finalized);
      final trip = detector.finalizedTrip;
      expect(trip, isNotNull);
      expect(detector.isOriginHome, isTrue);

      // Since otherSoleTrader does NOT have bulky tools exemption enabled by default,
      // Home -> Work/Store must remain UNCLASSIFIED for human substantiation.
      expect(trip!.classification, TripClassification.unclassified);
    });
  });
}
