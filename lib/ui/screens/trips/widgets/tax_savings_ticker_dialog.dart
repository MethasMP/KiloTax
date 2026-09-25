import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';

/// SIGNATURE KILLER INTERACTION:
/// Tax Savings Ticker Dialog providing immediate positive emotional reinforcement
/// showing the exact dollar value gained towards tax deductions.
class TaxSavingsTickerDialog extends StatelessWidget {
  final double tripDistanceKm;
  final double incrementalClaim;
  final double totalFyClaim;
  final bool isLogbook;
  final bool bulkyToolsCarried;
  final String tipText;
  final VoidCallback? onDismiss;

  const TaxSavingsTickerDialog({
    super.key,
    required this.tripDistanceKm,
    required this.incrementalClaim,
    required this.totalFyClaim,
    required this.isLogbook,
    this.bulkyToolsCarried = false,
    required this.tipText,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required double tripDistanceKm,
    required AppState appState,
    bool bulkyToolsCarried = false,
  }) {
    final vehicle = appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;
    final rate = appState.activeTaxRule.centsPerKmRate;
    final summary = appState.taxSummary;

    double incremental;
    if (isLogbook) {
      // In Logbook, every km contributes to business percentage of vehicle running expenses
      final currentRunning = summary.totalRunningExpenses;
      final newTotalKm = summary.totalKm + tripDistanceKm;
      final newBusinessKm = summary.businessKm + tripDistanceKm;
      final newPct = (newBusinessKm / (newTotalKm > 0 ? newTotalKm : 1.0)) * 100.0;
      final newClaim = (currentRunning * (newPct / 100.0)) + summary.totalDirectDeductions;
      incremental = (newClaim - summary.logbookClaim).clamp(0.0, 9999.0);
      if (incremental <= 0.0) {
        // Baseline estimate if no expenses yet: default to statutory rate proxy
        incremental = tripDistanceKm * rate;
      }
    } else {
      // CPK: min(dist, remaining cap) * rate
      final remainingKm = (appState.activeTaxRule.centsPerKmMaxKm - summary.businessKm).clamp(0.0, appState.activeTaxRule.centsPerKmMaxKm);
      final eligibleDist = tripDistanceKm > remainingKm ? remainingKm : tripDistanceKm;
      incremental = eligibleDist * rate;
    }

    final totalClaim = isLogbook ? summary.logbookClaim : summary.centsPerKmClaim;

    String smartTip;
    if (bulkyToolsCarried) {
      smartTip = 'Bulky tools exemption claimed (ITAA 1997 s 8-1). Home-to-work trip validated for ATO.';
    } else if (!isLogbook && summary.businessKm + tripDistanceKm >= 4500) {
      smartTip = 'You are nearing the 5,000 km statutory CPK cap. Consider switching to Logbook for unlimited claims.';
    } else if (isLogbook && summary.taxSavingsDiff > 200) {
      smartTip = 'Logbook is currently saving you ${Formatters.currency(summary.taxSavingsDiff)} more than Cents-per-km.';
    } else {
      smartTip = 'Contemporaneous drive entry secured in your encrypted audit ledger.';
    }

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TaxSavingsTickerDialog(
        tripDistanceKm: tripDistanceKm,
        incrementalClaim: incremental,
        totalFyClaim: totalClaim + incremental,
        isLogbook: isLogbook,
        bulkyToolsCarried: bulkyToolsCarried,
        tipText: smartTip,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.emeraldLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.check, color: AppColors.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRIP RECORDED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${tripDistanceKm.toStringAsFixed(1)} km Work Drive',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // HERO DOPAMINE PAYOFF BOX
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepNavy, Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Tax Deduction Added',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ATO D1',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '+${Formatters.currency(incrementalClaim)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AUD',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FY26 Total Claim to Date',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        Formatters.currency(totalFyClaim),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SMART TIP / ATO INSIGHT
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.lightbulb, size: 16, color: AppColors.workBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tipText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CLOSE BUTTON
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
