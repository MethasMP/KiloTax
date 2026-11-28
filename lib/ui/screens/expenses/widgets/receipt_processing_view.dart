import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';

class ReceiptProcessingView extends StatefulWidget {
  final String? imagePath;
  final String status;
  final double? confidence;
  final bool isLowConfidence;

  const ReceiptProcessingView({
    super.key,
    this.imagePath,
    required this.status,
    this.confidence,
    this.isLowConfidence = false,
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
            if (widget.isLowConfidence ||
                (widget.confidence != null && widget.confidence! < 0.70)) ...[
              Container(
                key: const ValueKey('receipt-processing-low-confidence-banner'),
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColor.attentionTintSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColor.attentionTintStrong, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.warning,
                        size: 18, color: AppColor.attentionStrong),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Low OCR Confidence (<70%)${widget.confidence != null ? " (${(widget.confidence! * 100).round()}%)" : ""}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColor.attentionInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Faded thermal ink or glare detected. Check merchant, date & total carefully before saving.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColor.ink,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
