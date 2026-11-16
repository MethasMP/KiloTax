import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/engine/trip_confidence_classifier.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/home_header_bar.dart';
import '../dashboard/widgets/tax_readiness_card.dart';
import '../dashboard/widgets/home_recent_activity.dart';
import '../dashboard/widgets/account_settings_sheet.dart';
import '../dashboard/widgets/money_left_on_table_card.dart';
import '../dashboard/widgets/home_telemetry_capsule.dart';
import '../trips/widgets/cpk_batch_review_sheet.dart';
import '../home/widgets/scaffold_bottom_nav_bar.dart';
import '../../../core/theme/app_color.dart';

/// Screen 5: Dedicated Home Canvas for Cents-per-Kilometre (CPK) Method
/// Clean Architecture - Zero Odometer Clutter, Zero Personal Trip Noise.
class CpkHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;

  const CpkHomeBody({super.key, required this.appState, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final summary = appState.taxSummary;
    final businessKm = summary.businessKm;
    final maxKm = appState.activeTaxRule.centsPerKmMaxKm;
    final remainingKm = (maxKm - businessKm).clamp(0.0, maxKm);
    final percentage = (businessKm / maxKm).clamp(0.0, 1.0);
    final rateCents = (appState.activeTaxRule.centsPerKmRate * 100).toInt();

    return RefreshIndicator(
      onRefresh: () async {
        await appState.restoreFromCloud();
      },
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, ScaffoldBottomNavBar.clearanceFor(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeHeaderBar(
              appState: appState,
              onAccountTap: () => AccountSettingsSheet.show(context, appState),
            ),
            const SizedBox(height: 14),
            // UI-Taste Bento Hero: Oxford Chronograph Ambiance with Dual-Pill Visual Anchor
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment(-0.8, -0.9),
                  radius: 1.4,
                  colors: [
                    AppColor.navy700, // Deep Oxford Luster
                    AppColor.surfaceNavy,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColor.navy600,
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColor.scrimMedium,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gestalt Common Region Header: Rate & Statutory Cap
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.shieldCheck,
                              size: 14,
                              color: AppColor.positiveBright,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ATO DEDUCTION • $rateCents¢/KM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColor.navy200,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColor.brandBright.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColor.brandBright.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'ESTIMATE',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: AppColor.brandTint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Gestalt Proximity & Closure: Main Metric + 5,000 km Arc Meter
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Formatters.currency(summary.centsPerKmClaim),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.8,
                                  height: 1.05,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColor.positiveBright,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${Formatters.distance(businessKm)} of 5,000 km claimed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColor.navy200,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Tactile 5,000 km Quota Cap Arc/Meter
                      CpkQuotaArcMeter(
                        currentKm: businessKm,
                        maxKm: maxKm,
                        size: 82,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Headroom Chip & Statutory Cap Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        businessKm >= 5000
                            ? '5,000 km limit reached (Claim capped)'
                            : 'ATO 5,000 km annual ceiling',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: businessKm >= 5000
                              ? AppColor.criticalTintStrong
                              : AppColor.navy300,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: businessKm >= 5000
                              ? AppColor.criticalStrong.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: businessKm >= 5000
                                ? AppColor.criticalTintStrong
                                    .withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${remainingKm.toStringAsFixed(0)} km remaining',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: businessKm >= 5000
                                ? AppColor.criticalTintStrong
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // High-Precision Linear Progress Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: Colors.white.withValues(alpha: 0.12),
                      child: LayoutBuilder(
                        builder: (context, bar) {
                          final fill =
                              percentage.clamp(0.0, 1.0) * bar.maxWidth;
                          if (fill <= 0) return const SizedBox.shrink();
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: fill.clamp(6.0, bar.maxWidth),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: businessKm >= 5000
                                      ? const [AppColor.critical, AppColor.criticalStrong]
                                      : const [AppColor.cyan400, AppColor.positiveBright],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TaxReadinessCard(appState: appState),
            // 1-Tap Batch Review Quick Trigger (Gestalt Proximity: Directly beneath Quota Hero)
            if (appState.missingComplianceTrips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final pending = appState.missingComplianceTrips;
                  final readyCount = pending
                      .where((t) =>
                          TripConfidenceClassifier.assess(t).isHighConfidence)
                      .length;
                  final callCount = pending.length - readyCount;

                  final headline = readyCount > 0
                      ? '$readyCount work ${readyCount == 1 ? 'drive' : 'drives'} ready for sign-off'
                      : '$callCount ${callCount == 1 ? 'drive needs' : 'drives need'} your sign-off';

                  final subline = callCount > 0 && readyCount > 0
                      ? '1-Tap claim $readyCount work ${readyCount == 1 ? 'drive' : 'drives'} ($callCount need decision)'
                      : '1-Tap batch claim your work deduction';

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        CpkBatchReviewSheet.show(context, appState);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColor.brandTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColor.brandBright.withValues(alpha: 0.18),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepNavy.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColor.brandTintStrong,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.shieldCheck,
                                  color: AppColor.brandBright, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headline,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColor.brand,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subline,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColor.navy400),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.brand,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                CpkBatchReviewSheet.show(context, appState);
                              },
                              child: const Text('Review',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 14),

            HomeTelemetryCapsule(appState: appState),
            const SizedBox(height: 14),
            // Strategic Advisor: Money Left on the Table
            if (appState.evidenceReview.items.isEmpty)
              MoneyLeftOnTableCard(appState: appState),

            HomeRecentActivity(appState: appState, onViewAll: onViewAll),
          ],
        ),
      ),
    );
  }
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
