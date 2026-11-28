import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';

/// Local examples only: exploring this preview never writes user records.
class WelcomeTripPreview extends StatefulWidget {
  final Animation<double>? progress;
  const WelcomeTripPreview({super.key, this.progress});
  @override
  State<WelcomeTripPreview> createState() => _WelcomeTripPreviewState();
}

class _WelcomeTripPreviewState extends State<WelcomeTripPreview> {
  bool _receipt = false;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: const Color(0xFFF0EDE6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: largeText ? 88 : 136,
              child: Stack(children: [
                Positioned.fill(
                    child: ExcludeSemantics(
                  child: CustomPaint(
                      painter: _RouteArtwork(
                          progress: widget.progress, receipt: _receipt)),
                )),
                Positioned(
                  top: 16,
                  left: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: AppColor.canvas,
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text('INTERACTIVE EXAMPLE',
                          style: AppType.eyebrow.copyWith(fontSize: 10)),
                    ),
                  ),
                ),
              ]),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColor.surfaceNavy,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(
                          _receipt
                              ? Icons.receipt_long_outlined
                              : Icons.route_outlined,
                          color: AppColor.onNavyMuted,
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              _receipt
                                  ? 'EXAMPLE RECEIPT'
                                  : 'EXAMPLE WORK TRIP',
                              style: AppType.eyebrow
                                  .copyWith(color: AppColor.onNavyMuted))),
                    ]),
                    const SizedBox(height: 12),
                    Text(_receipt ? r'$86.40' : '24.6 km',
                        style: AppType.title.copyWith(color: AppColor.onNavy)),
                    const SizedBox(height: 8),
                    Text(
                        _receipt
                            ? 'Fuel receipt · ready to check'
                            : 'Workshop → Customer site',
                        style: AppType.secondary
                            .copyWith(color: AppColor.onNavyMuted)),
                  ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColor.brandTint
                  : AppColor.canvas),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColor.brand
                  : AppColor.ink),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          textStyle: WidgetStatePropertyAll(AppType.secondary.copyWith(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontWeight: FontWeight.w600)),
        ),
        segments: const [
          ButtonSegment(value: false, label: Text('Work trip')),
          ButtonSegment(value: true, label: Text('Receipt')),
        ],
        selected: {_receipt},
        onSelectionChanged: (selection) =>
            setState(() => _receipt = selection.single),
      ),
    ]);
  }
}

class _RouteArtwork extends CustomPainter {
  final Animation<double>? progress;
  final bool receipt;
  _RouteArtwork({this.progress, this.receipt = false})
      : super(repaint: progress);
  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()
      ..color = AppColor.canvas
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;
    for (final fraction in [.15, .52, .88]) {
      canvas.drawLine(Offset(size.width * fraction, -20),
          Offset(size.width * (fraction + .12), size.height + 20), street);
    }
    canvas.drawLine(Offset(0, size.height * .68),
        Offset(size.width, size.height * .32), street);
    final start = Offset(size.width * .16, size.height * .75);
    final end = Offset(size.width * .84, size.height * .36);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * .44, size.height * .9, size.width * .5,
          size.height * .08, end.dx, end.dy);
    final metric = route.computeMetrics().first;
    final value =
        Curves.easeOutCubic.transform((progress?.value ?? 1).clamp(0, 1));
    canvas.drawPath(
        metric.extractPath(0, metric.length * value),
        Paint()
          ..color = AppColor.brandBright
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    for (final point in [start, end]) {
      canvas.drawCircle(point, 9, Paint()..color = AppColor.canvas);
      canvas.drawCircle(point, 5, Paint()..color = AppColor.brand);
    }
    if (receipt) {
      final paper = Rect.fromCenter(
          center: Offset(size.width * .66, size.height * .57),
          width: 72,
          height: size.height * .75);
      canvas.drawRRect(RRect.fromRectAndRadius(paper, const Radius.circular(8)),
          Paint()..color = AppColor.surface);
      final ink = Paint()
        ..color = AppColor.line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final y in [.25, .42, .59]) {
        canvas.drawLine(Offset(paper.left + 14, paper.top + paper.height * y),
            Offset(paper.right - 14, paper.top + paper.height * y), ink);
      }
      canvas.drawLine(
          Offset(paper.left + 14, paper.bottom - 14),
          Offset(paper.right - 28, paper.bottom - 14),
          ink..color = AppColor.brandBright);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteArtwork oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.receipt != receipt;
}
