import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'wgs84_geodesic_engine.dart';

class RoadRouteResult {
  final double roadDistanceKm;
  final double straightLineDistanceKm;
  final bool isRoadSnapped;
  final double durationSeconds;
  final String? geometryPolyline;

  const RoadRouteResult({
    required this.roadDistanceKm,
    required this.straightLineDistanceKm,
    required this.isRoadSnapped,
    required this.durationSeconds,
    this.geometryPolyline,
  });

  /// Winding factor (Detour Ratio): Real Road Distance / Straight Line Distance
  /// Typically 1.20 to 1.35 in Australian metropolitan road grids.
  double get windingFactor => straightLineDistanceKm > 0
      ? (roadDistanceKm / straightLineDistanceKm)
      : 1.0;
}

/// Australian Road-Snap Routing Service (Graph-Theory Dijkstra / OSRM Backend)
/// Snaps start and end coordinates onto the official road graph (OpenStreetMap / OSRM)
/// to calculate exact driving kilometres on asphalt instead of linear chords cutting through buildings.
class RoadSnapRoutingService {
  final http.Client _client;

  RoadSnapRoutingService({http.Client? client})
      : _client = client ?? http.Client();

  /// Calculates exact driving road distance between two coordinates.
  /// Falls back gracefully to WGS-84 Geodesic ellipsoidal straight-line if offline.
  Future<RoadRouteResult> calculateRoadDistanceKm({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    bool includeGeometry = true,
  }) async {
    final straightMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: startLat,
      lon1: startLon,
      lat2: endLat,
      lon2: endLon,
    );
    final straightKm = straightMeters / 1000.0;

    try {
      final overviewParam = includeGeometry ? 'full' : 'false';
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?overview=$overviewParam&geometries=polyline',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'KiloClaim-Australia-Logbook-Engine/1.0',
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
            final durationSec =
                (bestRoute['duration'] as num?)?.toDouble() ?? 0.0;
            final geometry = bestRoute['geometry'] as String?;

            final roadKm =
                double.parse((roadMeters / 1000.0).toStringAsFixed(2));

            return RoadRouteResult(
              roadDistanceKm: roadKm,
              straightLineDistanceKm:
                  double.parse(straightKm.toStringAsFixed(2)),
              isRoadSnapped: true,
              durationSeconds: durationSec,
              geometryPolyline: geometry,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[RoadSnapRoutingService] Offline fallback engaged: $e');
    }

    return RoadRouteResult(
      roadDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
      straightLineDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
      isRoadSnapped: false,
      durationSeconds: 0.0,
      geometryPolyline: null,
    );
  }

  /// Snaps a full GPS breadcrumb trace onto the road network via OSRM `/match/v1/driving/`.
  /// Samples/chunks to <= 80 points, falls back to `/route/v1/driving/` and then
  /// WGS-84 geodesic path accumulation if offline.
  Future<RoadRouteResult> matchTrace(
    List<Position> path, {
    bool includeGeometry = true,
  }) async {
    if (path.length < 2) {
      return const RoadRouteResult(
        roadDistanceKm: 0.0,
        straightLineDistanceKm: 0.0,
        isRoadSnapped: false,
        durationSeconds: 0.0,
        geometryPolyline: null,
      );
    }

    final sampled = _downsamplePath(path, maxPoints: 80);
    final straightKm = Wgs84GeodesicEngine.calculateDistanceMeters(
          lat1: sampled.first.latitude,
          lon1: sampled.first.longitude,
          lat2: sampled.last.latitude,
          lon2: sampled.last.longitude,
        ) /
        1000.0;

    double geodesicPathMeters = 0.0;
    for (int i = 0; i < sampled.length - 1; i++) {
      geodesicPathMeters += Wgs84GeodesicEngine.calculateDistanceMeters(
        lat1: sampled[i].latitude,
        lon1: sampled[i].longitude,
        lat2: sampled[i + 1].latitude,
        lon2: sampled[i + 1].longitude,
      );
    }
    final geodesicPathKm = geodesicPathMeters / 1000.0;

    try {
      final coords =
          sampled.map((p) => '${p.longitude},${p.latitude}').join(';');
      final radiuses = sampled
          .map((p) => p.accuracy.clamp(5.0, 50.0).toStringAsFixed(0))
          .join(';');
      final overviewParam = includeGeometry ? 'full' : 'false';

      // OSRM requires strictly non-decreasing timestamps if provided
      bool monotonicTimestamps = true;
      final timestamps = <int>[];
      for (final p in sampled) {
        final sec = p.timestamp.millisecondsSinceEpoch ~/ 1000;
        if (timestamps.isNotEmpty && sec < timestamps.last) {
          monotonicTimestamps = false;
          break;
        }
        timestamps.add(sec);
      }

      final tsQuery =
          monotonicTimestamps ? '&timestamps=${timestamps.join(';')}' : '';
      final uri = Uri.parse(
        'https://router.project-osrm.org/match/v1/driving/$coords?overview=$overviewParam&geometries=polyline&radiuses=$radiuses$tsQuery',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'KiloClaim-Australia-Logbook-Engine/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['matchings'] != null) {
          final matchings = data['matchings'] as List<dynamic>;
          if (matchings.isNotEmpty) {
            double totalMeters = 0.0;
            double totalDuration = 0.0;
            String? bestGeometry;
            double bestGeometryDist = -1.0;

            for (final raw in matchings) {
              final m = raw as Map<String, dynamic>;
              final dist = (m['distance'] as num?)?.toDouble() ?? 0.0;
              final dur = (m['duration'] as num?)?.toDouble() ?? 0.0;
              totalMeters += dist;
              totalDuration += dur;
              final geom = m['geometry'] as String?;
              if (geom != null && geom.isNotEmpty && dist > bestGeometryDist) {
                bestGeometry = geom;
                bestGeometryDist = dist;
              }
            }

            if (totalMeters > 0) {
              return RoadRouteResult(
                roadDistanceKm:
                    double.parse((totalMeters / 1000.0).toStringAsFixed(2)),
                straightLineDistanceKm:
                    double.parse(straightKm.toStringAsFixed(2)),
                isRoadSnapped: true,
                durationSeconds: totalDuration,
                geometryPolyline: bestGeometry,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[RoadSnapRoutingService] OSRM matchTrace fallback to route: $e');
    }

    // Fallback 1: 2-point OSRM /route/v1/driving/
    final routeFallback = await calculateRoadDistanceKm(
      startLat: sampled.first.latitude,
      startLon: sampled.first.longitude,
      endLat: sampled.last.latitude,
      endLon: sampled.last.longitude,
      includeGeometry: includeGeometry,
    );
    if (routeFallback.isRoadSnapped) {
      return routeFallback;
    }

    // Fallback 2: Full-trace WGS-84 geodesic accumulation
    return RoadRouteResult(
      roadDistanceKm: double.parse(geodesicPathKm.toStringAsFixed(2)),
      straightLineDistanceKm: double.parse(straightKm.toStringAsFixed(2)),
      isRoadSnapped: false,
      durationSeconds: 0.0,
      geometryPolyline: null,
    );
  }

  static List<Position> _downsamplePath(List<Position> path,
      {required int maxPoints}) {
    if (path.length <= maxPoints) return path;
    final result = <Position>[path.first];
    final innerCount = maxPoints - 2;
    final step = (path.length - 2) / innerCount;
    for (int i = 0; i < innerCount; i++) {
      final idx = 1 + (i * step).round().clamp(0, path.length - 3);
      result.add(path[idx]);
    }
    result.add(path.last);
    return result;
  }

  /// Decodes a Google/OSRM encoded polyline string (1e5 precision) into lat/lng pairs.
  static List<({double lat, double lng})> decodePolyline(String encoded) {
    final points = <({double lat, double lng})>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add((lat: lat / 1e5, lng: lng / 1e5));
    }

    return points;
  }
}
