import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  IconData get iconData {
    switch (this) {
      case VehicleType.ute:
        return Icons.minor_crash_rounded; // Front-facing vehicle badge for Ute / Work rig
      case VehicleType.van:
        return Icons.airport_shuttle_rounded; // Commercial van
      case VehicleType.suv:
        return Icons.directions_car_filled_rounded; // SUV
      case VehicleType.truck:
        return Icons.local_shipping_rounded; // Truck
      case VehicleType.car:
        return Icons.directions_car_rounded; // Car / Sedan
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

  /// Builds a Carsales / Tesla app grade 3D studio transparent cutout render
  /// Resolves specific car model assets (e.g. Tesla Model Y, Corolla) when available
  Widget build3dRender({
    String? make,
    String? model,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    String resolvedPath = imageAssetPath;
    final cleanModel = (model ?? '').toLowerCase();
    final cleanMake = (make ?? '').toLowerCase();

    if (cleanModel.contains('model y')) {
      resolvedPath = 'assets/vehicles/tesla_model_y.png';
    } else if (cleanModel.contains('corolla')) {
      resolvedPath = 'assets/vehicles/toyota_corolla.png';
    } else if (cleanMake.contains('tesla') && cleanModel.contains('model 3')) {
      resolvedPath = 'assets/vehicles/car.png';
    }

    return Image.asset(
      resolvedPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.asset(
        imageAssetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => buildSilhouette(
          width: width ?? 24,
          height: height ?? 24,
          fit: fit,
        ),
      ),
    );
  }

  /// Builds a high-precision vector silhouette icon with graceful Material icon fallback
  Widget buildSilhouette({
    double width = 24,
    double height = 24,
    Color color = const Color(0xFF0F172A),
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      svgAssetPath,
      width: width,
      height: height,
      fit: fit,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(iconData, size: height, color: color),
    );
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
  final String? toolSetupPhotoPath;
  final DateTime? toolSetupVerifiedAt;
  final String? toolSetupImageHash;

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
    this.toolSetupPhotoPath,
    this.toolSetupVerifiedAt,
    this.toolSetupImageHash,
  });

  String get displayName => (regoPlate.isEmpty || regoPlate == 'No Plate')
      ? '$make $model'
      : '$make $model ($regoPlate)';

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
    String? toolSetupPhotoPath,
    DateTime? toolSetupVerifiedAt,
    String? toolSetupImageHash,
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
      startOdometerPhotoPath: startOdometerPhotoPath ?? this.startOdometerPhotoPath,
      startOdometerVerifiedAt: startOdometerVerifiedAt ?? this.startOdometerVerifiedAt,
      startOdometerImageHash: startOdometerImageHash ?? this.startOdometerImageHash,
      endOdometerPhotoPath: endOdometerPhotoPath ?? this.endOdometerPhotoPath,
      endOdometerVerifiedAt: endOdometerVerifiedAt ?? this.endOdometerVerifiedAt,
      endOdometerImageHash: endOdometerImageHash ?? this.endOdometerImageHash,
      toolSetupPhotoPath: toolSetupPhotoPath ?? this.toolSetupPhotoPath,
      toolSetupVerifiedAt: toolSetupVerifiedAt ?? this.toolSetupVerifiedAt,
      toolSetupImageHash: toolSetupImageHash ?? this.toolSetupImageHash,
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
      'toolSetupPhotoPath': toolSetupPhotoPath,
      'toolSetupVerifiedAt': toolSetupVerifiedAt?.toIso8601String(),
      'toolSetupImageHash': toolSetupImageHash,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      regoPlate: (json['regoPlate'] ?? json['rego_plate']) as String,
      initialOdometer: ((json['initialOdometer'] ?? json['initial_odometer']) as num).toDouble(),
      engineCapacity: (json['engineCapacity'] ?? json['engine_capacity']) as String?,
      vehicleType: VehicleType.values.firstWhere(
        (v) => v.name == (json['vehicleType'] ?? json['vehicle_type']),
        orElse: () => VehicleType.car,
      ),
      bluetoothDeviceName: (json['bluetoothDeviceName'] ?? json['bluetooth_device_name']) as String?,
      isPrimary: (json['isPrimary'] ?? json['is_primary']) as bool? ?? true,
      taxMethod: TaxMethod.values.firstWhere(
        (t) => t.name == (json['taxMethod'] ?? json['tax_method']),
        orElse: () => TaxMethod.centsPerKm,
      ),
      logbookStartDate: (json['logbookStartDate'] ?? json['logbook_start_date']) != null
          ? DateTime.tryParse((json['logbookStartDate'] ?? json['logbook_start_date']) as String)
          : null,
      clientDedupId: (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null
          ? DateTime.tryParse((json['deletedAt'] ?? json['deleted_at']) as String)
          : null,
      startOdometerPhotoPath: json['startOdometerPhotoPath'] as String?,
      startOdometerVerifiedAt: json['startOdometerVerifiedAt'] != null
          ? DateTime.tryParse(json['startOdometerVerifiedAt'] as String)
          : null,
      startOdometerImageHash: json['startOdometerImageHash'] as String?,
      endOdometerPhotoPath: json['endOdometerPhotoPath'] as String?,
      endOdometerVerifiedAt: json['endOdometerVerifiedAt'] != null
          ? DateTime.tryParse(json['endOdometerVerifiedAt'] as String)
          : null,
      endOdometerImageHash: json['endOdometerImageHash'] as String?,
      toolSetupPhotoPath: json['toolSetupPhotoPath'] as String?,
      toolSetupVerifiedAt: json['toolSetupVerifiedAt'] != null
          ? DateTime.tryParse(json['toolSetupVerifiedAt'] as String)
          : null,
      toolSetupImageHash: json['toolSetupImageHash'] as String?,
    );
  }
}
