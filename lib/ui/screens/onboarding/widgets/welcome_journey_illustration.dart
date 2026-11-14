import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';

/// Decorative explanation: a journey becomes a record ready for review.
/// The caller controls the single entrance; no loop or independent ticker.
class WelcomeJourneyIllustration extends StatelessWidget {
  final Animation<double> progress;
  const WelcomeJourneyIllustration({super.key, required this.progress});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 224,
          height: 144,
          decoration: BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColor.hairline),
          ),
          child: CustomPaint(painter: _JourneyPainter(progress)),
        ),
      );
}

class _JourneyPainter extends CustomPainter {
  final Animation<double> progress;
  _JourneyPainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 224, size.height / 144);
    final route = Path()
      ..moveTo(28, 103)
      ..lineTo(56, 103)
      ..cubicTo(83, 103, 65, 42, 98, 42)
      ..lineTo(121, 42)
      ..cubicTo(145, 42, 126, 93, 155, 93)
      ..lineTo(172, 93);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, stroke..color = AppColor.surfaceSunken);
    final metric = route.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress.value),
        stroke..color = AppColor.brand);
    canvas.drawCircle(
        const Offset(28, 103), 6, Paint()..color = AppColor.brand);
    final record = RRect.fromRectAndRadius(
        const Rect.fromLTWH(165, 61, 40, 54), const Radius.circular(8));
    canvas.drawRRect(record, Paint()..color = AppColor.surface);
    canvas.drawRRect(
        record,
        Paint()
          ..color = AppColor.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawLine(
        const Offset(175, 73),
        const Offset(192, 73),
        stroke
          ..color = AppColor.line
          ..strokeWidth = 3);
    final check = Path()
      ..moveTo(175, 91)
      ..lineTo(182, 98)
      ..lineTo(195, 84);
    final checkMetric = check.computeMetrics().first;
    final completion = ((progress.value - 0.7) / 0.3).clamp(0.0, 1.0);
    canvas.drawPath(
        checkMetric.extractPath(0, checkMetric.length * completion),
        stroke
          ..color = AppColor.positive
          ..strokeWidth = 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JourneyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
