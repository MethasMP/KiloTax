import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/tracking/sensor_fusion_tracking_engine.dart';

void main() {
  group('FLAW-6 & FLAW-8 Fix Verification Tests', () {
    test('FLAW-6: First departure movement after long stationary red-light does NOT get discarded by velocity jump filter', () {
      final engine = SensorFusionTrackingEngine();
      final startTime = DateTime(2026, 11, 17, 10, 0, 0);

      // 1. Initial stop at red light (Melbourne Lat/Lon)
      const lat0 = -37.8136;
      const lon0 = 144.9631;

      final fix0 = Position(
        latitude: lat0,
        longitude: lon0,
        timestamp: startTime,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      engine.processFix(fix0);

      // 2. Stationary for 3 minutes (180 seconds)
      final fixWait = Position(
        latitude: lat0,
        longitude: lon0,
        timestamp: startTime.add(const Duration(minutes: 3)),
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final updateWait = engine.processFix(fixWait);
      expect(updateWait.isStationary, isTrue);
      expect(updateWait.distanceDeltaKm, 0.0);

      // 3. Light turns green! Vehicle accelerates: moves 25 meters in 2 seconds (45 km/h)
      // Lat delta ~ 25 meters (~0.000225 deg lat)
      final fixMove = Position(
        latitude: lat0 + 0.000225,
        longitude: lon0,
        timestamp: startTime.add(const Duration(minutes: 3, seconds: 2)),
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        accuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 12.5, // 45 km/h
        speedAccuracy: 0.0,
      );

      final updateMove = engine.processFix(fixMove);

      // Critical Assertion: The first departure fix MUST NOT be discarded as an anomalous jump!
      expect(updateMove.isAnomalousJumpDiscarded, isFalse);
      expect(updateMove.isStationary, isFalse);
      expect(updateMove.distanceDeltaKm, greaterThan(0.02)); // ~0.025 km
    });

    test('FLAW-8: Manual trip with startOdometer = 0.0 does NOT create a phantom 100k+ gap', () {
      const vehicleId = 'ute_main';
      const baseline = 100000.0;

      final trips = [
        // A manual trip entered without odometer (defaults to 0.0)
        Trip(
          id: 'manual_trip_1',
          vehicleId: vehicleId,
          distanceKm: 15.0,
          date: DateTime(2026, 11, 10),
          purpose: 'Emergency plumbing call',
          startOdometer: 0.0,
          endOdometer: 0.0, // or 15.0
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
        // Normal logbook trips around 100k km
        Trip(
          id: 'auto_trip_1',
          vehicleId: vehicleId,
          distanceKm: 20.0,
          date: DateTime(2026, 11, 11),
          purpose: 'Site visit',
          startOdometer: 100000.0,
          endOdometer: 100020.0,
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
        Trip(
          id: 'auto_trip_2',
          vehicleId: vehicleId,
          distanceKm: 30.0,
          date: DateTime(2026, 11, 12),
          purpose: 'Site visit 2',
          startOdometer: 100020.0,
          endOdometer: 100050.0,
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final gaps = OdometerGapReconciler.findGaps(
        vehicleId: vehicleId,
        baseline: baseline,
        trips: trips,
      );

      // Verify no phantom gap of 100,000 km is created!
      expect(gaps.isEmpty, isTrue);
    });
  });
}
