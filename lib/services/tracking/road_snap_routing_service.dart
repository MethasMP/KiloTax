import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'wgs84_geodesic_engine.dart';

class RoadRouteResult {
  final double roadDistanceKm;
  final double straightLineDistanceKm;
  final bool isRoadSnapped;
  final double durationSeconds;

  const RoadRouteResult({
    required this.roadDistanceKm,
    required this.straightLineDistanceKm,
    required this.isRoadSnapped,
    required this.durationSeconds,
  });

  /// Winding factor (Detour Ratio): Real Road Distance / Straight Line Distance
  /// Typically 1.20 to 1.35 in Australian metropolitan road grids.
  double get windingFactor =>
      straightLineDistanceKm > 0 ? (roadDistanceKm / straightLineDistanceKm) : 1.0;
}

/// Australian Road-Snap Routing Service (Graph-Theory Dijkstra / OSRM Backend)
/// Snaps start and end coordinates onto the official road graph (OpenStreetMap / OSRM)
/// to calculate exact driving kilometres on asphalt instead of linear chords cutting through buildings.
class RoadSnapRoutingService {
  final http.Client _client;

  RoadSnapRoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculates exact driving road distance between two coordinates.
  /// Falls back gracefully to WGS-84 Geodesic ellipsoidal straight-line if offline.
  Future<RoadRouteResult> calculateRoadDistanceKm({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    // 1. Calculate WGS-84 Geodesic straight-line baseline
    final straightMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: startLat,
      lon1: startLon,
      lat2: endLat,
      lon2: endLon,
    );
    final straightKm = straightMeters / 1000.0;

    // 2. Query OSRM Graph-Theory Road Network
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?overview=false',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'KiloTax-Australia-Logbook-Engine/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] != null) {
          final routes = data['routes'] as List<dynamic>;
          if (routes.isNotEmpty) {
            final bestRoute = routes.first as Map<String, dynamic>;
            final roadMeters = (bestRoute['distance'] as num).toDouble();
            final durationSec = (bestRoute['duration'] as num?)?.toDouble() ?? 0.0;

            final roadKm = double.parse((roadMeters / 1000.0).toStringAsFixed(2));

            return RoadRouteResult(
              roadDistanceKm: roadKm,
              straightLineDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
              isRoadSnapped: true,
              durationSeconds: durationSec,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[RoadSnapRoutingService] Offline fallback engaged: $e');
    }

    // 3. Fallback to WGS-84 Straight-line when offline
    return RoadRouteResult(
      roadDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
      straightLineDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
      isRoadSnapped: false,
      durationSeconds: 0.0,
    );
  }
}
