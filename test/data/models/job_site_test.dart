import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/job_site.dart';

void main() {
  group('JobSite POI Entity Invariants & Geodesic Boundaries', () {
    final now = DateTime.now();

    test('validates correct latitude, longitude, and radius boundaries', () {
      final jobSite = JobSite(
        id: 'site_101',
        userId: 'user_456',
        name: 'Barangaroo Tower Site',
        clientName: 'Lendlease Commercial',
        projectCode: 'LL-BAR-2026',
        address: '100 Barangaroo Ave, Barangaroo NSW 2000',
        latitude: -33.8642,
        longitude: 151.2015,
        radiusMeters: 200.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(jobSite.name, equals('Barangaroo Tower Site'));
      expect(jobSite.clientName, equals('Lendlease Commercial'));
      expect(jobSite.projectCode, equals('LL-BAR-2026'));
      expect(jobSite.radiusMeters, equals(200.0));
      expect(jobSite.isActive, isTrue);
    });

    test('enforces coordinate and radius bounds with assertions', () {
      // Invalid Latitude > 90
      expect(
        () => JobSite(
          id: 'site_bad_lat',
          userId: 'user_1',
          name: 'Bad Lat',
          clientName: 'Test',
          address: 'Test',
          latitude: 95.0,
          longitude: 151.0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );

      // Invalid Longitude < -180
      expect(
        () => JobSite(
          id: 'site_bad_lng',
          userId: 'user_1',
          name: 'Bad Lng',
          clientName: 'Test',
          address: 'Test',
          latitude: -33.0,
          longitude: -185.0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );

      // Invalid Radius < 10m
      expect(
        () => JobSite(
          id: 'site_bad_radius',
          userId: 'user_1',
          name: 'Bad Radius',
          clientName: 'Test',
          address: 'Test',
          latitude: -33.0,
          longitude: 151.0,
          radiusMeters: 5.0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );

      // Invalid Radius > 5,000m
      expect(
        () => JobSite(
          id: 'site_huge_radius',
          userId: 'user_1',
          name: 'Huge Radius',
          clientName: 'Test',
          address: 'Test',
          latitude: -33.0,
          longitude: 151.0,
          radiusMeters: 6000.0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('geodesic containment correctly identifies points within geofence', () {
      // Sydney Town Hall (-33.8732, 151.2069)
      final townHallSite = JobSite(
        id: 'site_town_hall',
        userId: 'user_1',
        name: 'Town Hall Station Renovation',
        clientName: 'Transport for NSW',
        projectCode: 'TNSW-TH-01',
        address: '483 George St, Sydney NSW 2000',
        latitude: -33.8732,
        longitude: 151.2069,
        radiusMeters: 150.0, // 150m radius
        createdAt: now,
        updatedAt: now,
      );

      // Point ~50m away (Queen Victoria Building nearby: -33.8720, 151.2068)
      final inside = townHallSite.containsCoordinate(
        lat: -33.8728,
        lng: 151.2069,
      );
      expect(inside, isTrue);

      // Point ~1.2 km away (Circular Quay: -33.8612, 151.2108)
      final outside = townHallSite.containsCoordinate(
        lat: -33.8612,
        lng: 151.2108,
      );
      expect(outside, isFalse);
    });

    test('JSON serialization & deserialization round-trip maintains integrity', () {
      final original = JobSite(
        id: 'site_202',
        userId: 'usr_789',
        name: 'Parramatta Light Rail Depot',
        clientName: 'Metro Infrastructure',
        projectCode: 'PLR-D04',
        address: '150 Church St, Parramatta NSW 2150',
        latitude: -33.8150,
        longitude: 151.0011,
        radiusMeters: 350.0,
        isActive: true,
        createdAt: DateTime(2026, 11, 8, 10, 0),
        updatedAt: DateTime(2026, 11, 8, 12, 30),
      );

      final json = original.toJson();
      final revived = JobSite.fromJson(json);

      expect(revived.id, equals(original.id));
      expect(revived.userId, equals(original.userId));
      expect(revived.name, equals(original.name));
      expect(revived.clientName, equals(original.clientName));
      expect(revived.projectCode, equals(original.projectCode));
      expect(revived.address, equals(original.address));
      expect(revived.latitude, equals(original.latitude));
      expect(revived.longitude, equals(original.longitude));
      expect(revived.radiusMeters, equals(original.radiusMeters));
      expect(revived.isActive, equals(original.isActive));
    });
  });
}
