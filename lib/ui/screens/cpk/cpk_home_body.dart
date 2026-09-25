import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/engine/trip_confidence_classifier.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/home_header_bar.dart';
import '../dashboard/widgets/home_recent_activity.dart';
import '../dashboard/widgets/account_settings_sheet.dart';
import '../dashboard/widgets/money_left_on_table_card.dart';
import '../dashboard/widgets/home_telemetry_capsule.dart';
import '../trips/widgets/cpk_batch_review_sheet.dart';

/// Screen 5: Dedicated Home Canvas for Cents-per-Kilometre (CPK) Method
/// Clean Architecture - Zero Odometer Clutter, Zero Personal Trip Noise.
class CpkHomeBody extends StatelessWidget {
  final AppState appState;

  const CpkHomeBody({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    final summary = appState.taxSummary;
    final businessKm = summary.businessKm;
    final maxKm = appState.activeTaxRule.centsPerKmMaxKm;
    final remainingKm = (maxKm - businessKm).clamp(0.0, maxKm);
    final percentage = (businessKm / maxKm).clamp(0.0, 1.0);
    final rateCents = (appState.activeTaxRule.centsPerKmRate * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (Universal Greeting & Vehicle)
          HomeHeaderBar(
            appState: appState,
            onAccountTap: () => AccountSettingsSheet.show(context, appState),
          ),
          const SizedBox(height: 14),

          // 2. Frontier Ambient Telemetry & Dynamic Drive Capsule
          HomeTelemetryCapsule(appState: appState),

          // 1-Tap Batch Review Quick Trigger (Muse Confidence Partitioning)
          if (appState.missingComplianceTrips.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final pending = appState.missingComplianceTrips;
                final readyCount = pending
                    .where((t) => TripConfidenceClassifier.assess(t).isHighConfidence)
                    .length;
                final callCount = pending.length - readyCount;

                final headline = readyCount > 0
                    ? '$readyCount work drives ready for sign-off'
                    : '$callCount drives need your sign-off';

                final subline = callCount > 0 && readyCount > 0
                    ? '1-Tap claim +$readyCount work drives ($callCount need decision)'
                    : '1-Tap batch claim your work deduction';

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.sparkles, color: Color(0xFF2563EB), size: 18),
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
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subline,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          CpkBatchReviewSheet.show(context, appState);
                        },
                        child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Strategic Advisor: Money Left on the Table
          MoneyLeftOnTableCard(appState: appState),

          // 2. CPK Tax Shield Hero Card (5,000 km Statutory Quota)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepNavy.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean Header: Deduction Title & 91¢/km Rate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ESTIMATED TAX DEDUCTION • $rateCents¢/KM',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (vehicle?.regoPlate != null &&
                        vehicle!.regoPlate.isNotEmpty &&
                        vehicle.regoPlate != 'No Plate')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          vehicle.regoPlate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Hero Dollar Figure
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      Formatters.currency(summary.centsPerKmClaim),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AUD',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.muted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Distance Progress & Remaining
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${Formatters.distance(businessKm)} of 5,000 km claimed',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: businessKm >= 5000 ? AppColors.crimsonLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${remainingKm.toStringAsFixed(0)} km left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: businessKm >= 5000 ? AppColors.crimson : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      businessKm >= 5000 ? AppColors.crimson : AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 3. Evidence Activity Stream
          HomeRecentActivity(appState: appState),
        ],
      ),
    );
  }
}
