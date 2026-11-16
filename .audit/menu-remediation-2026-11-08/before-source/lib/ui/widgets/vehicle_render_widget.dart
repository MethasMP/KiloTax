import 'package:flutter/material.dart';
import '../../data/models/vehicle.dart';
import '../../core/theme/app_color.dart';

/// Presentation widget responsible for rendering vehicle brand monogram badges
/// and clean geometric typography (Apple Wallet / Linear style).
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
    this.silhouetteColor = AppColor.surfaceNavy,
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

  /// High-precision Vector / Icon Monogram
  factory VehicleRenderWidget.silhouette({
    Key? key,
    required VehicleType vehicleType,
    String? make,
    String? model,
    double width = 36,
    double height = 28,
    Color color = AppColor.surfaceNavy,
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
      silhouetteOnly: true,
      silhouetteColor: color,
    );
  }

  /// Studio / Hero Monogram Card
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
    return _buildBrandMonogram();
  }

  Widget _buildBrandMonogram() {
    final effectiveMake = (make ?? '').trim();
    final monogram = _resolveMonogram(effectiveMake, vehicleType);
    final w = width ?? 44;
    final h = height ?? 32;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColor.surfaceNavy,
        borderRadius: BorderRadius.circular(w > 60 ? 14 : 8),
        border: Border.all(
          color: AppColor.navyLine,
          width: 1,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              vehicleType.iconData,
              size: (h * 0.44).clamp(11.0, 20.0),
              color: Colors.white.withValues(alpha: 0.9),
            ),
            if (w >= 48) ...[
              const SizedBox(width: 4),
              Text(
                monogram,
                style: TextStyle(
                  fontSize: (h * 0.36).clamp(10.0, 16.0),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolveMonogram(String make, VehicleType type) {
    if (make.isEmpty) {
      return type.displayName.toUpperCase();
    }
    final upper = make.toUpperCase();
    if (upper.contains('FORD')) return 'FORD';
    if (upper.contains('TOYOTA')) return 'TOYOTA';
    if (upper.contains('ISUZU')) return 'ISUZU';
    if (upper.contains('MITSUBISHI')) return 'MITSU';
    if (upper.contains('TESLA')) return 'TESLA';
    if (upper.contains('HOLDEN')) return 'HOLDEN';
    if (upper.contains('MAZDA')) return 'MAZDA';
    if (upper.contains('HYUNDAI')) return 'HYUNDAI';
    if (upper.contains('NISSAN')) return 'NISSAN';
    if (upper.contains('VOLKSWAGEN') || upper.contains('VW')) return 'VW';
    return upper.length > 6 ? upper.substring(0, 5) : upper;
  }
}
