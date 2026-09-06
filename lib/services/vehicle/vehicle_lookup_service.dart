import 'dart:convert';
import 'dart:io';
import '../../data/models/vehicle.dart';

class VehicleLookupResult {
  final String make;
  final String model;
  final String engineCapacity;
  final VehicleType vehicleType;
  final String fuelType;
  final String years;

  VehicleLookupResult({
    required this.make,
    required this.model,
    required this.engineCapacity,
    required this.vehicleType,
    this.fuelType = 'Diesel',
    this.years = '',
  });

  String get displayName => '$make $model';
}

/// Australian Vehicle Directory & Lookup Service
/// Fetches open data (BITRE / CC BY 3.0 AU) hosted on jsDelivr Global Edge CDN.
/// Zero-app-bloat, in-memory cached, and offline resilient.
class VehicleLookupService {
  static const String cdnUrl =
      'https://cdn.jsdelivr.net/gh/MethasMP/KiloTax@main/australia_vehicles.json';

  // Fast In-Memory Cache so CDN is fetched at most once per app session
  static List<VehicleLookupResult>? _cachedVehicles;
  static bool _isLoading = false;

  /// Fetch vehicles list from Global Edge CDN (or return cached)
  static Future<List<VehicleLookupResult>> getVehicleDirectory() async {
    if (_cachedVehicles != null && _cachedVehicles!.isNotEmpty) {
      return _cachedVehicles!;
    }

    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_cachedVehicles != null) return _cachedVehicles!;
    }

    _isLoading = true;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(cdnUrl));
      request.headers.set('User-Agent', 'KiloTax-ATO/1.0 (Privacy-First Client)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> jsonMap = json.decode(responseBody);
        final List list = jsonMap['vehicles'] as List? ?? [];

        _cachedVehicles = list.map((item) {
          final typeStr = (item['type'] ?? 'ute').toString().toLowerCase();
          final vehicleType = typeStr == 'van'
              ? VehicleType.van
              : (typeStr == 'ute' ? VehicleType.ute : VehicleType.car);

          return VehicleLookupResult(
            make: item['make'] ?? '',
            model: item['model'] ?? '',
            engineCapacity: item['engine'] ?? '',
            vehicleType: vehicleType,
            fuelType: item['fuel'] ?? 'Diesel',
            years: item['years'] ?? '',
          );
        }).toList();

        return _cachedVehicles!;
      }
    } catch (_) {
      // Offline fallback
    } finally {
      _isLoading = false;
    }

    // Default top Australian work vehicles fallback when completely offline
    _cachedVehicles ??= [
      VehicleLookupResult(
        make: 'Toyota',
        model: 'Hilux SR5 4x4',
        engineCapacity: '2.8L Turbo Diesel',
        vehicleType: VehicleType.ute,
      ),
      VehicleLookupResult(
        make: 'Ford',
        model: 'Ranger Wildtrak',
        engineCapacity: '3.0L V6 Turbo Diesel',
        vehicleType: VehicleType.ute,
      ),
      VehicleLookupResult(
        make: 'Isuzu',
        model: 'D-Max X-Terrain',
        engineCapacity: '3.0L 4JJ3 Turbo Diesel',
        vehicleType: VehicleType.ute,
      ),
      VehicleLookupResult(
        make: 'Toyota',
        model: 'HiAce LWB',
        engineCapacity: '2.8L Diesel',
        vehicleType: VehicleType.van,
      ),
    ];
    return _cachedVehicles!;
  }

  /// Search vehicles by query (e.g. 'hilux', 'ford', 'ranger')
  static Future<List<VehicleLookupResult>> search(String query) async {
    final list = await getVehicleDirectory();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((v) {
      return v.make.toLowerCase().contains(q) ||
          v.model.toLowerCase().contains(q) ||
          v.displayName.toLowerCase().contains(q);
    }).toList();
  }

  /// Lookup plate simulation / matcher against directory
  static Future<VehicleLookupResult?> lookup({
    required String state,
    required String plate,
  }) async {
    final list = await getVehicleDirectory();
    final p = plate.toUpperCase().trim();

    if (p.contains('UTE') || p.contains('TRD') || p.contains('777')) {
      return list.firstWhere(
        (v) => v.model.toLowerCase().contains('hilux'),
        orElse: () => list.first,
      );
    }
    if (p.contains('VAN') || p.contains('EXP')) {
      return list.firstWhere(
        (v) => v.vehicleType == VehicleType.van,
        orElse: () => list.first,
      );
    }
    return list.firstWhere(
      (v) => v.model.toLowerCase().contains('ranger'),
      orElse: () => list.first,
    );
  }
}
