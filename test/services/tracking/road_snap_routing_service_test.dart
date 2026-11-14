import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/tracking/road_snap_routing_service.dart';

void main() {
  group('RoadSnapRoutingService & Polyline Tests', () {
    test('successfully extracts snapped distance and geometryPolyline from OSRM response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['overview'], 'full');
        expect(request.url.queryParameters['geometries'], 'polyline');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 14250.0,
                'duration': 900.0,
                'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
              }
            ]
          }),
          200,
        );
      });

      final service = RoadSnapRoutingService(client: mockClient);
      final result = await service.calculateRoadDistanceKm(
        startLat: -33.8688,
        startLon: 151.2093,
        endLat: -33.9173,
        endLon: 151.2313,
      );

      expect(result.isRoadSnapped, isTrue);
      expect(result.roadDistanceKm, 14.25);
      expect(result.durationSeconds, 900.0);
      expect(result.geometryPolyline, '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(result.windingFactor, greaterThan(1.0));
    });

    test('falls back gracefully to geodesic straight line if network or OSRM times out', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable / remote bushland');
      });

      final service = RoadSnapRoutingService(client: mockClient);
      final result = await service.calculateRoadDistanceKm(
        startLat: -33.8688,
        startLon: 151.2093,
        endLat: -33.9173,
        endLon: 151.2313,
      );

      expect(result.isRoadSnapped, isFalse);
      expect(result.roadDistanceKm, greaterThan(5.0));
      expect(result.geometryPolyline, isNull);
    });
  });
}
