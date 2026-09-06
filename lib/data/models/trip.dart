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

  Trip({
    required this.id,
    required this.vehicleId,
    required this.distanceKm,
    required this.date,
    required this.purpose,
    required this.startOdometer,
    required this.endOdometer,
    this.classification = TripClassification.business,
    this.originAddress,
    this.destinationAddress,
    List<String>? linkedExpenseIds,
    this.clientDedupId,
    this.deletedAt,
  })  : assert(distanceKm >= 0, 'Trip distance cannot be negative'),
        assert(endOdometer >= startOdometer, 'End odometer cannot be less than start odometer'),
        linkedExpenseIds = linkedExpenseIds ?? [];

  bool get isBusiness => classification == TripClassification.business;
  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'distance_km': distanceKm,
      'date': date.toIso8601String(),
      'purpose': purpose,
      'start_odometer': startOdometer,
      'end_odometer': endOdometer,
      'classification': classification.name,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'client_dedup_id': clientDedupId,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
