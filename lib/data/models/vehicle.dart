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
  });

  String get displayName => '$make $model ($regoPlate)';
}
