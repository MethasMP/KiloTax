import 'package:flutter/material.dart';

import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/audit/contemporaneous_sla_service.dart';
import '../../../services/evidence/ghost_trip_detector.dart';
import '../../../services/tracking/odometer_calibration_engine.dart';
import '../../../services/tracking/tracking_watchdog_service.dart';

/// Standalone ATO Audit Shield & Compliance Dashboard Sheet (Axis B + C).
/// Surfaces:
/// - 7-Day Contemporaneous SLA (CR 2026/71 para 14) & 12-week stability
/// - Odometer Calibration Drift (CR 2021/16 para 35)
/// - Fuel-to-Km Plausibility Band (labeled as estimate)
/// - Receipt-Triggered Ghost Trip Candidates
/// - Silent-Death Watchdog & OEM Battery Checklist
class AtoAuditShieldSheet extends StatelessWidget {
  final ContemporaneousScoreReport slaReport;
  final RepresentativeWindowReport? windowReport;
  final OdometerCalibrationResult calibrationResult;
  final FuelPlausibilityResult fuelPlausibility;
  final List<GhostTripCandidate> ghostTrips;
  final WatchdogReport watchdogReport;
  final ValueChanged<GhostTripCandidate>? onRecoverGhostTrip;

  const AtoAuditShieldSheet({
    super.key,
    required this.slaReport,
    this.windowReport,
    required this.calibrationResult,
    required this.fuelPlausibility,
    required this.ghostTrips,
    required this.watchdogReport,
    this.onRecoverGhostTrip,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.canvas,
          borderRadius: R.sheetTopR,
        ),
        padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: R.chipR,
                  ),
                ),
              ),
              const SizedBox(height: S.lg),
              Row(
                children: [
                  const Icon(
                    AppIcons.tax,
                    color: AppColor.brand,
                    size: AppIconSize.navigation,
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text('ATO Audit Shield', style: AppType.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close, size: AppIconSize.control),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: S.xs),
              Text(
                'Substantiation readiness checks (advisory only — not an ATO ruling).',
                style: AppType.secondary,
              ),
              const SizedBox(height: S.lg),

              // 1. 7-Day Contemporaneous SLA (CR 2026/71)
              _ShieldSectionCard(
                title: '7-Day Contemporaneous SLA (CR 2026/71)',
                badgeText:
                    '${slaReport.integrityScorePercent.toStringAsFixed(0)}% Score',
                isAlert: slaReport.breachedCount > 0,
                body:
                    '${slaReport.confirmedWithin7DaysCount} confirmed within 7d • '
                    '${slaReport.pendingWithin7DaysCount} pending • '
                    '${slaReport.breachedCount} overdue (>7d)',
                extra: windowReport?.advisoryMessage,
              ),
              const SizedBox(height: S.md),

              // 2. Odometer Calibration & Drift (CR 2021/16)
              _ShieldSectionCard(
                title: 'Dashboard-Odometer Parity (CR 2021/16)',
                badgeText:
                    '${calibrationResult.calibrationFactor.toStringAsFixed(3)}x',
                isAlert: calibrationResult.requiresRecalibrationAlert,
                body: calibrationResult.advisoryMessage,
              ),
              const SizedBox(height: S.md),

              // 3. Fuel-to-Km Plausibility
              _ShieldSectionCard(
                title: 'Fuel-to-Km Plausibility (Estimate)',
                badgeText: fuelPlausibility.statusLabel,
                isAlert: fuelPlausibility.hasSufficientData &&
                    !fuelPlausibility.isPlausible,
                body: fuelPlausibility.advisoryMessage,
              ),
              const SizedBox(height: S.md),

              // 4. Ghost Trip Detector
              _ShieldSectionCard(
                title: 'Receipt-Triggered Ghost Trips',
                badgeText: '${ghostTrips.length} Found',
                isAlert: ghostTrips.isNotEmpty,
                body: ghostTrips.isEmpty
                    ? 'All fuel and trade receipts match logged trips within ±45 min.'
                    : ghostTrips.first.promptText,
                actionLabel:
                    ghostTrips.isNotEmpty && onRecoverGhostTrip != null
                        ? 'Recover Drive'
                        : null,
                onAction: ghostTrips.isNotEmpty && onRecoverGhostTrip != null
                    ? () => onRecoverGhostTrip!(ghostTrips.first)
                    : null,
              ),
              const SizedBox(height: S.md),

              // 5. Silent-Death Watchdog
              _ShieldSectionCard(
                title: watchdogReport.oemGuidanceTitle,
                badgeText: watchdogReport.status == WatchdogHealthStatus.healthy
                    ? 'Healthy'
                    : 'Action Needed',
                isAlert: watchdogReport.status != WatchdogHealthStatus.healthy,
                body: watchdogReport.recommendedBannerMessage,
                extra: watchdogReport.oemGuidanceSteps.isNotEmpty
                    ? watchdogReport.oemGuidanceSteps.map((s) => '• $s').join('\n')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldSectionCard extends StatelessWidget {
  final String title;
  final String badgeText;
  final bool isAlert;
  final String body;
  final String? extra;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ShieldSectionCard({
    required this.title,
    required this.badgeText,
    required this.isAlert,
    required this.body,
    this.extra,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBg = isAlert ? AppColor.attentionTint : AppColor.positiveTint;
    final badgeInk = isAlert ? AppColor.attentionInk : AppColor.positiveInk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.lg),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: R.cardR,
        border: AppElevation.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppType.cardTitle)),
              const SizedBox(width: S.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: S.sm,
                  vertical: S.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: R.chipR,
                ),
                child: Text(
                  badgeText,
                  style: AppType.eyebrow.copyWith(color: badgeInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: S.sm),
          Text(body, style: AppType.body),
          if (extra != null) ...[
            const SizedBox(height: S.sm),
            Text(extra!, style: AppType.secondary),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: S.md),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: R.controlR),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
