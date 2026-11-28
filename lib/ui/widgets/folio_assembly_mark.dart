import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';
import '../../core/theme/app_motion.dart';

/// One-shot Folio assembly driven by the welcome screen's existing timeline.
class FolioAssemblyMark extends StatelessWidget {
  final Animation<double> progress;
  final double size;

  const FolioAssemblyMark({
    super.key,
    required this.progress,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'KiloClaim',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: FolioAssemblyPainter(
              progress: progress,
              reduced: AppMotion.reduced(context),
            ),
          ),
        ),
      );
}

/// Geometry mirrors folio-mark.svg; timing never changes layout or the wordmark.
class FolioAssemblyPainter extends CustomPainter {
  final Animation<double> progress;
  final bool reduced;

  FolioAssemblyPainter({required this.progress, this.reduced = false})
      : super(repaint: progress);

  static final List<Path> _planes = [
    Path()
      ..moveTo(43, 9)
      ..quadraticBezierTo(43, 5, 48, 7)
      ..lineTo(103, 27)
      ..quadraticBezierTo(109, 29, 109, 35)
      ..lineTo(109, 91)
      ..lineTo(87, 99)
      ..lineTo(87, 47)
      ..lineTo(43, 31)
      ..close(),
    Path()
      ..moveTo(26, 40)
      ..quadraticBezierTo(26, 36, 31, 38)
      ..lineTo(76, 54)
      ..quadraticBezierTo(81, 56, 81, 61)
      ..lineTo(81, 106)
      ..lineTo(59, 114)
      ..lineTo(59, 73)
      ..lineTo(26, 61)
      ..close(),
    Path()
      ..moveTo(9, 71)
      ..quadraticBezierTo(9, 67, 14, 69)
      ..lineTo(48, 81)
      ..quadraticBezierTo(53, 83, 53, 88)
      ..lineTo(53, 121)
      ..lineTo(13, 106)
      ..quadraticBezierTo(9, 104, 9, 100)
      ..close(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = progress.value * AppMotion.welcome.inMicroseconds;
    final stagger = AppMotion.brandPlaneStagger.inMicroseconds;
    final planeDuration = AppMotion.brandAssembly.inMicroseconds - 2 * stagger;
    final paint = Paint();
    for (var index = 0; index < _planes.length; index++) {
      // Paint back-to-front as in the SVG, while revealing bottom-to-top.
      final delay = (2 - index) * stagger;
      final value = reduced
          ? 1.0
          : AppMotion.enterCurve.transform(
              ((elapsed - delay) / planeDuration).clamp(0.0, 1.0),
            );
      if (value == 0) continue;
      paint.color = AppBrand.vermilion.withValues(alpha: value);
      canvas.save();
      canvas.translate(0, AppMotion.brandAssemblyTravel * (1 - value));
      canvas.scale(size.width / 128, size.height / 128);
      canvas.drawPath(_planes[index], paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FolioAssemblyPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.reduced != reduced;
}
