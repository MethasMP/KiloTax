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
  final List<String> linkedExpenseIds; // Evidence Graph: Connected expenses (Fuel, Bunnings, Tolls)
  final String? clientDedupId; // Idempotency Key (Prevents duplicate syncs)
  final DateTime? deletedAt; // Soft Delete support
  final TaxMethod taxMethod; // Isolated tax scheme: centsPerKm vs logbook
  final String evidenceSource; // 'auto_telemetry', 'bluetooth_auto', 'manual_retroactive'
  final String? jobReference; // Evidence Link: Client site, Job ID, or Invoice ref

  Trip({
    required this.id,
    required this.vehicleId,
    required this.distanceKm,
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
  })  : assert(distanceKm >= 0, 'Trip distance cannot be negative'),
        assert(
          (startOdometer == 0.0 && endOdometer == 0.0) || endOdometer >= startOdometer,
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
      jobReference: jobReference ?? this.jobReference,
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

    return Trip(
      id: json['id'] as String,
      vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
      distanceKm: ((json['distanceKm'] ?? json['distance_km']) as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      purpose: json['purpose'] as String? ?? '',
      startOdometer: ((json['startOdometer'] ?? json['start_odometer']) as num?)?.toDouble() ?? 0.0,
      endOdometer: ((json['endOdometer'] ?? json['end_odometer']) as num?)?.toDouble() ?? 0.0,
      classification: TripClassification.values.firstWhere(
        (c) => c.name == json['classification'],
        orElse: () => TripClassification.business,
      ),
      originAddress: (json['originAddress'] ?? json['origin_address']) as String?,
      destinationAddress: (json['destinationAddress'] ?? json['destination_address']) as String?,
      linkedExpenseIds: (json['linkedExpenseIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      clientDedupId: (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null),
      taxMethod: resolvedTaxMethod,
      evidenceSource: (json['evidenceSource'] ?? json['evidence_source'] ?? 'auto_telemetry') as String,
      jobReference: (json['jobReference'] ?? json['job_reference']) as String?,
    );
  }
}
