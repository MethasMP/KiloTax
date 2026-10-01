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
  final VoidCallback? onViewAll;

  const CpkHomeBody({super.key, required this.appState, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
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

          // 1-Tap Batch Review Quick Trigger (Muse Confidence Partitioning)
          if (appState.missingComplianceTrips.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final pending = appState.missingComplianceTrips;
                final readyCount = pending
                    .where((t) =>
                        TripConfidenceClassifier.assess(t).isHighConfidence)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        child: const Icon(LucideIcons.sparkles,
                            color: Color(0xFF2563EB), size: 18),
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
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          CpkBatchReviewSheet.show(context, appState);
                        },
                        child: const Text('Review',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Strategic Advisor: Money Left on the Table
          MoneyLeftOnTableCard(appState: appState),

          // 2. CPK Tax Shield Hero Card (Royal Midnight Sapphire & Electric Cobalt VVIP Finish)
          Container(
            padding: const EdgeInsets.all(1.5), // Double-bezel outer machined rim
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B82F6), // Specular electric sapphire rim highlight
                  Color(0xFF1E3A8A), // Royal navy mid-tone
                  Color(0xFF0F172A), // Shadowed obsidian chamfer
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.5),
                gradient: const RadialGradient(
                  center: Alignment(-0.6, -0.8),
                  radius: 1.45,
                  colors: [
                    Color(0xFF1D4ED8), // Luminescent Cobalt Core Highlight
                    Color(0xFF1E3A8A), // Royal Midnight Sapphire
                    Color(0xFF0F172A), // Deep Obsidian Abyss Foundation
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Header: Deduction Title & 91¢/km Rate with Frosted Glass Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.shieldCheck,
                              size: 13,
                              color: Color(0xFF93C5FD), // Soft Electric Cyan Shield
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ESTIMATED TAX DEDUCTION • $rateCents¢/KM',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFBFDBFE), // Soft ice-blue for crystal clarity
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      if (vehicle?.regoPlate != null &&
                          vehicle!.regoPlate.isNotEmpty &&
                          vehicle.regoPlate != 'No Plate')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            vehicle.regoPlate,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hero Dollar Figure (Diamond Crisp White with Cyan Bloom)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Formatters.currency(summary.centsPerKmClaim),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Colors.white, // Crisp Diamond White
                          letterSpacing: -1.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF60A5FA).withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'AUD',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            color: Color(0xFFDBEAFE),
                            letterSpacing: 0.4,
                          ),
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
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE2E8F0), // Platinum text
                          letterSpacing: -0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: businessKm >= 5000
                              ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: businessKm >= 5000
                                ? const Color(0xFFFCA5A5).withValues(alpha: 0.40)
                                : Colors.white.withValues(alpha: 0.20),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${remainingKm.toStringAsFixed(0)} km left',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: businessKm >= 5000
                                ? const Color(0xFFFCA5A5)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar (Electric Cyan & Mint Glow)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 7,
                      color: Colors.white.withValues(alpha: 0.12),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: businessKm >= 5000
                                      ? [
                                          const Color(0xFFF87171),
                                          const Color(0xFFEF4444),
                                        ]
                                      : [
                                          const Color(0xFF38BDF8), // Electric Cyan
                                          const Color(0xFF34D399), // Precision Mint
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (businessKm >= 5000
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8))
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Ambient Telemetry & Dynamic Drive Capsule
          HomeTelemetryCapsule(appState: appState),
          const SizedBox(height: 14),

          // 4. Evidence Activity Stream (Glanceable Latest Drive)
          HomeRecentActivity(appState: appState, onViewAll: onViewAll),
        ],
        ),
      ),
    );
  }
}
