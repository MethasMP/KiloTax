import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kilotax/services/tracking/road_snap_routing_service.dart';

void main() {
  group('Live Real-World Australian Road Graph Verification', () {
    test('Richmond VIC to Bunnings Chadstone on Live Australian Asphalt Network', () async {
      final service = RoadSnapRoutingService(client: http.Client());

      // Coordinates: Richmond VIC (-37.8248, 144.9984) to Chadstone VIC (-37.8767, 145.0934)
      final result = await service.calculateRoadDistanceKm(
        startLat: -37.8248,
        startLon: 144.9984,
        endLat: -37.8767,
        endLon: 145.0934,
      );

      print('=== REAL ROAD NETWORK BENCHMARK (RICHMOND -> CHADSTONE) ===');
      print('Road Distance on Asphalt: ${result.roadDistanceKm} km');
      print('Straight-line Air Distance: ${result.straightLineDistanceKm} km');
      print('Additional Tradie Claimable Distance: +${(result.roadDistanceKm - result.straightLineDistanceKm).toStringAsFixed(2)} km');
      print('Winding Ratio (Road vs Straight): ${result.windingFactor.toStringAsFixed(2)}x');

      // The real driving distance is ~12.78 km via M1 Monash Fwy or Princes Hwy
      expect(result.isRoadSnapped, isTrue);
      expect(result.roadDistanceKm, greaterThan(12.0));
      expect(result.roadDistanceKm, lessThan(13.5));
    });
  });
}
