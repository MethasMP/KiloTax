import 'dart:convert';

/// Immutable model representing an ongoing in-flight driving session.
/// Saved to persistent disk continuously so that if iOS terminates the process
/// (due to low memory, user swipe kill, or crash), 100% of the accumulated
/// tax deduction evidence can be resurrected on next app launch.
class InFlightTrip {
  final String id;
  final String vehicleId;
  final String purpose;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final double distanceKm;
  final double startLatitude;
  final double startLongitude;
  final double lastLatitude;
  final double lastLongitude;
  final String? originAddress;
  final String? lastAddress;
  final double startOdometer;

  const InFlightTrip({
    required this.id,
    required this.vehicleId,
    required this.purpose,
    required this.startedAt,
    required this.lastUpdatedAt,
    required this.distanceKm,
    required this.startLatitude,
    required this.startLongitude,
    required this.lastLatitude,
    required this.lastLongitude,
    this.originAddress,
    this.lastAddress,
    required this.startOdometer,
  });

  InFlightTrip copyWith({
    String? id,
    String? vehicleId,
    String? purpose,
    DateTime? startedAt,
    DateTime? lastUpdatedAt,
    double? distanceKm,
    double? startLatitude,
    double? startLongitude,
    double? lastLatitude,
    double? lastLongitude,
    String? originAddress,
    String? lastAddress,
    double? startOdometer,
  }) {
    return InFlightTrip(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      purpose: purpose ?? this.purpose,
      startedAt: startedAt ?? this.startedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      originAddress: originAddress ?? this.originAddress,
      lastAddress: lastAddress ?? this.lastAddress,
      startOdometer: startOdometer ?? this.startOdometer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'purpose': purpose,
      'startedAt': startedAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'distanceKm': distanceKm,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'originAddress': originAddress,
      'lastAddress': lastAddress,
      'startOdometer': startOdometer,
    };
  }

  factory InFlightTrip.fromJson(Map<String, dynamic> json) {
    return InFlightTrip(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String? ?? 'default_vehicle',
      purpose: json['purpose'] as String? ?? 'Business',
      startedAt: DateTime.parse(json['startedAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      startLatitude: (json['startLatitude'] as num).toDouble(),
      startLongitude: (json['startLongitude'] as num).toDouble(),
      lastLatitude: (json['lastLatitude'] as num).toDouble(),
      lastLongitude: (json['lastLongitude'] as num).toDouble(),
      originAddress: json['originAddress'] as String?,
      lastAddress: json['lastAddress'] as String?,
      startOdometer: (json['startOdometer'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String serialize() => jsonEncode(toJson());

  static InFlightTrip? deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return InFlightTrip.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
