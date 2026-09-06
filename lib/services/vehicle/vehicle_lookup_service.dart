import 'dart:convert';
import 'dart:io';
import '../../data/models/vehicle.dart';

/// Normalized Vehicle Lookup Model
/// Direct keys for zero confusion: id, make, model, variant, displayName, vehicleType, engineCapacity, fuelType
class VehicleLookupResult {
  final String id;
  final String make;
  final String model;
  final String variant;
  final String displayName;
  final VehicleType vehicleType;
  final String engineCapacity;
  final String fuelType;

  VehicleLookupResult({
    required this.id,
    required this.make,
    required this.model,
    required this.variant,
    required this.displayName,
    required this.vehicleType,
    required this.engineCapacity,
    this.fuelType = 'Diesel',
  });

  String get atoCategoryLabel {
    switch (vehicleType) {
      case VehicleType.ute:
        return 'Commercial Ute (>1t)';
      case VehicleType.van:
        return 'Delivery Van';
      case VehicleType.car:
        return 'Passenger Car (<1t)';
    }
  }

  factory VehicleLookupResult.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? 'ute').toString().toLowerCase();
    final vehicleType = typeStr == 'van'
        ? VehicleType.van
        : (typeStr == 'ute' ? VehicleType.ute : VehicleType.car);

    final make = (json['make'] ?? '').toString();
    final model = (json['model'] ?? '').toString();
    final variant = (json['variant'] ?? '').toString();
    final displayName = json['display_name'] ?? '$make $model $variant'.trim();

    return VehicleLookupResult(
      id: (json['id'] ?? '').toString(),
      make: make,
      model: model,
      variant: variant,
      displayName: displayName,
      vehicleType: vehicleType,
      engineCapacity: (json['engine'] ?? '').toString(),
      fuelType: (json['fuel'] ?? 'Diesel').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'variant': variant,
        'display_name': displayName,
        'type': vehicleType.shortCategoryName.toLowerCase(),
        'engine': engineCapacity,
        'fuel': fuelType,
      };
}

/// Australian Vehicle Directory & Lookup Service
/// Fetches normalized flat dataset (BITRE / CC BY 3.0 AU) hosted on jsDelivr Global Edge CDN.
/// Zero-app-bloat, in-memory cached, and offline resilient.
class VehicleLookupService {
  static const String cdnUrl =
      'https://cdn.jsdelivr.net/gh/MethasMP/KiloTax@main/australia_vehicles.json';

  // In-Memory Cache (fetched once per app session)
  static List<VehicleLookupResult>? _cachedVehicles;
  static bool _isLoading = false;

  /// Fetch vehicle directory from CDN with instant memory caching
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

        _cachedVehicles = list
            .map((item) => VehicleLookupResult.fromJson(item as Map<String, dynamic>))
            .toList();

        return _cachedVehicles!;
      }
    } catch (_) {
      // Graceful offline fallback
    } finally {
      _isLoading = false;
    }

    // Default top Australian work vehicles fallback when completely offline
    _cachedVehicles ??= [
      VehicleLookupResult(
        id: 'toyota-hilux-sr5',
        make: 'Toyota',
        model: 'Hilux',
        variant: 'SR5 4x4',
        displayName: 'Toyota Hilux SR5 4x4',
        engineCapacity: '2.8L Turbo Diesel',
        vehicleType: VehicleType.ute,
        fuelType: 'Diesel',
      ),
      VehicleLookupResult(
        id: 'ford-ranger-wildtrak-v6',
        make: 'Ford',
        model: 'Ranger',
        variant: 'Wildtrak 3.0L V6 4x4',
        displayName: 'Ford Ranger Wildtrak 3.0L V6 4x4',
        engineCapacity: '3.0L V6 Turbo Diesel',
        vehicleType: VehicleType.ute,
        fuelType: 'Diesel',
      ),
      VehicleLookupResult(
        id: 'isuzu-dmax-x-terrain',
        make: 'Isuzu',
        model: 'D-Max',
        variant: 'X-Terrain 4x4 Crew Cab',
        displayName: 'Isuzu D-Max X-Terrain 4x4 Crew Cab',
        engineCapacity: '3.0L 4JJ3 Turbo Diesel',
        vehicleType: VehicleType.ute,
        fuelType: 'Diesel',
      ),
      VehicleLookupResult(
        id: 'toyota-hiace-lwb',
        make: 'Toyota',
        model: 'HiAce',
        variant: 'LWB Van',
        displayName: 'Toyota HiAce LWB Van',
        engineCapacity: '2.8L Diesel',
        vehicleType: VehicleType.van,
        fuelType: 'Diesel',
      ),
    ];
    return _cachedVehicles!;
  }

  /// Multi-token Search across make, model, variant, and display_name
  static Future<List<VehicleLookupResult>> search(String query) async {
    final list = await getVehicleDirectory();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;

    final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();

    return list.where((v) {
      final target = '${v.make} ${v.model} ${v.variant} ${v.engineCapacity}'.toLowerCase();
      // All search tokens must match target string
      return tokens.every((token) => target.contains(token));
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
        (v) => v.id == 'toyota-hilux-sr5',
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
      (v) => v.id.startsWith('ford-ranger'),
      orElse: () => list.first,
    );
  }
}
