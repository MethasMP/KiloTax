import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../services/tracking/road_snap_routing_service.dart';

/// Renders an Australian Snapped-Road Route & Trade POI Badge preview
/// Designed for low-latency, zero-battery-drain rendering without heavy map tiles.
class TripRoutePreviewWidget extends StatelessWidget {
  final String? routePolyline;
  final String origin;
  final String destination;
  final double distanceKm;
  final Map<String, dynamic>? detectedPoi;

  const TripRoutePreviewWidget({
    super.key,
    this.routePolyline,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    this.detectedPoi,
  });

  @override
  Widget build(BuildContext context) {
    final hasPolyline = routePolyline != null && routePolyline!.isNotEmpty;
    final decodedPoints = hasPolyline
        ? RoadSnapRoutingService.decodePolyline(routePolyline!)
        : const <({double lat, double lng})>[];
    final merchantName = detectedPoi?['merchantName'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route Visual Container
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColor.surfaceSunken,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                // Real Road-Snap Polyline Visualizer (with geodesic fallback)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SnappedRoadPathPainter(
                      hasPolyline: hasPolyline,
                      points: decodedPoints,
                      strokeColor: AppColors.workBlue,
                    ),
                  ),
                ),
                // Origin Pin
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: _buildPin(label: 'A', isOrigin: true),
                ),
                // Destination Pin
                Positioned(
                  right: 24,
                  top: 24,
                  child: _buildPin(label: 'B', isOrigin: false),
                ),
                // Snapped Badge
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPolyline ? AppColor.positiveTint : AppColor.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasPolyline ? AppColor.positiveTintStrong : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPolyline ? LucideIcons.route : LucideIcons.navigation,
                          size: 12,
                          color: hasPolyline ? AppColor.positiveStrong : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPolyline ? 'Snapped to Asphalt (${distanceKm.toStringAsFixed(1)} km)' : 'Geodesic Route',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hasPolyline ? AppColor.positiveStrong : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Trade POI Context Banner (If detected at stop)
          if (merchantName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColor.brandTint,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.store, size: 16, color: AppColor.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchantName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColor.brand,
                          ),
                        ),
                        const Text(
                          'Recognised Trade Supplier · Review purpose before claiming',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPin({required String label, required bool isOrigin}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isOrigin ? AppColors.emerald : AppColors.deepNavy,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SnappedRoadPathPainter extends CustomPainter {
  final bool hasPolyline;
  final List<({double lat, double lng})> points;
  final Color strokeColor;

  _SnappedRoadPathPainter({
    required this.hasPolyline,
    required this.points,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor.withValues(alpha: 0.55)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    if (points.length >= 2) {
      double minLat = points.first.lat;
      double maxLat = points.first.lat;
      double minLng = points.first.lng;
      double maxLng = points.first.lng;
      for (final p in points) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
      }

      const padX = 37.0;
      const padY = 28.0;
      final drawW = (size.width - padX * 2).clamp(1.0, size.width);
      final drawH = (size.height - padY * 2).clamp(1.0, size.height);
      final dLng = maxLng - minLng;
      final dLat = maxLat - minLat;

      Offset project(({double lat, double lng}) p) {
        final nx = dLng > 1e-7 ? (p.lng - minLng) / dLng : 0.5;
        final ny = dLat > 1e-7 ? (p.lat - minLat) / dLat : 0.5;
        return Offset(
          padX + nx * drawW,
          padY + (1.0 - ny) * drawH,
        );
      }

      final first = project(points.first);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < points.length; i++) {
        final pt = project(points[i]);
        path.lineTo(pt.dx, pt.dy);
      }
    } else if (hasPolyline) {
      path.moveTo(37, size.height - 37);
      path.cubicTo(
        size.width * 0.3,
        size.height * 0.8,
        size.width * 0.6,
        size.height * 0.2,
        size.width - 37,
        37,
      );
    } else {
      path.moveTo(37, size.height - 37);
      path.lineTo(size.width - 37, 37);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SnappedRoadPathPainter oldDelegate) =>
      oldDelegate.hasPolyline != hasPolyline ||
      oldDelegate.points.length != points.length ||
      oldDelegate.strokeColor != strokeColor;
}
