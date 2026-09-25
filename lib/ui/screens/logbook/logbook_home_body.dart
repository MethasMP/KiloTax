import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/home_header_bar.dart';
import '../dashboard/widgets/home_recent_activity.dart';
import '../dashboard/widgets/tax_readiness_card.dart';
import '../dashboard/widgets/account_settings_sheet.dart';
import '../dashboard/widgets/money_left_on_table_card.dart';
import '../dashboard/widgets/home_telemetry_capsule.dart';

/// Screen 6: Dedicated Home Canvas for Logbook Method (TR 97/11)
/// Clean Architecture - 100% Focused on 12-Week Compliance, Gapless Odometer, and Expenses.
class LogbookHomeBody extends StatelessWidget {
  final AppState appState;

  const LogbookHomeBody({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    final summary = appState.taxSummary;
    final businessUse = summary.businessPercentage;
    final businessKm = summary.businessKm;
    final totalKm = summary.totalKm;

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

          // Strategic Advisor: Money Left on the Table
          MoneyLeftOnTableCard(appState: appState),

          // 2. Action Required (Missing Purposes or Receipts)
          if (appState.missingComplianceTrips.isNotEmpty || appState.unclassifiedExpenses.isNotEmpty) ...[
            TaxReadinessCard(appState: appState),
            const SizedBox(height: 16),
          ],

          // 3. Logbook Hero Masterpiece (12-Week Tracker & Business %)
          Container(
            padding: const EdgeInsets.all(22),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.bookOpen, color: AppColors.emerald, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'LOGBOOK • Week ${appState.currentLogbookWeek} of 12',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: AppColors.emerald,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      vehicle?.regoPlate ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Circular Progress + Business Use %
                Row(
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: businessUse / 100.0,
                            strokeWidth: 7,
                            backgroundColor: AppColors.background,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                          ),
                          Center(
                            child: Text(
                              '${businessUse.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${businessUse.toStringAsFixed(1)}% Business Use',
                            style: AppTextStyles.pageTitle,
                          ),
                          const SizedBox(height: 2),
                          const Text('Valid for 5 consecutive tax years', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Km stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Formatters.distance(businessKm), style: AppTextStyles.cardPrimary),
                        const Text('Business km', style: AppTextStyles.caption),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formatters.distance(totalKm), style: AppTextStyles.cardPrimary),
                        const Text('Total km logged', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Odometer Continuous Baseline Indicator
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emerald),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Odometer baseline: ${Formatters.odometer(appState.currentOdometer)} km (Continuous audit trail active)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (appState.logbookStraddlesFinancialYear) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.calendarDays, size: 15, color: AppColors.amberDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appState.logbookFyApportionmentAdvisory,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.amberDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 4. Evidence Activity Stream
          HomeRecentActivity(appState: appState),
        ],
      ),
    );
  }
}
