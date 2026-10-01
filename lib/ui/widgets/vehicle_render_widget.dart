import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../data/models/vehicle.dart';
import 'vehicle_type_ui_extension.dart';

/// Presentation widget responsible for rendering vehicle 3D renders, models, and silhouettes.
/// Decoupled from the Vehicle domain entity.
class VehicleRenderWidget extends StatelessWidget {
  final VehicleType vehicleType;
  final String? make;
  final String? model;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool silhouetteOnly;
  final Color silhouetteColor;

  const VehicleRenderWidget({
    super.key,
    required this.vehicleType,
    this.make,
    this.model,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.silhouetteOnly = false,
    this.silhouetteColor = const Color(0xFF0F172A),
  });

  /// Factory constructor to render directly from a [Vehicle] entity
  factory VehicleRenderWidget.fromVehicle({
    Key? key,
    required Vehicle vehicle,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return VehicleRenderWidget(
      key: key,
      vehicleType: vehicle.effectiveVehicleType,
      make: vehicle.make,
      model: vehicle.model,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Factory constructor for high-precision vector silhouettes
  factory VehicleRenderWidget.silhouette({
    Key? key,
    required VehicleType vehicleType,
    double width = 24,
    double height = 24,
    Color color = const Color(0xFF0F172A),
    BoxFit fit = BoxFit.contain,
  }) {
    return VehicleRenderWidget(
      key: key,
      vehicleType: vehicleType,
      width: width,
      height: height,
      fit: fit,
      silhouetteOnly: true,
      silhouetteColor: color,
    );
  }

  /// Factory constructor for 3D studio transparent cutout renders
  factory VehicleRenderWidget.studio3d({
    Key? key,
    required VehicleType vehicleType,
    String? make,
    String? model,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return VehicleRenderWidget(
      key: key,
      vehicleType: vehicleType,
      make: make,
      model: model,
      width: width,
      height: height,
      fit: fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (silhouetteOnly) {
      return _buildSilhouette();
    }
    return _build3dRender();
  }

  Widget _buildSilhouette() {
    return SvgPicture.asset(
      vehicleType.svgAssetPath,
      width: width,
      height: height,
      fit: fit,
      colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcIn),
      placeholderBuilder: (_) =>
          Icon(vehicleType.iconData, size: height, color: silhouetteColor),
    );
  }

  Widget _build3dRender() {
    String resolvedPath = vehicleType.imageAssetPath;
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
        vehicleType.imageAssetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildSilhouette(),
      ),
    );
  }
}
