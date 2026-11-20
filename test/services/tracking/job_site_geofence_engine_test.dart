import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/job_site.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/tracking/job_site_geofence_engine.dart';

void main() {
  group('JobSiteGeofenceEngine Tests (POI & Geofencing Engine)', () {
    final now = DateTime(2026, 11, 8, 8, 30);

    final barangarooSite = JobSite(
      id: 'site_barangaroo',
      name: 'Barangaroo Tower B',
      clientName: 'Lendlease Commercial',
      projectCode: 'LL-BAR-02',
      address: '200 Barangaroo Ave, Sydney NSW 2000',
      latitude: -33.8640,
      longitude: 151.2010,
      radiusMeters: 150.0,
    );

    final parramattaSite = JobSite(
      id: 'site_parramatta',
      name: 'Parramatta Square',
      clientName: 'Walker Corporation',
      projectCode: 'WC-PSQ-01',
      address: '6 Parramatta Square, Parramatta NSW 2150',
      latitude: -33.8160,
      longitude: 151.0040,
      radiusMeters: 200.0,
    );

    final jobSites = [barangarooSite, parramattaSite];

    test('Associates trip destination when within 150m geofence radius', () {
      final trip = Trip(
        id: 'trip_101',
        vehicleId: 'veh_ute_1',
        date: now,
        distanceKm: 15.0,
        purpose: '',
      );

      // Destination coordinate is ~45m from Barangaroo Tower (-33.8643, 151.2012)
      final enriched = JobSiteGeofenceEngine.enrichTripWithJobSite(
        trip: trip,
        jobSites: jobSites,
        startLatitude: -33.8800,
        startLongitude: 151.2100,
        endLatitude: -33.8643,
        endLongitude: 151.2012,
      );

      expect(enriched.jobReference, contains('Barangaroo Tower B (Lendlease Commercial)'));
      expect(enriched.jobReference, contains('[Ref: LL-BAR-02]'));
      expect(enriched.purpose, equals('Client Visit: Lendlease Commercial at Barangaroo Tower B'));
      expect(enriched.destinationAddress, equals('200 Barangaroo Ave, Sydney NSW 2000'));
    });

    test('Associates trip origin when trip starts within known JobSite', () {
      final trip = Trip(
        id: 'trip_102',
        vehicleId: 'veh_ute_1',
        date: now,
        distanceKm: 22.0,
        purpose: '',
      );

      // Origin coordinate is inside Parramatta Square (~80m away)
      final enriched = JobSiteGeofenceEngine.enrichTripWithJobSite(
        trip: trip,
        jobSites: jobSites,
        startLatitude: -33.8165,
        startLongitude: 151.0045,
        endLatitude: -33.9000,
        endLongitude: 151.1000,
      );

      expect(enriched.jobReference, contains('Parramatta Square (Walker Corporation)'));
      expect(enriched.originAddress, equals('6 Parramatta Square, Parramatta NSW 2150'));
    });

    test('Does not associate trip when coordinates exceed geofence radius (>150m)', () {
      final trip = Trip(
        id: 'trip_outside',
        vehicleId: 'veh_ute_1',
        date: now,
        distanceKm: 5.0,
        purpose: 'Personal Errands',
      );

      // Coordinates ~1.5 km away from Barangaroo
      final result = JobSiteGeofenceEngine.enrichTripWithJobSite(
        trip: trip,
        jobSites: jobSites,
        startLatitude: -33.8800,
        startLongitude: 151.2100,
        endLatitude: -33.8500,
        endLongitude: 151.2100,
      );

      expect(result.jobReference, isNull);
      expect(result.purpose, equals('Personal Errands'));
    });

    test('Preserves existing user-entered purpose and jobReference without overwriting', () {
      final trip = Trip(
        id: 'trip_existing',
        vehicleId: 'veh_ute_1',
        date: now,
        distanceKm: 12.0,
        purpose: 'Custom Urgent Electrical Fault Rectification',
        jobReference: 'INV-999-URGENT',
      );

      final enriched = JobSiteGeofenceEngine.enrichTripWithJobSite(
        trip: trip,
        jobSites: jobSites,
        endLatitude: -33.8643,
        endLongitude: 151.2012,
      );

      expect(enriched.jobReference, equals('INV-999-URGENT'));
      expect(enriched.purpose, equals('Custom Urgent Electrical Fault Rectification'));
    });

    Trip makeTripWithDwell({required double lat, required double lng, required int seconds}) {
      return Trip(
        id: 'trip_dwell_test',
        vehicleId: 'veh_test_1',
        date: DateTime(2026, 11, 20, 10, 0),
        purpose: '',
        endLat: lat,
        endLng: lng,
        stoppedDuration: seconds,
        stoppedAt: DateTime(2026, 11, 20, 10, 30),
      );
    }

    test('tags trip when dwell ≥ 120s inside geofence', () {
      final engine = JobSiteGeofenceEngine();
      final trip = makeTripWithDwell(lat: -33.865, lng: 151.209, seconds: 180);
      final site = JobSite(lat: -33.865, lng: 151.209, radiusMeters: 150);
      expect(engine.matchTripToJobSite(trip, [site])?.confidenceScore, greaterThan(0.0));
    });

    test('does NOT tag trip when dwell < 120s', () {
      final engine = JobSiteGeofenceEngine();
      final trip = makeTripWithDwell(lat: -33.865, lng: 151.209, seconds: 90);
      final site = JobSite(lat: -33.865, lng: 151.209, radiusMeters: 150);
      expect(engine.matchTripToJobSite(trip, [site]), isNull);
    });
  });
}
