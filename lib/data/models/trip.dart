import 'vehicle.dart';

enum TripClassification {
  business,
  personal,
  unclassified;

  String get displayName {
    switch (this) {
      case TripClassification.business:
        return 'Business (Deductible)';
      case TripClassification.personal:
        return 'Personal';
      case TripClassification.unclassified:
        return 'Unclassified';
    }
  }
}

/// Core Trip Entity conforming to Layer 1 (TRIPS):
/// - Vehicle
/// - Distance
/// - Date
/// - Purpose
/// - Odometer
/// - Tax Method (CPK vs Logbook isolation)
/// - Evidence Source (Auto telemetry vs manual)
class Trip {
  final String id;
  final String vehicleId;
  final double distanceKm;
  final DateTime date;
  final String purpose;
  final double startOdometer;
  final double endOdometer;
  final TripClassification classification;
  final String? originAddress;
  final String? destinationAddress;
  final List<String>
      linkedExpenseIds; // Evidence Graph: Connected expenses (Fuel, Bunnings, Tolls)
  final String? clientDedupId; // Idempotency Key (Prevents duplicate syncs)
  final DateTime? deletedAt; // Soft Delete support
  final TaxMethod taxMethod; // Isolated tax scheme: centsPerKm vs logbook
  final String
      evidenceSource; // 'auto_telemetry', 'bluetooth_auto', 'manual_retroactive'
  final String?
      jobReference; // Evidence Link: Client site, Job ID, or Invoice ref

  final String? jobId;
  final Map<String, dynamic> review;
  final String? routePolyline;
  final Map<String, dynamic>? detectedPoi;
  final bool isPassengerUnverified;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final DateTime? stoppedAt;
  final int? stoppedDuration; // in seconds

  double? get startLatitude => startLat;
  double? get startLongitude => startLng;
  double? get endLatitude => endLat;
  double? get endLongitude => endLng;

  /// Full captured distance is retained; only confirmed business distance is counted.
  double get businessDistanceKm {
    if (!isBusiness || isDeleted) return 0;
    final value = review['businessKm'];
    return value is num && value.isFinite
        ? value.toDouble().clamp(0.0, distanceKm)
        : distanceKm;
  }

  bool get isMixed => isBusiness && businessDistanceKm < distanceKm;
  String get useLabel => isMixed
      ? 'Mixed'
      : isBusiness
          ? 'Business'
          : classification.displayName;
  bool get shareRoute => isBusiness && !isMixed;

  Trip({
    required this.id,
    required this.vehicleId,
    double distanceKm = 0.0,
    required this.date,
    required this.purpose,
    this.startOdometer = 0.0,
    this.endOdometer = 0.0,
    this.classification = TripClassification.business,
    this.originAddress,
    this.destinationAddress,
    List<String>? linkedExpenseIds,
    this.clientDedupId,
    this.deletedAt,
    this.taxMethod = TaxMethod.centsPerKm,
    this.evidenceSource = 'auto_telemetry',
    this.jobReference,
    this.jobId,
    this.routePolyline,
    this.detectedPoi,
    this.isPassengerUnverified = false,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.stoppedAt,
    this.stoppedDuration,
    Map<String, dynamic> review = const {},
  })  : review = Map.unmodifiable(review),
        distanceKm = distanceKm < 0.0 ? 0.0 : distanceKm,
        assert(
          (startOdometer == 0.0 && endOdometer == 0.0) ||
              endOdometer >= startOdometer,
          'End odometer cannot be less than start odometer',
        ),
        linkedExpenseIds = linkedExpenseIds ?? [];

  bool get isBusiness => classification == TripClassification.business;
  bool get isDeleted => deletedAt != null;

  Trip copyWith({
    String? id,
    String? vehicleId,
    double? distanceKm,
    DateTime? date,
    String? purpose,
    double? startOdometer,
    double? endOdometer,
    TripClassification? classification,
    String? originAddress,
    String? destinationAddress,
    List<String>? linkedExpenseIds,
    String? clientDedupId,
    DateTime? deletedAt,
    TaxMethod? taxMethod,
    String? evidenceSource,
    String? jobReference,
    String? jobId,
    bool clearJob = false,
    String? routePolyline,
    Map<String, dynamic>? detectedPoi,
    bool? isPassengerUnverified,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    DateTime? stoppedAt,
    int? stoppedDuration,
    Map<String, dynamic>? review,
  }) {
    return Trip(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      distanceKm: distanceKm ?? this.distanceKm,
      date: date ?? this.date,
      purpose: purpose ?? this.purpose,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      classification: classification ?? this.classification,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      linkedExpenseIds: linkedExpenseIds ?? this.linkedExpenseIds,
      clientDedupId: clientDedupId ?? this.clientDedupId,
      deletedAt: deletedAt ?? this.deletedAt,
      taxMethod: taxMethod ?? this.taxMethod,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      jobReference: clearJob ? null : (jobReference ?? this.jobReference),
      jobId: clearJob ? null : (jobId ?? this.jobId),
      routePolyline: routePolyline ?? this.routePolyline,
      detectedPoi: detectedPoi ?? this.detectedPoi,
      isPassengerUnverified: isPassengerUnverified ?? this.isPassengerUnverified,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      stoppedDuration: stoppedDuration ?? this.stoppedDuration,
      review: review ??
          (this.review.isNotEmpty &&
                  classification != null &&
                  classification != this.classification
              ? {
                  ...this.review,
                  'businessKm': classification == TripClassification.business
                      ? distanceKm ?? this.distanceKm
                      : 0.0
                }
              : this.review),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'distanceKm': distanceKm,
      'date': date.toIso8601String(),
      'purpose': purpose,
      'startOdometer': startOdometer,
      'endOdometer': endOdometer,
      'classification': classification.name,
      'originAddress': originAddress,
      'destinationAddress': destinationAddress,
      'linkedExpenseIds': linkedExpenseIds,
      'clientDedupId': clientDedupId,
      'deletedAt': deletedAt?.toIso8601String(),
      'taxMethod': taxMethod.name,
      'evidenceSource': evidenceSource,
      'jobReference': jobReference,
      'jobId': jobId,
      'routePolyline': routePolyline,
      'detectedPoi': detectedPoi,
      'isPassengerUnverified': isPassengerUnverified,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'stoppedAt': stoppedAt?.toIso8601String(),
      'stoppedDuration': stoppedDuration,
      'review': review,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // Parse TaxMethod with fallback
    TaxMethod resolvedTaxMethod = TaxMethod.centsPerKm;
    final rawMethod = json['taxMethod'] ?? json['tax_method'];
    if (rawMethod != null) {
      resolvedTaxMethod = TaxMethod.values.firstWhere(
        (m) => m.name == rawMethod,
        orElse: () => TaxMethod.centsPerKm,
      );
    }

    final rawDist =
        ((json['distanceKm'] ?? json['distance_km']) as num?)?.toDouble() ??
            0.0;
    final clampedDist = rawDist < 0.0 ? 0.0 : rawDist;

    final startOdo = ((json['startOdometer'] ?? json['start_odometer']) as num?)
            ?.toDouble() ??
        0.0;
    final endOdo =
        ((json['endOdometer'] ?? json['end_odometer']) as num?)?.toDouble() ??
            0.0;

    return Trip(
      id: json['id'] as String,
      vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
      distanceKm: clampedDist,
      date: DateTime.parse(json['date'] as String),
      purpose: json['purpose'] as String? ?? '',
      startOdometer: startOdo,
      endOdometer: endOdo,
      classification: TripClassification.values.firstWhere(
        (c) => c.name == json['classification'],
        orElse: () => TripClassification.business,
      ),
      originAddress:
          (json['originAddress'] ?? json['origin_address']) as String?,
      destinationAddress: (json['destinationAddress'] ??
          json['destination_address']) as String?,
      linkedExpenseIds: (json['linkedExpenseIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      clientDedupId:
          (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null
              ? DateTime.tryParse(json['deleted_at'] as String)
              : null),
      taxMethod: resolvedTaxMethod,
      evidenceSource: (json['evidenceSource'] ??
          json['evidence_source'] ??
          'auto_telemetry') as String,
      jobReference: (json['jobReference'] ?? json['job_reference']) as String?,
      jobId: (json['jobId'] ?? json['job_id']) as String?,
      routePolyline:
          (json['routePolyline'] ?? json['route_polyline']) as String?,
      detectedPoi: (json['detectedPoi'] ?? json['detected_poi']) != null
          ? Map<String, dynamic>.from(
              (json['detectedPoi'] ?? json['detected_poi']) as Map)
          : null,
      isPassengerUnverified:
          (json['isPassengerUnverified'] ?? json['is_passenger_unverified']) as bool? ?? false,
      startLat: ((json['startLat'] ?? json['start_lat'] ?? json['startLatitude'] ?? json['start_latitude']) as num?)?.toDouble(),
      startLng: ((json['startLng'] ?? json['start_lng'] ?? json['startLongitude'] ?? json['start_longitude']) as num?)?.toDouble(),
      endLat: ((json['endLat'] ?? json['end_lat'] ?? json['endLatitude'] ?? json['end_latitude']) as num?)?.toDouble(),
      endLng: ((json['endLng'] ?? json['end_lng'] ?? json['endLongitude'] ?? json['end_longitude']) as num?)?.toDouble(),
      stoppedAt: json['stoppedAt'] != null
          ? DateTime.tryParse(json['stoppedAt'] as String)
          : (json['stopped_at'] != null ? DateTime.tryParse(json['stopped_at'] as String) : null),
      stoppedDuration: (json['stoppedDuration'] ?? json['stopped_duration']) as int?,
      review: Map<String, dynamic>.from((json['review'] as Map?) ?? const {}),
    );
  }
}
