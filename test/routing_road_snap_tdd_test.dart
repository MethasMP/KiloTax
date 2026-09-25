import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/tracking/road_snap_routing_service.dart';

void main() {
  group('TDD Phase 2 (RED): Road Snap Routing Service Tests', () {
    test('Richmond to Chadstone calculates exact road driving distance (12.78 km)', () async {
      // Mock OSRM Driving Road Graph response
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 12781.1, // 12.781 km on asphalt
                'duration': 855.9,
              }
            ]
          }),
          200,
        );
      });

      final service = RoadSnapRoutingService(client: mockClient);

      final routeResult = await service.calculateRoadDistanceKm(
        startLat: -37.8248,
        startLon: 144.9984,
        endLat: -37.8767,
        endLon: 145.0934,
      );

      print('ROAD-SNAP DRIVING DISTANCE: ${routeResult.roadDistanceKm} km');
      print('STRAIGHT-LINE CHORD DISTANCE: ${routeResult.straightLineDistanceKm} km');
      print('ROAD NETWORK WINDING RATIO (DETOUR FACTOR): ${routeResult.windingFactor.toStringAsFixed(2)}x');

      // The real driving distance is ~12.78 km, whereas straight line is ~10.05 km
      expect(routeResult.roadDistanceKm, closeTo(12.78, 0.05));
      expect(routeResult.straightLineDistanceKm, closeTo(10.05, 0.1));
      expect(routeResult.windingFactor, greaterThan(1.2)); // Real roads are at least 20-27% longer than straight lines!
    });

    test('Graceful fallback to Geodesic Straight line if device is completely offline', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Network timeout', 504);
      });

      final service = RoadSnapRoutingService(client: mockClient);

      final routeResult = await service.calculateRoadDistanceKm(
        startLat: -37.8248,
        startLon: 144.9984,
        endLat: -37.8767,
        endLon: 145.0934,
      );

      print('OFFLINE FALLBACK DISTANCE: ${routeResult.roadDistanceKm} km');
      expect(routeResult.isRoadSnapped, isFalse);
      expect(routeResult.roadDistanceKm, closeTo(10.05, 0.1));
    });
  });
}
