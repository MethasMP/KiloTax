import '../../../services/notifications/notification_service.dart';
import '../notifications/notifications_dropdown.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../auth/sign_in_screen.dart';
import '../evidence/evidence_review_screen.dart';
import '../home/widgets/scaffold_bottom_nav_bar.dart';
import '../logbook/logbook_progress_screen.dart';
import '../logbook/logbook_setup_screen.dart';
import '../logbook/widgets/annual_odometer_reminder_card.dart';
import '../logbook/widgets/odometer_gap_review_card.dart';
import '../tax/tax_summary_screen.dart';
import 'widgets/account_settings_sheet.dart';
import '../home/widgets/quick_capture_bottom_sheet.dart';
import '../trips/trip_live_tracking_screen.dart';
import 'models/home_record_summary.dart';
import 'widgets/home_record_hero.dart';
import 'widgets/home_recent_activity.dart';
import 'widgets/home_telemetry_capsule.dart';

class TaskHomeBody extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  const TaskHomeBody({super.key, required this.appState, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final report = appState.evidenceReview;
    final hasTrips = report.trips.isNotEmpty;
    final summary = HomeRecordSummary.fromReport(report,
        taxRule: appState.activeTaxRule, now: DateTime.now());
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;
    return RefreshIndicator(
      color: AppColor.brand,
      onRefresh: () async {
        await appState.restoreFromCloud();
        await appState.refreshLocationPermission();
        await appState.checkRealBluetoothConnection();
      },
      child: ListView(
        key: const PageStorageKey('task-home'),
        padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            ScaffoldBottomNavBar.clearanceFor(context,
                taxMethod: appState.primaryVehicle?.taxMethod)),
        children: [
          Row(children: [
            const Expanded(child: Text('Your driving.', style: AppType.title)),
            IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  final service = await NotificationService.getInstance();
                  if (context.mounted) {
                    await NotificationsDropdown.show(context,
                        notificationService: service);
                  }
                },
                icon: const Icon(Icons.notifications_none)),
            IconButton(
                tooltip: 'Account and settings',
                onPressed: () => AccountSettingsSheet.show(context, appState),
                icon: const Icon(Icons.person_outline)),
          ]),
          Text(
              appState.primaryVehicle?.displayName ??
                  'Add your vehicle to begin',
              style: AppType.secondary),
          const SizedBox(height: 24),
          if (appState.isDriving)
            HomeTelemetryCapsule(appState: appState)
          else if (report.hasRecords)
            HomeRecordHero(
                summary: summary,
                onViewBasis: () => _showBasis(context, summary),
                onLogbook: () => _openLogbook(context))
          else ...[
            HomeWelcomeHero(
                vehicleName:
                    appState.primaryVehicle?.displayName ?? 'Your vehicle',
                taxMethod: appState.primaryVehicle?.taxMethod),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: () =>
                    QuickCaptureBottomSheet.showTripCaptureModeSheet(
                        context, appState),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
                icon: const Icon(Icons.add),
                label: const Text('Add your first trip')),
            TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            TripLiveTrackingScreen(appState: appState))),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Record a drive with GPS →')),
          ],
          const SizedBox(height: 16),
          if (!appState.isDriving) HomeTelemetryCapsule(appState: appState),
          if (isLogbook && report.hasRecords) _odometer(context),
          if (report.hasRecords && summary.pendingItems.isNotEmpty) ...[
            Material(
              key: const ValueKey('home-next-task'),
              color: AppColor.brandTint,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColor.brandTintStrong)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Text('${summary.pendingItems.length}',
                    style: AppType.metricSmall),
                title: const Text('Review your records',
                    style: AppType.bodyStrong),
                subtitle: const Text(
                    'Check trip purposes, receipts and missing details.',
                    style: AppType.secondary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    EvidenceReviewScreen.show(context, appState: appState),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (hasTrips) ...[
            HomeRecentActivity(appState: appState, onViewAll: onViewAll),
            const SizedBox(height: 24)
          ],
          if (isLogbook) ...[
            OdometerGapReviewCard(appState: appState),
            if (!report.hasRecords) _logbook(context),
            const SizedBox(height: 16),
            AnnualOdometerReminderCard(appState: appState),
          ],
          if (hasTrips) ...[
            const SizedBox(height: 16),
            if (!appState.isAuthenticated) ...[
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Records on this device',
                    style: AppType.bodyStrong),
                subtitle: const Text('Account and backup options',
                    style: AppType.secondary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (routeContext) => SignInScreen(
                        onAuthSuccess: () => Navigator.of(routeContext).pop(),
                        onContinueAsGuest: () =>
                            Navigator.of(routeContext).pop()))),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showBasis(BuildContext context, HomeRecordSummary summary) {
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Your estimate basis',
                          style: AppType.titleSmall),
                      const SizedBox(height: 16),
                      Text(
                          '${appState.primaryVehicle?.taxMethod.title ?? 'Selected method'} · FY ${summary.report.financialYear}',
                          style: AppType.bodyStrong),
                      const SizedBox(height: 12),
                      Text(
                          '${summary.reviewedTripCount} reviewed trips and ${summary.reviewedExpenseCount} reviewed expenses. Records with missing or unconfirmed details and archived receipts are excluded.',
                          style: AppType.body),
                      const SizedBox(height: 12),
                      Text(
                          summary.isCpk
                              ? 'Uses ${(summary.taxRule.centsPerKmRate * 100).toStringAsFixed(0)}c/km, capped at ${Formatters.odometer(summary.taxRule.centsPerKmMaxKm)} work km for this financial year. Car running costs are not added again.'
                              : '${Formatters.currency(summary.reviewed.totalRunningExpenses)} running costs × ${Formatters.percentage(summary.reviewed.businessPercentage)} reviewed work use, plus ${Formatters.currency(summary.reviewed.totalDirectDeductions)} direct expenses. Missing personal travel can change that share.',
                          style: AppType.body),
                      const SizedBox(height: 12),
                      const Text(
                          'This is a provisional deduction, not a tax refund or an eligibility decision. Receipt file availability is checked separately during export. Elapsed logbook days do not establish completeness.',
                          style: AppType.secondary),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            navigator.push(MaterialPageRoute<void>(
                                builder: (_) => const TaxSummaryScreen()));
                          },
                          child: const Text('View full tax summary')),
                      const SizedBox(height: 8),
                      const Text(
                          'The full summary includes recorded amounts that may still need review.',
                          style: AppType.secondary),
                    ]),
              ),
            ));
  }

  Widget _odometer(BuildContext context) {
    final vehicle = appState.primaryVehicle!;
    final trips = appState.trips
        .where((trip) =>
            trip.vehicleId == vehicle.id &&
            !trip.isDeleted &&
            trip.endOdometer > 0)
        .toList()
      ..sort((a, b) => b.endOdometer.compareTo(a.endOdometer));
    final latest = trips.isEmpty ? null : trips.first;
    final reading = latest?.endOdometer ?? vehicle.initialOdometer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.speed_outlined),
        title: Text(
            reading > 0
                ? '${Formatters.odometer(reading)} km'
                : 'Record an opening odometer',
            style: AppType.bodyStrong),
        subtitle: Text(
            latest == null
                ? 'Opening reading · vehicle setup'
                : 'Trip ledger odometer · ${Formatters.date(latest.date)}',
            style: AppType.secondary),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openLogbook(context),
      ),
    );
  }

  void _openLogbook(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => appState.primaryVehicle?.logbookStartDate == null
              ? LogbookSetupScreen(appState: appState)
              : const LogbookProgressScreen()));

  Widget _logbook(BuildContext context) {
    final start = appState.primaryVehicle?.logbookStartDate;
    final day = start == null
        ? 0
        : DateUtils.dateOnly(DateTime.now())
                .difference(DateUtils.dateOnly(start))
                .inDays +
            1;
    final elapsed = day.clamp(0, AppConstants.statutoryLogbookDays);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(start == null ? 'Set up your logbook' : 'Logbook period',
          style: AppType.bodyStrong),
      subtitle: Text(
          start == null
              ? 'Choose a start date and opening odometer reading.'
              : '$elapsed of ${AppConstants.statutoryLogbookDays} days · Review your recorded period',
          style: AppType.secondary),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => start == null
              ? LogbookSetupScreen(appState: appState)
              : const LogbookProgressScreen())),
    );
  }
}
