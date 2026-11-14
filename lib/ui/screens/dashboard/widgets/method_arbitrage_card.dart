import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Milestone comparison card presenting method arbitrage opportunity.
/// Progressive disclosure:
/// - Hidden if businessKm < 4,000 km or logbook advantage < $250.
/// - Informs tradies when switching to Logbook method yields higher tax deduction.
///
/// Ergonomic & Anti-Slop:
/// - High-craft Split Telemetry Gauge comparing CPK (Capped) vs Logbook (Uncapped).
/// - Surface: AppColor.surface with clean AppColor.line border (WCAG AAA daylight contrast).
/// - Minimum tap target >= 48x48 pt.
/// - Motion tokens: AppMotion.pressScale (0.972), AppHaptic.light().
class MethodArbitrageCard extends StatefulWidget {
  final double businessKm;
  final double centsPerKmClaim;
  final double logbookClaim;
  final double thresholdDelta;
  final VoidCallback? onExplore;
  final VoidCallback? onDismiss;
  final bool isDark;

  const MethodArbitrageCard({
    super.key,
    required this.businessKm,
    required this.centsPerKmClaim,
    required this.logbookClaim,
    this.thresholdDelta = 250.0,
    this.onExplore,
    this.onDismiss,
    this.isDark = false,
  });

  @override
  State<MethodArbitrageCard> createState() => _MethodArbitrageCardState();
}

class _MethodArbitrageCardState extends State<MethodArbitrageCard> {
  bool _dismissedLocally = false;

  void _dismiss() {
    AppHaptic.light();
    setState(() {
      _dismissedLocally = true;
    });
    widget.onDismiss?.call();
  }

  static String _formatDigits(double value) {
    final rounded = value.round();
    return rounded.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  static String _formatAud(double value) => '\$${_formatDigits(value)}';

  static String _formatKm(double km) => '${_formatDigits(km)} km';

  @override
  Widget build(BuildContext context) {
    if (_dismissedLocally) {
      return const SizedBox.shrink();
    }

    final delta = widget.logbookClaim - widget.centsPerKmClaim;
    final isEligible = widget.businessKm >= 4000.0 && delta >= widget.thresholdDelta;

    if (!isEligible) {
      return const SizedBox.shrink();
    }

    final deltaDigits = _formatDigits(delta);
    final deltaText = '+\$$deltaDigits Difference';

    // Estimated net cash in pocket at Australian tradie typical 32% marginal tax rate
    final estCashRefund = _formatDigits(delta * 0.32);

    final cpkKm = widget.businessKm > 5000.0 ? 5000.0 : widget.businessKm;
    final cpkDisplay = '${_formatKm(cpkKm)} | ${_formatAud(widget.centsPerKmClaim)} Cap';
    final logbookDisplay =
        '${_formatKm(widget.businessKm)} | ${_formatAud(widget.logbookClaim)} Est';

    final maxClaim = math.max(widget.logbookClaim, widget.centsPerKmClaim);
    final cpkFraction =
        maxClaim > 0 ? (widget.centsPerKmClaim / maxClaim).clamp(0.05, 1.0) : 0.5;
    final logbookFraction =
        maxClaim > 0 ? (widget.logbookClaim / maxClaim).clamp(0.05, 1.0) : 1.0;

    final cardBg = widget.isDark ? AppColor.surfaceNavy : AppColor.surface;
    final borderColor = widget.isDark ? AppColor.navyLine : AppColor.line;
    final titleColor = widget.isDark ? AppColor.onNavy : AppColor.ink;
    final microLabelColor = widget.isDark ? AppColor.onNavyMuted : AppColor.inkSubtle;
    final positiveHighlightColor =
        widget.isDark ? AppColor.positiveBright : AppColor.positiveInk;

    final pillBg =
        widget.isDark ? AppColor.positiveBright.withValues(alpha: 0.18) : AppColor.positiveTintStrong;
    final pillTextColor = widget.isDark ? AppColor.positiveBright : AppColor.positiveInk;
    final pillBorderColor = widget.isDark
        ? AppColor.positiveBright.withValues(alpha: 0.35)
        : AppColor.positiveStrong.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                  color: AppColor.ink.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColor.positiveBright.withValues(alpha: 0.15)
                      : AppColor.positiveTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.gauge,
                  size: 18,
                  color: positiveHighlightColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'METHOD ARBITRAGE',
                      style: AppType.eyebrow.copyWith(
                        color: microLabelColor,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Claim Comparison Telemetry',
                      style: AppType.cardTitle.copyWith(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Dismiss',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: microLabelColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Center Callout Badge: High-contrast delta pill + Dopamine Net Refund Callout
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pillBorderColor, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.trendingUp,
                        size: 16,
                        color: pillTextColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deltaText,
                        style: AppType.metricSmall.copyWith(
                          color: pillTextColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '~\$$estCashRefund est. cash back in pocket (at 32% marginal rate)',
                  style: AppType.secondary.copyWith(
                    color: positiveHighlightColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dual-Track Comparison Widget (Split Telemetry Gauge)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColor.navyRaised : AppColor.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDark ? AppColor.navyLine : AppColor.hairline,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: CPK (Capped @ 5,000 km)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CPK (Capped @ 5,000 km)',
                            style: AppType.eyebrow.copyWith(
                              color: microLabelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cpkDisplay,
                            style: AppType.cardNumeric.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: widget.isDark ? AppColor.navyLine : AppColor.hairline,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    // Right side: Logbook (Uncapped)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logbook (Uncapped)',
                            style: AppType.eyebrow.copyWith(
                              color: positiveHighlightColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            logbookDisplay,
                            style: AppType.cardNumeric.copyWith(
                              color: positiveHighlightColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Dual Telemetry Gauge Tracks
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        'CPK',
                        style: AppType.eyebrow.copyWith(
                          color: microLabelColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ComparisonTrack(
                        fraction: cpkFraction,
                        fillColor: widget.isDark ? AppColor.navyLine : AppColor.line,
                        trackColor:
                            widget.isDark ? AppColor.surfaceNavy : AppColor.surfaceMuted,
                        isCapped: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        'LOG',
                        style: AppType.eyebrow.copyWith(
                          color: positiveHighlightColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ComparisonTrack(
                        fraction: logbookFraction,
                        fillColor: positiveHighlightColor,
                        trackColor:
                            widget.isDark ? AppColor.surfaceNavy : AppColor.positiveTint,
                        isCapped: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: _ArbitragePressableButton(
                  label: 'Unlock Logbook',
                  isPrimary: true,
                  isDark: widget.isDark,
                  onTap: () {
                    AppHaptic.light();
                    widget.onExplore?.call();
                  },
                ),
              ),
              const SizedBox(width: 8),
              _ArbitragePressableButton(
                label: 'Keep Cents/km',
                isPrimary: false,
                isDark: widget.isDark,
                onTap: _dismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonTrack extends StatelessWidget {
  final double fraction;
  final Color fillColor;
  final Color trackColor;
  final bool isCapped;

  const _ComparisonTrack({
    required this.fraction,
    required this.fillColor,
    required this.trackColor,
    required this.isCapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ),
          if (isCapped && fraction < 0.96)
            Align(
              alignment: Alignment(fraction * 2 - 1, 0),
              child: Container(
                width: 2,
                height: 7,
                color: AppColor.line,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArbitragePressableButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback onTap;

  const _ArbitragePressableButton({
    required this.label,
    required this.isPrimary,
    this.isDark = false,
    required this.onTap,
  });

  @override
  State<_ArbitragePressableButton> createState() => _ArbitragePressableButtonState();
}

class _ArbitragePressableButtonState extends State<_ArbitragePressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.press,
      reverseDuration: AppMotion.release,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppMotion.pressScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.pressIn,
        reverseCurve: AppMotion.settle,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary
        ? AppColor.brand
        : (widget.isDark ? AppColor.surfaceNavy : AppColor.surfaceMuted);

    final textColor = widget.isPrimary
        ? Colors.white
        : (widget.isDark ? AppColor.onNavy : AppColor.ink);

    final borderColor = widget.isPrimary
        ? Colors.transparent
        : (widget.isDark ? AppColor.navyLine : AppColor.line);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        borderRadius: BorderRadius.circular(10),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 48,
              minWidth: 48,
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Text(
                widget.label,
                style: AppType.bodyStrong.copyWith(
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
