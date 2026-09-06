enum VehicleType {
  car,
  ute,
  van,
  suv,
  truck,
  motorcycle;

  String get shortCategoryName {
    switch (this) {
      case VehicleType.car:
        return 'Sedan / Hatch';
      case VehicleType.ute:
        return 'Tradie Ute';
      case VehicleType.van:
        return 'Delivery Van';
      case VehicleType.suv:
        return 'SUV / 4WD';
      case VehicleType.truck:
        return 'Light Truck';
      case VehicleType.motorcycle:
        return 'Motorcycle';
    }
  }
}

/// Tax Tracking Strategy per Vehicle (ATO Aligned)
enum TaxMethod {
  centsPerKm,
  logbook;

  String get title {
    switch (this) {
      case TaxMethod.centsPerKm:
        return 'Cents per Kilometre';
      case TaxMethod.logbook:
        return 'Logbook Method';
    }
  }

  String get description {
    switch (this) {
      case TaxMethod.centsPerKm:
        return 'Best if you drive less than 5,000 work km/year. Set rate 91c/km, no receipt hoarding required.';
      case TaxMethod.logbook:
        return 'Best if you drive a lot for work. 12-week logbook unlocks actual fuel, lease & depreciation claims.';
    }
  }

  String get shortBadge {
    switch (this) {
      case TaxMethod.centsPerKm:
        return '91c/km';
      case TaxMethod.logbook:
        return 'Logbook %';
    }
  }
}

class Vehicle {
  final String id;
  final String make;
  final String model;
  final String regoPlate;
  final double initialOdometer;
  final String? engineCapacity;
  final VehicleType vehicleType;
  final String? bluetoothDeviceName;
  final bool isPrimary;
  final TaxMethod taxMethod;
  final DateTime? logbookStartDate;
  final String? clientDedupId;
  final DateTime? deletedAt;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.regoPlate,
    required this.initialOdometer,
    this.engineCapacity,
    this.vehicleType = VehicleType.car,
    this.bluetoothDeviceName,
    this.isPrimary = true,
    this.taxMethod = TaxMethod.centsPerKm,
    this.logbookStartDate,
    this.clientDedupId,
    this.deletedAt,
  });

  String get displayName => '$make $model ($regoPlate)';
}
