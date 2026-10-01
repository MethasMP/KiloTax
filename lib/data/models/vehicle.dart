enum VehicleType {
  car,
  ute,
  van,
  suv,
  truck;

  String get displayName {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.ute:
        return 'Ute';
      case VehicleType.van:
        return 'Van';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.truck:
        return 'Truck';
    }
  }

  String get shortCategoryName {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.ute:
        return 'Ute';
      case VehicleType.van:
        return 'Van';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.truck:
        return 'Truck';
    }
  }

  String get svgAssetPath {
    switch (this) {
      case VehicleType.ute:
        return 'assets/vehicles/ute.svg';
      case VehicleType.van:
        return 'assets/vehicles/van.svg';
      case VehicleType.suv:
        return 'assets/vehicles/suv.svg';
      case VehicleType.truck:
        return 'assets/vehicles/truck.svg';
      case VehicleType.car:
        return 'assets/vehicles/car.svg';
    }
  }

  String get imageAssetPath {
    switch (this) {
      case VehicleType.ute:
        return 'assets/vehicles/ute.png';
      case VehicleType.van:
        return 'assets/vehicles/van.png';
      case VehicleType.suv:
        return 'assets/vehicles/suv.png';
      case VehicleType.truck:
        return 'assets/vehicles/truck.png';
      case VehicleType.car:
        return 'assets/vehicles/car.png';
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
  final String? startOdometerPhotoPath;
  final DateTime? startOdometerVerifiedAt;
  final String? startOdometerImageHash;
  final String? endOdometerPhotoPath;
  final DateTime? endOdometerVerifiedAt;
  final String? endOdometerImageHash;

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
    this.startOdometerPhotoPath,
    this.startOdometerVerifiedAt,
    this.startOdometerImageHash,
    this.endOdometerPhotoPath,
    this.endOdometerVerifiedAt,
    this.endOdometerImageHash,
  });

  bool get hasRegoPlate =>
      regoPlate.trim().isNotEmpty &&
      regoPlate.trim().toLowerCase() != 'no plate';

  String get displayName => hasRegoPlate
      ? '$make $model ($regoPlate)'
      : '$make $model';

  /// Body style resolver:
  /// Infers vehicle archetype from make & model keywords (Hilux, Ranger, RAV4, HiAce, etc.)
  VehicleType get effectiveVehicleType {
    if (vehicleType != VehicleType.car) return vehicleType;
    final m = model.toLowerCase();
    if (m.contains('hilux') ||
        m.contains('ranger') ||
        m.contains('d-max') ||
        m.contains('dmax') ||
        m.contains('navara') ||
        m.contains('triton') ||
        m.contains('amarok') ||
        m.contains('bt-50') ||
        m.contains('ute') ||
        m.contains('cab chassis')) {
      return VehicleType.ute;
    }
    if (m.contains('rav4') ||
        m.contains('cx-5') ||
        m.contains('everest') ||
        m.contains('prado') ||
        m.contains('landcruiser') ||
        m.contains('outback') ||
        m.contains('forester') ||
        m.contains('tucson') ||
        m.contains('sportage') ||
        m.contains('x-trail') ||
        m.contains('model y') ||
        m.contains('suv')) {
      return VehicleType.suv;
    }
    if (m.contains('hiace') ||
        m.contains('transit') ||
        m.contains('iload') ||
        m.contains('staria') ||
        m.contains('transporter') ||
        m.contains('caddy') ||
        m.contains('trafic') ||
        m.contains('van')) {
      return VehicleType.van;
    }
    if (m.contains('n-series') ||
        m.contains('isuzu') ||
        m.contains('canter') ||
        m.contains('hino') ||
        m.contains('truck')) {
      return VehicleType.truck;
    }
    return VehicleType.car;
  }

  Vehicle copyWith({
    String? id,
    String? make,
    String? model,
    String? regoPlate,
    double? initialOdometer,
    String? engineCapacity,
    VehicleType? vehicleType,
    String? bluetoothDeviceName,
    bool? isPrimary,
    TaxMethod? taxMethod,
    DateTime? logbookStartDate,
    String? clientDedupId,
    DateTime? deletedAt,
    String? startOdometerPhotoPath,
    DateTime? startOdometerVerifiedAt,
    String? startOdometerImageHash,
    String? endOdometerPhotoPath,
    DateTime? endOdometerVerifiedAt,
    String? endOdometerImageHash,
    bool clearBluetoothDevice = false,
  }) {
    return Vehicle(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      regoPlate: regoPlate ?? this.regoPlate,
      initialOdometer: initialOdometer ?? this.initialOdometer,
      engineCapacity: engineCapacity ?? this.engineCapacity,
      vehicleType: vehicleType ?? this.vehicleType,
      bluetoothDeviceName: clearBluetoothDevice
          ? null
          : (bluetoothDeviceName ?? this.bluetoothDeviceName),
      isPrimary: isPrimary ?? this.isPrimary,
      taxMethod: taxMethod ?? this.taxMethod,
      logbookStartDate: logbookStartDate ?? this.logbookStartDate,
      clientDedupId: clientDedupId ?? this.clientDedupId,
      deletedAt: deletedAt ?? this.deletedAt,
      startOdometerPhotoPath:
          startOdometerPhotoPath ?? this.startOdometerPhotoPath,
      startOdometerVerifiedAt:
          startOdometerVerifiedAt ?? this.startOdometerVerifiedAt,
      startOdometerImageHash:
          startOdometerImageHash ?? this.startOdometerImageHash,
      endOdometerPhotoPath: endOdometerPhotoPath ?? this.endOdometerPhotoPath,
      endOdometerVerifiedAt:
          endOdometerVerifiedAt ?? this.endOdometerVerifiedAt,
      endOdometerImageHash: endOdometerImageHash ?? this.endOdometerImageHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'regoPlate': regoPlate,
      'initialOdometer': initialOdometer,
      'engineCapacity': engineCapacity,
      'vehicleType': vehicleType.name,
      'bluetoothDeviceName': bluetoothDeviceName,
      'isPrimary': isPrimary,
      'taxMethod': taxMethod.name,
      'logbookStartDate': logbookStartDate?.toIso8601String(),
      'clientDedupId': clientDedupId,
      'deletedAt': deletedAt?.toIso8601String(),
      'startOdometerPhotoPath': startOdometerPhotoPath,
      'startOdometerVerifiedAt': startOdometerVerifiedAt?.toIso8601String(),
      'startOdometerImageHash': startOdometerImageHash,
      'endOdometerPhotoPath': endOdometerPhotoPath,
      'endOdometerVerifiedAt': endOdometerVerifiedAt?.toIso8601String(),
      'endOdometerImageHash': endOdometerImageHash,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      regoPlate: (json['regoPlate'] ?? json['rego_plate']) as String,
      initialOdometer:
          ((json['initialOdometer'] ?? json['initial_odometer']) as num)
              .toDouble(),
      engineCapacity:
          (json['engineCapacity'] ?? json['engine_capacity']) as String?,
      vehicleType: VehicleType.values.firstWhere(
        (v) => v.name == (json['vehicleType'] ?? json['vehicle_type']),
        orElse: () => VehicleType.car,
      ),
      bluetoothDeviceName: (json['bluetoothDeviceName'] ??
          json['bluetooth_device_name']) as String?,
      isPrimary: (json['isPrimary'] ?? json['is_primary']) as bool? ?? true,
      taxMethod: TaxMethod.values.firstWhere(
        (t) => t.name == (json['taxMethod'] ?? json['tax_method']),
        orElse: () => TaxMethod.centsPerKm,
      ),
      logbookStartDate:
          (json['logbookStartDate'] ?? json['logbook_start_date']) != null
              ? DateTime.tryParse((json['logbookStartDate'] ??
                  json['logbook_start_date']) as String)
              : null,
      clientDedupId:
          (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null
          ? DateTime.tryParse(
              (json['deletedAt'] ?? json['deleted_at']) as String)
          : null,
      startOdometerPhotoPath: (json['startOdometerPhotoPath'] ??
              json['start_odometer_photo_path']) as String?,
      startOdometerVerifiedAt: (json['startOdometerVerifiedAt'] ??
                  json['start_odometer_verified_at']) !=
              null
          ? DateTime.tryParse((json['startOdometerVerifiedAt'] ??
              json['start_odometer_verified_at']) as String)
          : null,
      startOdometerImageHash: (json['startOdometerImageHash'] ??
              json['start_odometer_image_hash']) as String?,
      endOdometerPhotoPath: (json['endOdometerPhotoPath'] ??
              json['end_odometer_photo_path']) as String?,
      endOdometerVerifiedAt: (json['endOdometerVerifiedAt'] ??
                  json['end_odometer_verified_at']) !=
              null
          ? DateTime.tryParse((json['endOdometerVerifiedAt'] ??
              json['end_odometer_verified_at']) as String)
          : null,
      endOdometerImageHash: (json['endOdometerImageHash'] ??
              json['end_odometer_image_hash']) as String?,
    );
  }
}
