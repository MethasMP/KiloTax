import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/tax_summary.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_quick_resolve_sheet.dart';
import '../../trips/trip_review_sheet.dart';
import '../../logbook/logbook_setup_screen.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';

/// STRATEGIC DIFFERENTIATION ADVISOR:
/// "Money Left on the Table" Advisor Card.
/// Identifies lost or unoptimized tax deductions in real time:
/// 1. CPK cap near limit/exceeded (Priority 1)
/// 2. Missing purpose drives (Priority 2)
/// 3. Method arbitrage (Priority 3)
/// 4. Year end rescue (Priority 4)
///
/// If multiple conditions apply, displays the single highest-priority alert condition
/// as the primary banner and any secondary actionable opportunities as compact,
/// quiet secondary rows to prevent visual alert card stacking.
enum _AlertPriority {
  cpkCap,
  missingTrips,
  arbitrage,
  yearEndRescue,
}

class MoneyLeftOnTableCard extends StatelessWidget {
  final AppState appState;

  const MoneyLeftOnTableCard({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    if (vehicle == null) return const SizedBox.shrink();

    final isLogbook = vehicle.taxMethod == TaxMethod.logbook;
    final summary = appState.taxSummary;
    final rate = appState.activeTaxRule.centsPerKmRate;
    final missingTrips = appState.missingComplianceTrips;
    final unclassifiedExpenses = appState.unclassifiedExpenses;

    // Vault running expenses safely held during CPK mode
    final vaultCount = appState.expenses
        .where((e) =>
            e.isVaultOnly && e.vaultReason == 'cents_per_km_running_cost')
        .length;

    double unloggedTripKm = 0.0;
    for (final t in missingTrips) {
      unloggedTripKm += t.distanceKm;
    }

    double lostPurposeDollars;
    if (isLogbook) {
      // In Logbook: impact is drop in business % multiplied by actual running expenses
      if (summary.totalRunningExpenses > 0 && summary.totalKm > 0) {
        final currentPct = summary.businessPercentage;
        final potentialBizKm = summary.businessKm + unloggedTripKm;
        final potentialPct =
            (potentialBizKm / summary.totalKm * 100.0).clamp(0.0, 100.0);
        final deltaPct = (potentialPct - currentPct) / 100.0;
        lostPurposeDollars = summary.totalRunningExpenses * deltaPct;
      } else {
        // Without expenses logged, dollar loss cannot be determined from receipts
        lostPurposeDollars = 0.0;
      }
    } else {
      // In Cents per km: each km is worth statutory flat rate (e.g. 91c) up to 5,000 km cap
      final remainingCap = (5000.0 - summary.businessKm).clamp(0.0, 5000.0);
      final claimableUnloggedKm = unloggedTripKm.clamp(0.0, remainingCap);
      lostPurposeDollars = claimableUnloggedKm * rate;
    }

    final capNearLimit = !isLogbook && summary.businessKm >= 3500.0;
    final hasMissingTrips = missingTrips.isNotEmpty;
    final canOptimizeMethod = !isLogbook &&
        summary.recommendedMethod == RecommendedMethod.logbook &&
        summary.taxSavingsDiff >= 150.0;

    final now = DateTime.now();
    final isYearEndWindow = now.month == 5 && now.day >= 15 || now.month == 6;
    final remainingCapKm = (5000.0 - summary.businessKm).clamp(0.0, 5000.0);
    final yearEndRescueDollars = remainingCapKm * rate;
    final isYearEndRescueActive = !isLogbook &&
        isYearEndWindow &&
        summary.businessKm >= 1500.0 &&
        summary.businessKm < 4900.0 &&
        yearEndRescueDollars >= 200.0;

    // Collect all active alert conditions in order of strict priority:
    // 1. CPK cap near limit/exceeded
    // 2. Missing purpose drives
    // 3. Method arbitrage
    // 4. Year end rescue
    final activeAlerts = <_AlertPriority>[];
    if (capNearLimit) {
      activeAlerts.add(_AlertPriority.cpkCap);
    }
    if (hasMissingTrips) {
      activeAlerts.add(_AlertPriority.missingTrips);
    }
    if (canOptimizeMethod) {
      activeAlerts.add(_AlertPriority.arbitrage);
    }
    if (isYearEndRescueActive) {
      activeAlerts.add(_AlertPriority.yearEndRescue);
    }

    // If there's no leak or gap detected, keep home canvas clean
    final hasLeak = activeAlerts.isNotEmpty ||
        (isLogbook && unclassifiedExpenses.isNotEmpty);

    if (!hasLeak) {
      return const SizedBox.shrink();
    }

    final primaryAlert = activeAlerts.isNotEmpty ? activeAlerts.first : null;
    final secondaryAlerts = activeAlerts.length > 1
        ? activeAlerts.sublist(1)
        : const <_AlertPriority>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColor.line,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColor.scrimSoft,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColor.attentionStrong.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.alertCircle,
                          color: AppColor.attentionStrong, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'MONEY LEFT ON THE TABLE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.eyebrow.copyWith(
                          color: AppColor.attentionInk,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (lostPurposeDollars > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColor.criticalStrong.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColor.criticalStrong.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '-${Formatters.currency(lostPurposeDollars)} AT RISK',
                    style: AppType.eyebrow.copyWith(
                      color: AppColor.criticalInk,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Alert Section (Highest Priority)
          if (primaryAlert != null)
            _buildPrimaryAlert(
              context: context,
              alert: primaryAlert,
              summary: summary,
              rate: rate,
              missingTrips: missingTrips,
              unloggedTripKm: unloggedTripKm,
              lostPurposeDollars: lostPurposeDollars,
              isLogbook: isLogbook,
              vaultCount: vaultCount,
              yearEndRescueDollars: yearEndRescueDollars,
              remainingCapKm: remainingCapKm,
            ),

          // Secondary Opportunities (Quiet, Calm Rows)
          if (secondaryAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColor.hairline, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADDITIONAL OPPORTUNITIES',
                    style: AppType.eyebrow.copyWith(
                      color: AppColor.inkSubtle,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...secondaryAlerts.map(
                    (alert) => _buildSecondaryRow(
                      context: context,
                      alert: alert,
                      summary: summary,
                      rate: rate,
                      missingTrips: missingTrips,
                      unloggedTripKm: unloggedTripKm,
                      lostPurposeDollars: lostPurposeDollars,
                      isLogbook: isLogbook,
                      vaultCount: vaultCount,
                      yearEndRescueDollars: yearEndRescueDollars,
                      remainingCapKm: remainingCapKm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryAlert({
    required BuildContext context,
    required _AlertPriority alert,
    required TaxSummary summary,
    required double rate,
    required List<Trip> missingTrips,
    required double unloggedTripKm,
    required double lostPurposeDollars,
    required bool isLogbook,
    required int vaultCount,
    required double yearEndRescueDollars,
    required double remainingCapKm,
  }) {
    switch (alert) {
      case _AlertPriority.cpkCap:
        final remainingKm =
            (5000 - summary.businessKm).clamp(0.0, 5000.0).round();
        final isOverCap = summary.businessKm >= 5000;

        final headline = isOverCap
            ? "You're driving for free right now"
            : '$remainingKm km until trips earn \$0';

        final body = vaultCount > 0
            ? 'You have $vaultCount fuel ${vaultCount == 1 ? 'receipt' : 'receipts'} in the vault. ${isOverCap ? 'Past 5,000 km the ATO pays \$0, so those receipts are now the only way to claim fuel.' : 'Keep them attached to stay audit-ready past the 5,000 km cap.'}'
            : (isOverCap
                ? 'Past 5,000 km the ATO pays \$0, so fuel receipts are the only way to keep claiming. Add your first one.'
                : 'Fuel receipts are what hold up a claim past 5,000 km. Add your first one.');

        final buttonLabel =
            vaultCount > 0 ? 'Claim My Fuel' : 'Protect My Claim';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColor.criticalTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColor.criticalTintStrong),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColor.criticalStrong.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.shieldAlert,
                    size: 16, color: AppColor.criticalStrong),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: AppType.cardTitle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColor.criticalInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: AppType.secondary.copyWith(
                        color: AppColor.criticalInk,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.criticalStrong,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LogbookSetupScreen(appState: appState),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              buttonLabel,
                              style: AppType.secondary.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.arrowRight, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case _AlertPriority.missingTrips:
        final n = missingTrips.length;
        final noun = n == 1 ? 'drive is' : 'drives are';
        final km = unloggedTripKm.toStringAsFixed(1);
        final rateCents = (rate * 100).toStringAsFixed(0);
        final String copy;
        if (isLogbook && lostPurposeDollars > 0) {
          copy =
              '$n $noun ($km km) missing a work reason — that puts ${Formatters.currency(lostPurposeDollars)} of your logbook claim at risk. Trips without a documented purpose can be disallowed in an ATO review.';
        } else if (isLogbook) {
          copy =
              '$n $noun ($km km) missing a work reason. Trips without a documented purpose can be disallowed in an ATO review.';
        } else {
          copy =
              '$n $noun ($km km at $rateCents¢/km) missing a work reason. Add one to keep the deduction.';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy,
              style: AppType.secondary.copyWith(
                color: AppColor.attentionInk,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.attentionStrong,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                if (missingTrips.isNotEmpty) {
                  TripQuickResolveSheet.show(context,
                      trip: missingTrips.first, appState: appState);
                } else {
                  TripReviewSheet.show(context, appState);
                }
              },
              icon: const Icon(LucideIcons.sparkles, size: 14),
              label: Text(
                lostPurposeDollars > 0
                    ? 'Recover ${Formatters.currency(lostPurposeDollars)} in 1 Tap'
                    : 'Fix ${missingTrips.length} Drives',
                style: AppType.secondary.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

      case _AlertPriority.arbitrage:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColor.attentionTintStrong),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.trendingUp,
                  color: AppColor.positive, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switching to Logbook unlocks +${Formatters.currency(summary.taxSavingsDiff)}',
                      style: AppType.cardTitle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColor.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vaultCount > 0
                          ? 'Logbook claim is ${Formatters.currency(summary.logbookClaim)} vs ${Formatters.currency(summary.centsPerKmClaim)} under flat rate. Your $vaultCount saved receipts will be included.'
                          : 'Logbook claim is ${Formatters.currency(summary.logbookClaim)} vs ${Formatters.currency(summary.centsPerKmClaim)} under flat rate.',
                      style: AppType.secondary.copyWith(
                        color: AppColor.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColor.brand,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LogbookSetupScreen(appState: appState),
                    ),
                  );
                },
                child: Text(
                  'Switch',
                  style: AppType.secondary.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColor.brand,
                  ),
                ),
              ),
            ],
          ),
        );

      case _AlertPriority.yearEndRescue:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColor.brandTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColor.navy200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColor.brandBright.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.calendarClock,
                    size: 16, color: AppColor.brandBright),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Year Ending Soon: ${Formatters.currency(yearEndRescueDollars)} Quota Unharvested',
                      style: AppType.cardTitle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColor.brand,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${Formatters.distance(remainingCapKm)} of your 5,000 km allowance remaining before 30 June. Unclaimed quota does not roll over to the next financial year.',
                      style: AppType.secondary.copyWith(
                        color: AppColor.navy600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSecondaryRow({
    required BuildContext context,
    required _AlertPriority alert,
    required TaxSummary summary,
    required double rate,
    required List<Trip> missingTrips,
    required double unloggedTripKm,
    required double lostPurposeDollars,
    required bool isLogbook,
    required int vaultCount,
    required double yearEndRescueDollars,
    required double remainingCapKm,
  }) {
    switch (alert) {
      case _AlertPriority.cpkCap:
        final remainingKm =
            (5000 - summary.businessKm).clamp(0.0, 5000.0).round();
        final isOverCap = summary.businessKm >= 5000;
        final title = isOverCap
            ? 'Statutory 5k km cap reached'
            : '$remainingKm km remaining before 5k cap';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogbookSetupScreen(appState: appState),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColor.hairline),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldAlert,
                      size: 14, color: AppColor.criticalStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: AppType.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColor.ink,
                      ),
                    ),
                  ),
                  Text(
                    'Review',
                    style: AppType.eyebrow.copyWith(
                      color: AppColor.brandBright,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(LucideIcons.chevronRight,
                      size: 13, color: AppColor.brandBright),
                ],
              ),
            ),
          ),
        );

      case _AlertPriority.missingTrips:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (missingTrips.isNotEmpty) {
                TripQuickResolveSheet.show(context,
                    trip: missingTrips.first, appState: appState);
              } else {
                TripReviewSheet.show(context, appState);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColor.hairline),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles,
                      size: 14, color: AppColor.attentionStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${missingTrips.length} drives missing purpose (${lostPurposeDollars > 0 ? Formatters.currency(lostPurposeDollars) : "${unloggedTripKm.toStringAsFixed(1)} km"} at risk)',
                      style: AppType.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColor.ink,
                      ),
                    ),
                  ),
                  Text(
                    'Resolve',
                    style: AppType.eyebrow.copyWith(
                      color: AppColor.attentionStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(LucideIcons.chevronRight,
                      size: 13, color: AppColor.attentionStrong),
                ],
              ),
            ),
          ),
        );

      case _AlertPriority.arbitrage:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogbookSetupScreen(appState: appState),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColor.hairline),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.trendingUp,
                      size: 14, color: AppColor.positiveStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Switching to Logbook unlocks +${Formatters.currency(summary.taxSavingsDiff)}',
                      style: AppType.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColor.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColor.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LogbookSetupScreen(appState: appState),
                        ),
                      );
                    },
                    child: Text(
                      'Switch',
                      style: AppType.secondary.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColor.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _AlertPriority.yearEndRescue:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColor.surfaceSunken,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColor.hairline),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendarClock,
                    size: 14, color: AppColor.brandBright),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Year-end quota: ${Formatters.currency(yearEndRescueDollars)} (${Formatters.distance(remainingCapKm)}) before 30 June',
                    style: AppType.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColor.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

