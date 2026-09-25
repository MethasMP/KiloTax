import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/tax_summary.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_quick_resolve_sheet.dart';
import '../../trips/trip_review_sheet.dart';
import '../../logbook/logbook_setup_screen.dart';

/// STRATEGIC DIFFERENTIATION ADVISOR:
/// "Money Left on the Table" Advisor Card.
/// Identifies lost or unoptimized tax deductions in real time:
/// 1. Unlogged purposes at risk of ATO audit rejection ($ value)
/// 2. Method Arbitrage (Logbook vs CPK dollar difference)
/// 3. Approaching statutory 5,000 km cap alert
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
        .where((e) => e.isVaultOnly && e.vaultReason == 'cents_per_km_running_cost')
        .length;

    // 1. Calculate lost dollars from missing purposes differentiated by tax method
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
        final potentialPct = (potentialBizKm / summary.totalKm * 100.0).clamp(0.0, 100.0);
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

    // 2. Check method arbitrage opportunity
    final canOptimizeMethod = !isLogbook &&
        summary.recommendedMethod == RecommendedMethod.logbook &&
        summary.taxSavingsDiff >= 150.0;

    // 3. Check 5,000 km cap near-limit (Early warning at 3,500 km or at 5,000 km cap)
    final capNearLimit = !isLogbook && summary.businessKm >= 3500.0;

    // 4. End-of-FY CPK Quota Rescue Monitor (May 15 - June 30): Alert if significant quota ($400+) remains unharvested
    final now = DateTime.now();
    final isYearEndWindow = now.month == 5 && now.day >= 15 || now.month == 6;
    final remainingCapKm = (5000.0 - summary.businessKm).clamp(0.0, 5000.0);
    final yearEndRescueDollars = remainingCapKm * rate;
    final isYearEndRescueActive = !isLogbook &&
        isYearEndWindow &&
        summary.businessKm >= 1500.0 &&
        summary.businessKm < 4900.0 &&
        yearEndRescueDollars >= 200.0;

    // If there's no leak or gap detected, render an encouraging "Audit Proof" badge
    final hasLeak = lostPurposeDollars > 0 ||
        missingTrips.isNotEmpty ||
        canOptimizeMethod ||
        capNearLimit ||
        isYearEndRescueActive ||
        (isLogbook && unclassifiedExpenses.isNotEmpty);

    if (!hasLeak) {
      // Zero clutter: When compliant with no leaks, keep the home canvas clean & breathing.
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Warm amber background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.alertCircle, color: Color(0xFFD97706), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MONEY LEFT ON THE TABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              if (lostPurposeDollars > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${Formatters.currency(lostPurposeDollars)} AT RISK',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Case 1: Unlogged / Missing Purpose Drives
          if (missingTrips.isNotEmpty) ...[
            Text(
              isLogbook
                  ? (lostPurposeDollars > 0
                      ? '${missingTrips.length} drives (${unloggedTripKm.toStringAsFixed(1)} km) are missing a work reason, putting ${Formatters.currency(lostPurposeDollars)} of your logbook claim at risk. Under ATO TR 97/11, undocumented trips will be disqualified in an audit.'
                      : '${missingTrips.length} drives (${unloggedTripKm.toStringAsFixed(1)} km) are missing a work reason. Under ATO TR 97/11, undocumented trips will be disqualified in an audit.')
                  : '${missingTrips.length} drives (${unloggedTripKm.toStringAsFixed(1)} km at ${(rate * 100).toStringAsFixed(0)}c/km) are missing a work reason. Under ATO TR 97/11, undocumented trips will be disqualified in an audit.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF78350F),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                if (missingTrips.isNotEmpty) {
                  TripQuickResolveSheet.show(context, trip: missingTrips.first, appState: appState);
                } else {
                  TripReviewSheet.show(context, appState);
                }
              },
              icon: const Icon(LucideIcons.sparkles, size: 14),
              label: Text(
                lostPurposeDollars > 0
                    ? 'Recover ${Formatters.currency(lostPurposeDollars)} in 1 Tap'
                    : 'Fix ${missingTrips.length} Drives',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Case 2: Method Arbitrage Opportunity (Logbook gives significantly more)
          if (canOptimizeMethod) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.trendingUp, color: AppColors.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Switching to Logbook unlocks +${Formatters.currency(summary.taxSavingsDiff)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vaultCount > 0
                              ? 'Logbook claim is ${Formatters.currency(summary.logbookClaim)} vs ${Formatters.currency(summary.centsPerKmClaim)} under flat rate. Your $vaultCount saved receipts will be included.'
                              : 'Logbook claim is ${Formatters.currency(summary.logbookClaim)} vs ${Formatters.currency(summary.centsPerKmClaim)} under flat rate.',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.workBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LogbookSetupScreen(appState: appState),
                        ),
                      );
                    },
                    child: const Text('Switch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Case 3b: End-of-FY CPK Quota Rescue Alert (May 15 - June 30)
          if (isYearEndRescueActive) ...[
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.calendarClock, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tax Year Ending Soon: ${Formatters.currency(yearEndRescueDollars)} Quota Unharvested',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E40AF),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have ${Formatters.distance(remainingCapKm)} of your 5,000 km allowance remaining before 30 June. Unclaimed quota does not roll over to the next financial year.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Case 3: CPK 5,000 km Cap Strategic Pivot Monitor (Chris Voss Tactical Empathy & Loss Aversion)
          if (capNearLimit) ...[
            Builder(
              builder: (context) {
                final remainingKm = (5000 - summary.businessKm).clamp(0.0, 5000.0).round();
                final isOverCap = summary.businessKm >= 5000;

                final headline = isOverCap
                    ? "You're driving for free right now"
                    : '$remainingKm km until trips earn \$0';

                final body = vaultCount > 0
                    ? (isOverCap
                        ? 'Past 5,000 km, the ATO pays \$0. Don\'t leave your $vaultCount fuel receipts in the glovebox.'
                        : 'The ATO stops paying at 5,000 km. Don\'t leave your $vaultCount fuel receipts in the glovebox.')
                    : (isOverCap
                        ? 'Past 5,000 km, the ATO pays \$0. Don\'t leave 8 fuel receipts in your glovebox.'
                        : 'The ATO stops paying at 5,000 km. Don\'t leave 8 fuel receipts in your glovebox.');

                final buttonLabel = vaultCount > 0
                    ? 'Claim My Fuel'
                    : 'Protect My Claim';

                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.shieldAlert, size: 16, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF991B1B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              body,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LogbookSetupScreen(appState: appState),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      buttonLabel,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
              },
            ),
          ],
        ],
      ),
    );
  }
}
