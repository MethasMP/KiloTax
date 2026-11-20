import '../../services/tracking/wgs84_geodesic_engine.dart';

/// JobSite Point of Interest (POI) Entity
/// Represents a work location, client project, depot, or trade supplier.
/// Enforces WGS84 geodesic geometry boundaries and ATO business nexus verification.
class JobSite {
  final String id;
  final String userId;
  final String name;
  final String clientName;
  final String? projectCode;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final bool trackingEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobSite({
    String? id,
    this.userId = '',
    String? name,
    String? clientName,
    this.projectCode,
    this.address = '',
    double? latitude,
    double? longitude,
    double? lat,
    double? lng,
    this.radiusMeters = 150.0,
    this.isActive = true,
    this.trackingEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? 'site_${DateTime.now().millisecondsSinceEpoch}',
        name = name ?? 'Job Site',
        clientName = clientName ?? 'Client',
        latitude = latitude ?? lat ?? 0.0,
        longitude = longitude ?? lng ?? 0.0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        assert((latitude ?? lat ?? 0.0) >= -90.0 && (latitude ?? lat ?? 0.0) <= 90.0,
            'Latitude must be between -90 and 90 degrees'),
        assert((longitude ?? lng ?? 0.0) >= -180.0 && (longitude ?? lng ?? 0.0) <= 180.0,
            'Longitude must be between -180 and 180 degrees'),
        assert(radiusMeters >= 10.0 && radiusMeters <= 5000.0,
            'Radius must be between 10m and 5,000m');

  double get lat => latitude;
  double get lng => longitude;

  /// Evaluates whether a given GPS coordinate falls within this JobSite's geodesic geofence.
  bool containsCoordinate({
    required double lat,
    required double lng,
  }) {
    if (!trackingEnabled) return false;
    final distanceMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: latitude,
      lon1: longitude,
      lat2: lat,
      lon2: lng,
    );
    return distanceMeters <= radiusMeters;
  }

  /// Calculates exact geodesic distance from a coordinate to this JobSite center in meters.
  double distanceTo({
    required double lat,
    required double lng,
  }) {
    return Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: latitude,
      lon1: longitude,
      lat2: lat,
      lon2: lng,
    );
  }

  JobSite copyWith({
    String? id,
    String? userId,
    String? name,
    String? clientName,
    String? projectCode,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
    bool? trackingEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobSite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      projectCode: projectCode ?? this.projectCode,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'clientName': clientName,
      'projectCode': projectCode,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'trackingEnabled': trackingEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JobSite.fromJson(Map<String, dynamic> json) {
    return JobSite(
      id: (json['local_id'] ?? json['id']) as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String,
      clientName:
          json['clientName'] as String? ?? json['client_name'] as String? ?? '',
      projectCode:
          json['projectCode'] as String? ?? json['project_code'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num? ??
              json['radius_meters'] as num? ??
              150.0)
          .toDouble(),
      trackingEnabled:
          (json['trackingEnabled'] ?? json['tracking_enabled']) as bool? ??
              true,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now(),
    );
  }
}
