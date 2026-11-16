import 'widgets/odometer_gap_review_card.dart';
import '../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_space.dart';
import 'logbook_progress_screen.dart';
import 'logbook_setup_screen.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/home_header_bar.dart';
import '../dashboard/widgets/home_recent_activity.dart';
import '../dashboard/widgets/tax_readiness_card.dart';
import '../dashboard/widgets/account_settings_sheet.dart';
import '../dashboard/widgets/money_left_on_table_card.dart';
import '../home/widgets/scaffold_bottom_nav_bar.dart';
import 'widgets/annual_odometer_reminder_card.dart';
import 'widgets/tax_exemption_streak_hero.dart';

/// Screen 6: Dedicated Home Canvas for Logbook Method (TR 97/11)
/// Clean Architecture - 100% Focused on 12-Week Compliance, Gapless Odometer, and Expenses.
class LogbookHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;

  const LogbookHomeBody({super.key, required this.appState, this.onViewAll});

  @override
  Widget build(BuildContext context) {
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
            OdometerGapReviewCard(appState: appState),
            TaxExemptionStreakHero(appState: appState),
            const SizedBox(height: S.sm),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.ink,
                      minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              appState.primaryVehicle?.logbookStartDate == null
                                  ? LogbookSetupScreen(appState: appState)
                                  : const LogbookProgressScreen())),
                  icon: Icon(
                      appState.primaryVehicle?.logbookStartDate == null
                          ? AppIcons.add
                          : AppIcons.forward,
                      size: AppIconSize.control),
                  label: Text(
                      appState.primaryVehicle?.logbookStartDate == null
                          ? 'Start your logbook'
                          : 'View logbook overview',
                      style: AppType.bodyStrong),
                )),
            const SizedBox(height: S.lg),

            // 1-Tap Action Banner for Pending Reviews / Receipts
            if (appState.pendingOdometerGaps.isEmpty) ...[
              TaxReadinessCard(appState: appState),
              const SizedBox(height: 14),
            ],

            // Priority Tradie Section: Today's Trips front & center
            HomeRecentActivity(appState: appState, onViewAll: onViewAll),
            const SizedBox(height: 14),

            AnnualOdometerReminderCard(appState: appState),

            // Strategic Advisor: Money Left on the Table
            if (appState.evidenceReview.items.isEmpty)
              MoneyLeftOnTableCard(appState: appState),
          ],
        ),
      ),
    );
  }
}
