import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';

class ReceiptProcessingView extends StatefulWidget {
  final String? imagePath;
  final String status;

  const ReceiptProcessingView({
    super.key,
    this.imagePath,
    required this.status,
  });

  @override
  State<ReceiptProcessingView> createState() => _ReceiptProcessingViewState();
}

class _ReceiptProcessingViewState extends State<ReceiptProcessingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reducedMotion) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  Widget _previewFallback() => const Center(
        child: Icon(AppIcons.expenses, size: 64, color: AppColor.inkMuted),
      );

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        liveRegion: true,
        label: widget.status,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('READING YOUR RECEIPT', style: AppType.eyebrow),
            const SizedBox(height: 16),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 280,
                  child: ColoredBox(
                    color: AppColor.surfaceMuted,
                    child: Stack(fit: StackFit.expand, children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: widget.imagePath == null
                            ? _previewFallback()
                            : Image.file(
                                File(widget.imagePath!),
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) =>
                                    _previewFallback(),
                              ),
                      ),
                      if (!_reducedMotion)
                        ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: _sweep,
                            builder: (_, __) => CustomPaint(
                              key: const ValueKey('receipt-reading-sweep'),
                              painter: _ReceiptSweepPainter(_sweep.value),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ExcludeSemantics(
              child: Text(widget.status,
                  style: AppType.section, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next, check the shop, date and total. You can edit the details before saving.',
              style: AppType.secondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.edit_outlined, size: 16, color: AppColor.inkMuted),
              SizedBox(width: 8),
              Flexible(
                child: Text('Nothing is saved as an expense yet',
                    style: AppType.secondary, textAlign: TextAlign.center),
              ),
            ]),
          ],
        ),
      );
}

class _ReceiptSweepPainter extends CustomPainter {
  final double phase;
  const _ReceiptSweepPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final y = 20 + (size.height - 40) * phase;
    final glow = Rect.fromLTWH(0, y - 26, size.width, 52);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColor.brand.withValues(alpha: 0),
            AppColor.brand.withValues(alpha: .10),
            AppColor.brand.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    canvas.drawLine(
      Offset(16, y),
      Offset(size.width - 16, y),
      Paint()
        ..color = AppColor.brand.withValues(alpha: .65)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ReceiptSweepPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
