import 'package:flutter/foundation.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../widgets/kiloclaim_brand_lockup.dart';
import '../../../services/notifications/notification_service.dart';
import '../notifications/notifications_dropdown.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../services/engine/tax_calculator_service.dart';
import '../../../state/app_state.dart';
import 'widgets/method_arbitrage_card.dart';
import '../auth/sign_in_screen.dart';
import '../evidence/evidence_review_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../home/widgets/scaffold_bottom_nav_bar.dart';
import '../logbook/logbook_progress_screen.dart';
import '../logbook/logbook_setup_screen.dart';
import '../logbook/widgets/annual_odometer_reminder_card.dart';
import '../logbook/widgets/odometer_gap_review_card.dart';
import '../tax/tax_summary_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import 'widgets/account_settings_sheet.dart';
import '../home/widgets/quick_capture_bottom_sheet.dart';
import '../trips/trip_live_tracking_screen.dart';
import 'widgets/home_record_hero.dart';
import 'widgets/home_telemetry_capsule.dart';

class TaskHomeBody extends StatefulWidget {
  final AppState appState;
  final EvidenceReviewService evidenceService;
  final VoidCallback? onViewAll;
  final VoidCallback? onReviewTrips;
  final VoidCallback? onViewTax;
  const TaskHomeBody({
    super.key,
    required this.appState,
    this.evidenceService = const EvidenceReviewService(),
    this.onViewAll,
    this.onReviewTrips,
    this.onViewTax,
  });

  @override
  State<TaskHomeBody> createState() => _TaskHomeBodyState();
}

class _TaskHomeBodyState extends State<TaskHomeBody> {
  AppState get appState => widget.appState;
  VoidCallback? get onViewAll => widget.onViewAll;
  VoidCallback? get onReviewTrips => widget.onReviewTrips;
  VoidCallback? get onViewTax => widget.onViewTax;
  Map<String, ReceiptFileInspection> _files = const {};
  bool _checking = true;
  bool _failed = false;
  int _generation = 0;
  List<VehicleExpense> _inspectedExpenses = const [];
  String? _inspectedVehicleId;
  String? _inspectedYear;
  EvidenceReviewReport get _report => widget.evidenceService.evaluate(
      vehicle: appState.primaryVehicle,
      financialYear: appState.activeTaxRule.financialYear,
      trips: appState.trips,
      expenses: appState.expenses,
      receiptFiles: _files,
      hasOdometerGaps: appState.pendingOdometerGaps.isNotEmpty);
  @override
  void initState() {
    super.initState();
    appState.addListener(_refresh);
    _inspect();
  }

  @override
  void didUpdateWidget(covariant TaskHomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != appState) {
      oldWidget.appState.removeListener(_refresh);
      appState.addListener(_refresh);
      _inspect();
    } else if (oldWidget.evidenceService != widget.evidenceService) {
      _inspect();
    }
  }

  @override
  void dispose() {
    _generation++;
    appState.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final report = _report;
    if (_inspectedVehicleId != report.vehicle?.id ||
        _inspectedYear != report.financialYear ||
        !listEquals(_inspectedExpenses, report.expenses)) {
      _inspect();
    } else {
      setState(() {});
    }
  }

  Future<void> _inspect() async {
    final report = _report;
    _inspectedExpenses = List.of(report.expenses);
    _inspectedVehicleId = report.vehicle?.id;
    _inspectedYear = report.financialYear;
    final generation = ++_generation;
    setState(() {
      _files = const {};
      _checking = true;
      _failed = false;
    });
    try {
      final files =
          await widget.evidenceService.inspectReceipts(report.expenses);
      if (!mounted || generation != _generation) return;
      setState(() {
        _files = files;
        _checking = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final hasTrips = report.trips.isNotEmpty;
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
            const Expanded(child: KiloClaimBrandLockup(compact: true)),
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
          const SizedBox(height: 12),
          const Text('Your evidence.', style: AppType.section),
          const SizedBox(height: 4),
          Text(
              appState.primaryVehicle == null
                  ? 'Add your vehicle to begin'
                  : '${appState.primaryVehicle!.displayName} · FY ${report.financialYear}',
              style: AppType.secondary),
          const SizedBox(height: 24),
          if (appState.isDriving) HomeTelemetryCapsule(appState: appState),
          if (appState.syncStatus == SyncStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Couldn’t sync your records',
                    style: AppType.bodyStrong),
                subtitle: const Text(
                    'Your records on this device are still available.',
                    style: AppType.secondary),
                trailing: TextButton(
                  onPressed: () => appState.triggerSyncToCloud(),
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (!appState.isDriving) ...[
            if (!report.hasRecords) ...[
              HomeWelcomeHero(
                vehicleName:
                    appState.primaryVehicle?.displayName ?? 'Your vehicle',
                taxMethod: appState.primaryVehicle?.taxMethod,
                actions: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        if (appState.primaryVehicle == null) {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (routeContext) => VehicleSetupFlow(
                              onVehicleCreated: (vehicle) async {
                                await appState.addVehicle(vehicle);
                                if (routeContext.mounted) {
                                  Navigator.of(routeContext).pop();
                                }
                              },
                              onCancel: () => Navigator.of(routeContext).pop(),
                            ),
                          ));
                        } else {
                          QuickCaptureBottomSheet.show(context, appState);
                        }
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColor.brand,
                          foregroundColor: AppColor.onNavy,
                          minimumSize: const Size(48, 52),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16)),
                      icon: const Icon(Icons.add),
                      label: Text(appState.primaryVehicle == null
                          ? 'Add your vehicle'
                          : 'Capture your first record'),
                    ),
                    if (appState.primaryVehicle != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => TripLiveTrackingScreen(
                                    appState: appState))),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColor.onNavyMuted,
                            minimumSize: const Size(48, 48)),
                        child: const Text('Record a drive with GPS →'),
                      ),
                  ],
                ),
              ),
            ] else
              _nextAction(context, report),
            const SizedBox(height: 24),
          ],
          _packStatus(context, report),
          _buildArbitrageCard(context, report),
          if (report.hasRecords) ...[
            _recentRecords(context, report),
            const SizedBox(height: 16),
          ],
          if (!appState.isDriving) ...[
            HomeTelemetryCapsule(appState: appState),
            const SizedBox(height: 8),
          ],
          if (appState.pendingOdometerGaps.isNotEmpty && !isLogbook) ...[
            OdometerGapReviewCard(appState: appState),
            const SizedBox(height: 16),
          ],
          if (isLogbook) ...[
            const Text('Logbook details', style: AppType.section),
            const SizedBox(height: 8),
            if (report.hasRecords) _odometer(context),
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

  Widget _nextAction(BuildContext context, EvidenceReviewReport report) {
    final week = report.itemsForWeek(DateTime.now());
    final tripCount = week.whereType<TripReviewItem>().length;
    final expenseCount = week.whereType<ExpenseReviewItem>().length;
    final allRecords = report.items
        .where((i) => i is TripReviewItem || i is ExpenseReviewItem)
        .length;
    final older = allRecords - tripCount - expenseCount;
    final setup = report.items
        .where((i) => i is SetupReviewItem || i is OdometerReviewItem)
        .length;
    return Container(
        key: const ValueKey('home-next-task'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColor.surfaceNavy,
            borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('FINISH YOUR RECORDS',
              style: AppType.eyebrow.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 12),
          Text(
              report.items.isEmpty && !_checking && !_failed
                  ? 'No outstanding record checks'
                  : 'Review your evidence',
              style: AppType.titleSmall.copyWith(color: AppColor.onNavy)),
          const SizedBox(height: 8),
          Text(
              '$tripCount ${tripCount == 1 ? 'trip' : 'trips'} · $expenseCount ${expenseCount == 1 ? 'receipt' : 'receipts'} this week',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          if (older > 0)
            Text('$older older records need attention',
                style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          if (setup > 0)
            Text('$setup vehicle or odometer checks · all periods',
                style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 16),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColor.brand,
                  foregroundColor: AppColor.onNavy,
                  minimumSize: const Size(48, 48)),
              onPressed: () {
                if (onReviewTrips != null) {
                  onReviewTrips!();
                } else {
                  EvidenceReviewScreen.show(context, appState: appState);
                }
              },
              child: const Text('Review records')),
          Text('All pending records for FY ${report.financialYear}',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        ]));
  }

  Widget _buildArbitrageCard(BuildContext context, EvidenceReviewReport report) {
    final vehicle = appState.primaryVehicle;
    if (vehicle == null ||
        vehicle.taxMethod != TaxMethod.centsPerKm ||
        report.trips.isEmpty) {
      return const SizedBox.shrink();
    }

    final rule = appState.activeTaxRule;
    final summary = TaxCalculatorService.evaluateSummary(
      trips: report.trips,
      expenses: report.expenses,
      taxRule: rule,
    );
    final earliestDate = report.trips
        .map((t) => t.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final trackingDays =
        DateTime.now().difference(earliestDate).inDays.clamp(1, 365);
    final annualizedBusinessKm = (summary.businessKm / trackingDays) * 365.0;
    final annualizedTotalKm = (summary.totalKm / trackingDays) * 365.0;

    final useActual = summary.businessKm >= 4000.0;
    final projectedCpkClaim = useActual
        ? summary.centsPerKmClaim
        : (annualizedBusinessKm.clamp(0.0, rule.centsPerKmMaxKm)) *
            rule.centsPerKmRate;
    final isBenchmarkEstimate =
        summary.logbookClaim <= 0 && summary.businessPercentage > 0;
    final projectedLogbookClaim = isBenchmarkEstimate
        ? TaxCalculatorService.estimateAnnualUteRunningCost(annualizedTotalKm) *
            (summary.businessPercentage / 100.0)
        : (useActual
            ? summary.logbookClaim
            : (summary.logbookClaim / trackingDays) * 365.0);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MethodArbitrageCard(
        businessKm: summary.businessKm,
        centsPerKmClaim: projectedCpkClaim,
        logbookClaim: projectedLogbookClaim,
        annualizedBusinessKm: annualizedBusinessKm,
        trackingDays: trackingDays,
        isBenchmarkEstimate: isBenchmarkEstimate,
        onExplore: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LogbookSetupScreen(appState: appState),
          ),
        ),
      ),
    );
  }

  Widget _packStatus(BuildContext context, EvidenceReviewReport report) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Accountant pack', style: AppType.section),
            const SizedBox(height: 8),
            if (_checking) const LinearProgressIndicator(),
            Text(
                _checking
                    ? 'Checking receipt files…'
                    : _failed
                        ? 'Receipt files could not be checked'
                        : report.isComplete
                            ? 'No outstanding app checks in this scope'
                            : !report.hasRecords
                                ? 'No records in this scope yet'
                                : 'Records need attention before review',
                style: AppType.body),
            if (_failed)
              TextButton(
                  onPressed: _inspect,
                  child: const Text('Retry receipt check')),
            TextButton(
                onPressed: () => _openTax(context),
                child: const Text('Open accountant pack')),
          ])));

  Widget _recentRecords(BuildContext context, EvidenceReviewReport report) {
    final records = <({DateTime date, Widget row})>[
      for (final trip in report.trips)
        (
          date: trip.date,
          row: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.route),
              title: Text(trip.destinationAddress ?? trip.purpose),
              subtitle: Text(
                  '${Formatters.date(trip.date)} · ${trip.distanceKm.toStringAsFixed(1)} km'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      TripDetailScreen(trip: trip, appState: appState))))
        ),
      for (final expense in report.expenses)
        (
          date: expense.date,
          row: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long),
              title: Text(expense.category.displayName),
              subtitle: Text(
                  '${Formatters.date(expense.date)} · ${Formatters.currency(expense.amount)}'),
              onTap: () => ExpenseDetailScreen.show(context,
                  appState: appState, expense: expense))
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Recent records', style: AppType.section),
      for (final record in records.take(3)) record.row,
      if (onViewAll != null)
        TextButton(onPressed: onViewAll, child: const Text('View records')),
    ]);
  }

  void _openTax(BuildContext context) {
    if (onViewTax != null) {
      onViewTax!();
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaxSummaryScreen(
              initialVehicleId: appState.primaryVehicle?.id,
              initialFinancialYear: appState.activeTaxRule.financialYear)));
    }
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
