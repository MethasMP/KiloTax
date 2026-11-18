import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_color.dart';
import '../../../state/app_state.dart';
import '../dashboard/task_home_body.dart';

class CpkHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  final VoidCallback? onReviewTrips;
  final VoidCallback? onViewTax;
  const CpkHomeBody(
      {super.key,
      required this.appState,
      this.onViewAll,
      this.onReviewTrips,
      this.onViewTax});
  @override
  Widget build(BuildContext context) => TaskHomeBody(
      appState: appState,
      onViewAll: onViewAll,
      onReviewTrips: onReviewTrips,
      onViewTax: onViewTax);
}

/// Tactile 5,000 km Quota Cap Arc / Meter Gauge
/// Visualizes the legal ATO ceiling via Gestalt Closure & radial sweep.
class CpkQuotaArcMeter extends StatelessWidget {
  final double currentKm;
  final double maxKm;
  final double size;

  const CpkQuotaArcMeter({
    super.key,
    required this.currentKm,
    required this.maxKm,
    this.size = 78,
  });

  @override
  Widget build(BuildContext context) {
    final clampedKm = currentKm.clamp(0.0, maxKm);
    final ratio = maxKm > 0 ? (clampedKm / maxKm).clamp(0.0, 1.0) : 0.0;
    final isCapReached = currentKm >= maxKm;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CpkQuotaArcPainter(
              percentage: ratio,
              trackColor: Colors.white.withValues(alpha: 0.12),
              progressColors: isCapReached
                  ? const [AppColor.red400, AppColor.criticalStrong]
                  : const [AppColor.cyan400, AppColor.positiveBright],
              strokeWidth: 7.0,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ratio * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'OF CAP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColor.onNavyMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CpkQuotaArcPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final List<Color> progressColors;
  final double strokeWidth;

  const _CpkQuotaArcPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (percentage > 0) {
      final activeSweep = sweepAngle * percentage.clamp(0.0, 1.0);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: progressColors,
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        activeSweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CpkQuotaArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
