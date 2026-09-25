import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// High-fidelity On-Device / Fallback Geocoding Service for Australian Suburbs
/// Resolves GPS Coordinates (lat, long) into clean Australian address formats
/// (e.g. "Richmond VIC" or "142 Commercial Rd, Prahran VIC")
class GeocodingService {
  static final http.Client _client = http.Client();
  static final Map<String, String> _cache = {};

  /// Converts Latitude & Longitude to a concise, human-readable Australian address.
  /// Falls back gracefully to formatted coordinates if offline or unresolved.
  static Future<String> reverseGeocode(
    double latitude,
    double longitude, {
    http.Client? client,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final httpClient = client ?? _client;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&zoom=16&addressdetails=1',
      );

      final response = await httpClient.get(
        uri,
        headers: {
          'User-Agent': 'KiloTax-Australia-Logbook-Engine/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] as String?;
          final suburb = (address['suburb'] ??
              address['neighbourhood'] ??
              address['town'] ??
              address['city'] ??
              address['county']) as String?;
          final state = address['state'] as String?;
          final postcode = address['postcode'] as String?;

          final stateShort = _abbreviateState(state);

          final placeName = data['name'] as String?;

          String? result;
          if (placeName != null && placeName.isNotEmpty && suburb != null) {
            result = '$placeName, $suburb $stateShort';
          } else if (road != null && suburb != null) {
            result = '$road, $suburb $stateShort';
          } else if (suburb != null) {
            result = '$suburb $stateShort ${postcode ?? ''}'.trim();
          } else if (placeName != null && placeName.isNotEmpty) {
            result = placeName;
          }

          if (result != null) {
            _cache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Reverse geocode silent bypass: $e');
    }

    // Resilient fallback: Clean coordinate tag
    final fallback = 'Location (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)})';
    _cache[cacheKey] = fallback;
    return fallback;
  }

  /// Resolves the Australian state abbreviation from GPS coordinates.
  /// Uses precise coordinate bounding boxes (zero network needed).
  /// Returns null if outside Australia.
  static String? stateFromCoordinates(double lat, double lng) {
    // Quick geographic bounds check for Australia
    // WA: West of 129°E
    if (lng < 129.0 && lat < -13.0 && lat > -36.0) return 'WA';
    // NT: North of 26°S, between 129°E and 138°E
    if (lat > -26.0 && lat < -10.0 && lng >= 129.0 && lng < 138.0) return 'NT';
    // SA: South of 26°S, between 129°E and 141°E
    if (lat <= -26.0 && lat > -39.0 && lng >= 129.0 && lng < 141.0) return 'SA';
    // QLD: North of 29°S, east of 138°E
    if (lat > -29.0 && lat < -9.0 && lng >= 138.0) return 'QLD';
    // TAS: South of 39.5°S
    if (lat <= -39.5 && lat > -44.0 && lng >= 143.0 && lng <= 149.0) return 'TAS';
    // ACT: Pocket around Canberra (-35.1 to -35.9, 148.7 to 149.4)
    if (lat <= -35.1 && lat >= -35.9 && lng >= 148.7 && lng <= 149.4) return 'ACT';
    // VIC: South of Murray River (~-34.0 to -39.2, 140.9 to 150.0)
    if (lat <= -34.0 && lat > -39.5 && lng >= 140.9 && lng <= 150.0) {
      // Border differentiation between VIC and NSW
      if (lat < -36.0 || (lat < -34.5 && lng < 143.0)) return 'VIC';
    }
    // Default eastern mainland corridor is NSW
    if (lat < -28.0 && lat > -38.0 && lng >= 141.0) return 'NSW';

    return null; // Return null if outside Australia bounds
  }

  static String _abbreviateState(String? state) {
    if (state == null) return '';
    final lower = state.toLowerCase();
    if (lower.contains('victoria')) return 'VIC';
    if (lower.contains('new south wales')) return 'NSW';
    if (lower.contains('queensland')) return 'QLD';
    if (lower.contains('western australia')) return 'WA';
    if (lower.contains('south australia')) return 'SA';
    if (lower.contains('tasmania')) return 'TAS';
    if (lower.contains('northern territory')) return 'NT';
    if (lower.contains('australian capital territory')) return 'ACT';
    return state;
  }
}
