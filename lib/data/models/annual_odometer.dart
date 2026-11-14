/// Represents opening and closing odometer records for a vehicle in an Australian
/// Financial Year (1 July to 30 June) under ITAA 1997 s 28-J.
class AnnualVehicleOdometer {
  final String id;
  final String vehicleId;
  final String financialYear; // e.g. "2024-2025" or "FY25"
  final DateTime openingDate;
  final double openingOdometer;
  final DateTime? closingDate;
  final double? closingOdometer;

  const AnnualVehicleOdometer({
    required this.id,
    required this.vehicleId,
    required this.financialYear,
    required this.openingDate,
    required this.openingOdometer,
    this.closingDate,
    this.closingOdometer,
  });

  /// Total annual kilometres travelled during the financial year if closing odometer is present.
  double? get totalAnnualKm =>
      closingOdometer != null ? closingOdometer! - openingOdometer : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'financialYear': financialYear,
      'openingDate': openingDate.toIso8601String(),
      'openingOdometer': openingOdometer,
      'closingDate': closingDate?.toIso8601String(),
      'closingOdometer': closingOdometer,
    };
  }

  factory AnnualVehicleOdometer.fromJson(Map<String, dynamic> json) {
    return AnnualVehicleOdometer(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      financialYear: json['financialYear'] as String,
      openingDate: DateTime.parse(json['openingDate'] as String),
      openingOdometer: (json['openingOdometer'] as num).toDouble(),
      closingDate: json['closingDate'] != null
          ? DateTime.parse(json['closingDate'] as String)
          : null,
      closingOdometer: (json['closingOdometer'] as num?)?.toDouble(),
    );
  }

  AnnualVehicleOdometer copyWith({
    String? id,
    String? vehicleId,
    String? financialYear,
    DateTime? openingDate,
    double? openingOdometer,
    DateTime? closingDate,
    double? closingOdometer,
  }) {
    return AnnualVehicleOdometer(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      financialYear: financialYear ?? this.financialYear,
      openingDate: openingDate ?? this.openingDate,
      openingOdometer: openingOdometer ?? this.openingOdometer,
      closingDate: closingDate ?? this.closingDate,
      closingOdometer: closingOdometer ?? this.closingOdometer,
    );
  }
}
