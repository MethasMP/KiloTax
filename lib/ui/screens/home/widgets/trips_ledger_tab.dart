import '../../../widgets/adaptive_row.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../cpk/cpk_trip_entry_screen.dart';
import '../../logbook/logbook_trip_entry_screen.dart';
import '../../trips/trip_detail_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';
import '../../trips/trip_quick_resolve_sheet.dart';
import '../../trips/widgets/cpk_batch_review_sheet.dart';
import '../../trips/widgets/bulky_tools_badge.dart';
import '../../evidence/evidence_review_screen.dart';
import '../../audit/ato_audit_shield_sheet.dart';
import '../../trips/back_capture_trip_sheet.dart';
import '../../workflow/workflow_screen.dart';
import '../../workflow/workflow_trip_editor.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';
import 'scaffold_bottom_nav_bar.dart';
import '../../../../services/engine/evidence_review_service.dart';
import '../../../../services/tax/ato_tax_period_engine.dart';

class TripsLedgerTab extends StatefulWidget {
  final AppState appState;

  final String? initialFilter;
  final String? initialVehicleId;
  final String? financialYear;

  const TripsLedgerTab({
    super.key,
    required this.appState,
    this.initialFilter,
    this.initialVehicleId,
    this.financialYear,
  });

  @override
  State<TripsLedgerTab> createState() => _TripsLedgerTabState();
}

class _TripsLedgerTabState extends State<TripsLedgerTab> {
  Set<String> _reviewTripIds = {};
  Map<String, String> _reviewReasons = {};

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.initialVehicleId;
    if (const ['All', 'Needs review', 'Business', 'Personal']
        .contains(widget.initialFilter)) {
      _selectedFilter = widget.initialFilter!;
    }
  }

  String _selectedFilter =
      'All'; // 'All', 'Needs review', 'Business', 'Personal'
  String?
      _selectedVehicleId; // null = follow active primary vehicle, or specific vehicle id

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) => _buildLedger(context),
      );

  Widget _buildLedger(BuildContext context) {
    final appState = widget.appState;
    final primaryVeh = appState.primaryVehicle;
    final activeVehicleId = _selectedVehicleId ?? primaryVeh?.id;

    final activeVehicle =
        appState.vehicles.where((v) => v.id == activeVehicleId).firstOrNull ??
            primaryVeh;
    final report = const EvidenceReviewService().evaluate(
      vehicle: activeVehicle,
      financialYear:
          widget.financialYear ?? appState.activeTaxRule.financialYear,
      trips: appState.trips,
      expenses: appState.expenses,
    );
    final vehicleTrips = report.trips;
    _reviewTripIds = report.items
        .whereType<TripReviewItem>()
        .map((item) => item.tripId)
        .toSet();
    _reviewReasons = {
      for (final item in report.items.whereType<TripReviewItem>())
        item.tripId: item.description,
    };
    final filteredTrips = vehicleTrips.where((t) {
      if (_selectedFilter == 'Needs review') {
        return _reviewTripIds.contains(t.id);
      }
      if (_selectedFilter == 'Business') {
        return t.classification == TripClassification.business;
      }
      if (_selectedFilter == 'Personal') {
        return t.classification == TripClassification.personal;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: AppColor.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trips',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColor.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              activeVehicle?.displayName ?? 'Your vehicle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColor.inkSubtle,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add trip',
            icon: const Icon(AppIcons.add),
            onPressed: () => _addTrip(context, appState),
          ),
          PopupMenuButton<String>(
            tooltip: 'Trip tools',
            onSelected: (value) {
              if (value == 'drive') {
                if (!appState.isDriving && activeVehicleId != null) {
                  appState.selectVehicle(activeVehicleId);
                }
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => TripLiveTrackingScreen(appState: appState),
                ));
              } else if (value == 'evidence') {
                EvidenceReviewScreen.show(context,
                    appState: appState,
                    vehicleId: activeVehicleId,
                    financialYear: widget.financialYear);
              } else if (value == 'shield') {
                final snapshot = appState.buildAuditShieldSnapshot();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AtoAuditShieldSheet(
                    slaReport: snapshot.slaReport,
                    windowReport: snapshot.windowReport,
                    calibrationResult: snapshot.calibrationResult,
                    fuelPlausibility: snapshot.fuelPlausibility,
                    ghostTrips: snapshot.ghostTrips,
                    watchdogReport: snapshot.watchdogReport,
                    onRecoverGhostTrip: activeVehicle == null
                        ? null
                        : (candidate) {
                            Navigator.of(context).pop();
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BackCaptureTripSheet(
                                vehicleId: activeVehicle.id,
                                taxMethod: activeVehicle.taxMethod,
                                userProfile: appState.userProfile,
                                jobSites: appState.jobSites,
                                initialStartOdometer: appState.currentOdometer,
                                initialPurpose: candidate.suggestedPurpose,
                                initialDepartureTime:
                                    candidate.receiptTimestamp,
                                onSave: (trip) {
                                  appState.recordTrip(trip);
                                },
                              ),
                            );
                          },
                  ),
                );
              } else {
                if (activeVehicleId != null) {
                  appState.selectVehicle(activeVehicleId);
                }
                WorkflowScreen.show(context, appState);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'drive',
                child: Text(appState.isDriving
                    ? 'Open current drive'
                    : 'Start manually'),
              ),
              const PopupMenuItem(
                  value: 'evidence', child: Text('Review evidence')),
              const PopupMenuItem(
                  value: 'shield', child: Text('ATO Audit Shield')),
              const PopupMenuItem(
                  value: 'workflow', child: Text('Accountant workflow')),
            ],
          ),
          if (appState.vehicles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(AppIcons.vehicle,
                  color: AppColors.deepNavy, size: AppIconSize.control),
              tooltip: 'Switch Vehicle Ledger',
              onSelected: (vehId) {
                setState(() {
                  _selectedVehicleId = vehId;
                });
              },
              itemBuilder: (ctx) => [
                for (final v in appState.vehicles)
                  PopupMenuItem<String>(
                    value: v.id,
                    child: AdaptiveRow(
                      children: [
                        Icon(
                          v.id == activeVehicleId
                              ? AppIcons.selected
                              : AppIcons.unselected,
                          size: AppIconSize.inline,
                          color: v.id == activeVehicleId
                              ? AppColors.emerald
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Text('${v.regoPlate} (${v.displayName})',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('FY ${report.financialYear}',
                  style: AppTextStyles.caption)),
          // Segmented Filter Bar (Only shown when trips exist to avoid zero-counter clutter)
          if (vehicleTrips.isNotEmpty)
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: AdaptiveRow(
                  children: [
                    _buildFilterChip('All', vehicleTrips.length),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Needs review',
                      vehicleTrips
                          .where((t) => _reviewTripIds.contains(t.id))
                          .length,
                      isAlert: vehicleTrips
                          .any((t) => _reviewTripIds.contains(t.id)),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Business',
                      vehicleTrips
                          .where((t) =>
                              t.classification == TripClassification.business)
                          .length,
                    ),
                    if (activeVehicle?.taxMethod == TaxMethod.logbook) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Personal',
                        vehicleTrips
                            .where((t) =>
                                t.classification == TripClassification.personal)
                            .length,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Same-day consecutive business journey chaining (ITAA 1997 s 28-125(3))
          Builder(
            builder: (context) {
              final chains = appState.findSameDayChainCandidates(
                  vehicleId: activeVehicleId);
              if (chains.isEmpty) return const SizedBox.shrink();
              final firstChain = chains.first;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColor.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColor.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.link,
                        size: 18, color: AppColor.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${firstChain.trips.length} consecutive work trips (${firstChain.totalDistanceKm.toStringAsFixed(1)} km) can be combined (s 28-125(3)).',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        appState.chainSameDayBusinessTrips(firstChain.trips);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Combined consecutive work trips.'),
                          ),
                        );
                      },
                      child: const Text('Combine'),
                    ),
                  ],
                ),
              );
            },
          ),

          // 3M Lean Optimization: Eliminate Muri (Overburden) & Muda (Waiting/Inventory)
          if (vehicleTrips.any((t) => _reviewTripIds.contains(t.id))) ...[
            if (_reviewTripIds.length > 5)
              Container(
                key: const ValueKey('prominent-batch-review-card'),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deepNavy, AppColor.surfaceNavy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.sparkles,
                              color: AppColors.emerald, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_reviewTripIds.length} Trips Pending Review',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Approve high-confidence work drives with 1 tap.',
                                style: TextStyle(
                                  color: AppColor.onNavyMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('btn-1tap-batch-review'),
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              CpkBatchReviewSheet.show(context, appState);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            icon: const Icon(LucideIcons.checkCheck, size: 18),
                            label: const Text('1-Tap Batch Review'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final nextTrip = vehicleTrips.firstWhere(
                                (t) => _reviewTripIds.contains(t.id));
                            TripQuickResolveSheet.show(context,
                                trip: nextTrip, appState: appState);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColor.onNavy,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25)),
                            minimumSize: const Size(48, 48),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('One by one'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.amberDark.withValues(alpha: 0.3)),
                ),
                child: AdaptiveRow(
                  children: [
                    const Icon(AppIcons.warning,
                        size: AppIconSize.inline, color: AppColors.amberDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_reviewTripIds.length} ${_reviewTripIds.length == 1 ? "trip" : "trips"} to review',
                            style: AppTextStyles.secondaryMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text('Confirm the type and business purpose.',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final nextTrip = vehicleTrips
                            .firstWhere((t) => _reviewTripIds.contains(t.id));
                        TripQuickResolveSheet.show(context,
                            trip: nextTrip, appState: appState);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColor.ink,
                        foregroundColor: AppColor.onNavy,
                        minimumSize: const Size(48, 48),
                        textStyle: AppType.secondary.copyWith(
                            fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                      child: const Text('Review next'),
                    ),
                  ],
                ),
              ),
          ],

          const Divider(height: 1, color: AppColors.border),
        ])),
        if (filteredTrips.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: vehicleTrips.isEmpty
                  ? _buildEmptyTripsCard(context, appState, activeVehicle)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('No trips in this filter',
                            style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 12),
                        const Text(
                            'Choose another filter to see your recorded trips.',
                            style: AppTextStyles.secondaryMedium),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () =>
                              setState(() => _selectedFilter = 'All'),
                          child: const Text('Show all trips'),
                        ),
                      ],
                    ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                (ModalRoute.of(context)?.canPop ?? false)
                    ? 20
                    : ScaffoldBottomNavBar.clearanceFor(context,
                        taxMethod: appState.primaryVehicle?.taxMethod)),
            sliver: SliverList.separated(
              itemCount: filteredTrips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final trip = filteredTrips[index];
                final previous =
                    index > 0 ? filteredTrips[index - 1].date : null;
                final startsDay = previous == null ||
                    DateUtils.dateOnly(previous) !=
                        DateUtils.dateOnly(trip.date);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (startsDay)
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(4, index == 0 ? 0 : 14, 4, 12),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatFullDate(trip.date),
                          style: AppTextStyles.caption,
                        ),
                      ),
                    _buildTripCard(trip, appState, activeVehicle),
                  ],
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildEmptyTripsCard(
    BuildContext context,
    AppState appState,
    Vehicle? activeVehicle,
  ) {
    final telemetry = appState.telemetryStatus;
    final (String gpsLabel, IconData gpsIcon, Color gpsBg, Color gpsFg) =
        switch (telemetry) {
      DriveTelemetryStatus.driving => (
          'Auto-GPS: Recording',
          LucideIcons.navigation,
          AppColor.positiveTint,
          AppColor.positiveStrong,
        ),
      DriveTelemetryStatus.armed => (
          'Auto-GPS: Armed',
          LucideIcons.radio,
          AppColor.surfaceMuted,
          AppColor.inkMuted,
        ),
    };

    final isLogbook = activeVehicle?.taxMethod == TaxMethod.logbook;
    final logbookStarted = activeVehicle?.logbookStartDate != null;
    final logbookProgress = logbookStarted
        ? (appState.currentLogbookWeek / 12.0).clamp(0.0, 1.0)
        : 0.0;
    final methodLabel = isLogbook
        ? (logbookStarted
            ? 'Logbook · Week ${appState.currentLogbookWeek} of 12'
            : '12-week logbook ready to start')
        : '0 / ${appState.activeTaxRule.centsPerKmMaxKm.toInt()} km annual cap';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: R.cardR,
        border: Border.all(color: AppColor.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: gpsBg,
                borderRadius: R.chipR,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(gpsIcon, size: 14, color: gpsFg),
                  const SizedBox(width: 6),
                  Text(
                    gpsLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: gpsFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('No trips yet', style: AppType.section),
          const SizedBox(height: 6),
          Text(
            methodLabel,
            style: AppType.secondary.copyWith(fontFeatures: AppType.tabular),
          ),
          if (isLogbook) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: logbookProgress,
                minHeight: 4,
                backgroundColor: AppColor.hairline,
                color: AppColor.brandBright,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.brand,
              foregroundColor: AppColor.onNavy,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => _addTrip(context, appState),
            icon: const Icon(AppIcons.add),
            label: const Text('Add a trip'),
          ),
        ],
      ),
    );
  }

  void _addTrip(BuildContext context, AppState appState) {
    final vehicle = appState.vehicles
            .where((vehicle) => vehicle.id == _selectedVehicleId)
            .firstOrNull ??
        appState.primaryVehicle;
    final currentYear = const AtoTaxPeriodEngine().forDate(DateTime.now());
    final scopedStartYear = widget.financialYear == null
        ? null
        : int.tryParse(widget.financialYear!.split(RegExp(r'[-–]')).first);
    final requiresDate =
        scopedStartYear != null && scopedStartYear != currentYear.startYear;
    final initialDate =
        requiresDate ? AtoFinancialYear(scopedStartYear!).startDate : null;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => vehicle?.taxMethod == TaxMethod.logbook
            ? LogbookTripEntryScreen(
                appState: appState,
                vehicleId: vehicle?.id,
                initialDate: initialDate,
                requireDateConfirmation: requiresDate,
              )
            : CpkTripEntryScreen(
                appState: appState,
                vehicleId: vehicle?.id,
                initialDate: initialDate,
                requireDateConfirmation: requiresDate,
              )));
  }

  String _cleanPlaceName(String? raw, {String fallback = 'Destination'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parts = raw.split(',');
    final first = parts.first.trim();
    return first.isNotEmpty ? first : fallback;
  }

  IconData _getTripIcon(Trip trip) {
    if (_reviewTripIds.contains(trip.id)) {
      return AppIcons.warning;
    }
    if (trip.classification == TripClassification.personal) {
      return AppIcons.personal;
    }
    final text =
        '${trip.purpose} ${trip.destinationAddress ?? ""} ${trip.originAddress ?? ""}'
            .toLowerCase();
    if (text.contains('bunnings') ||
        text.contains('supplier') ||
        text.contains('materials') ||
        text.contains('tools') ||
        text.contains('hardware') ||
        text.contains('timber') ||
        text.contains('depot') ||
        text.contains('trade')) {
      return LucideIcons.shoppingBag;
    }
    if (text.contains('site') ||
        text.contains('inspection') ||
        text.contains('reno') ||
        text.contains('fitout') ||
        text.contains('warehouse') ||
        text.contains('build')) {
      return LucideIcons.hardHat;
    }
    return AppIcons.business;
  }

  Color _getTripAccentColor(Trip trip, bool isNeedsReview, bool isBusiness) {
    if (isNeedsReview) return AppColor.attentionStrong;
    if (!isBusiness) return AppColor.inkSubtle;
    final text =
        '${trip.purpose} ${trip.destinationAddress ?? ""} ${trip.originAddress ?? ""}'
            .toLowerCase();
    if (text.contains('bunnings') ||
        text.contains('supplier') ||
        text.contains('materials') ||
        text.contains('tools') ||
        text.contains('timber')) {
      return AppColor.positive;
    }
    if (text.contains('site') ||
        text.contains('reno') ||
        text.contains('fitout')) {
      return AppColor.attentionStrong;
    }
    return AppColor.ink;
  }

  Widget _buildEvidencePill({
    required String label,
    required Color fg,
    required Color bg,
    bool tabular = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFeatures: tabular ? AppType.tabular : null,
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip, AppState appState,
      [Vehicle? vehicleOverride]) {
    final activeVehicle = vehicleOverride ??
        appState.vehicles.cast<Vehicle?>().firstWhere(
              (v) => v?.id == trip.vehicleId,
              orElse: () => appState.primaryVehicle,
            ) ??
        Vehicle(
          id: 'default',
          make: 'All Vehicles',
          model: '',
          regoPlate: '',
          initialOdometer: 0.0,
        );

    final isBusiness = trip.classification == TripClassification.business;
    final isNeedsReview = _reviewTripIds.contains(trip.id);

    final destName =
        _cleanPlaceName(trip.destinationAddress, fallback: 'Destination');
    final originName = _cleanPlaceName(trip.originAddress, fallback: 'Origin');
    final hasDistinctRoute = trip.originAddress != null &&
        trip.originAddress != trip.destinationAddress &&
        originName != destName;

    final icon = _getTripIcon(trip);
    final accentColor = _getTripAccentColor(trip, isNeedsReview, isBusiness);
    final claimAmount = trip.distanceKm * appState.activeTaxRule.centsPerKmRate;
    final isLogbook = activeVehicle.taxMethod == TaxMethod.logbook ||
        trip.taxMethod == TaxMethod.logbook;

    final distanceText = '${trip.distanceKm.toStringAsFixed(1)} km';
    final linkedReceiptCount = appState.expenses
        .where((e) => !e.isDeleted && trip.linkedExpenseIds.contains(e.id))
        .length;
    final jobRef = (trip.jobReference ?? '').trim();
    final isAutoGps = trip.evidenceSource == 'auto_telemetry';

    final cardContent = Material(
      color: AppColor.surface,
      shape: RoundedRectangleBorder(
        borderRadius: R.cardR,
        side: BorderSide(
          color: isNeedsReview
              ? AppColor.attention.withValues(alpha: 0.6)
              : AppColor.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            TripDetailScreen.show(context, trip: trip, appState: appState),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: AdaptiveRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Refined, contextual category indicator (Replaces repetitive generic briefcase)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, color: accentColor, size: AppIconSize.control),
              ),
              const SizedBox(width: 12),

              // Main content area: structured hierarchy without horizontal crunch
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBusiness
                          ? destName
                          : (destName != 'Destination'
                              ? destName
                              : (isNeedsReview
                                  ? 'Unclassified trip'
                                  : 'Personal Drive')),
                      style: AppType.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$distanceText · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(trip.date))}',
                      style: AppType.secondary
                          .copyWith(fontFeatures: AppType.tabular),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildEvidencePill(
                          label: isAutoGps ? 'Auto-GPS' : 'Manual',
                          fg: isAutoGps
                              ? AppColor.inkMuted
                              : AppColor.inkSubtle,
                          bg: AppColor.surfaceMuted,
                        ),
                        if (linkedReceiptCount > 0)
                          _buildEvidencePill(
                            label:
                                '$linkedReceiptCount ${linkedReceiptCount == 1 ? 'receipt' : 'receipts'}',
                            fg: AppColor.positiveStrong,
                            bg: AppColor.positiveTint,
                            tabular: true,
                          ),
                        if (jobRef.isNotEmpty)
                          _buildEvidencePill(
                            label: 'Job: $jobRef',
                            fg: AppColor.inkMuted,
                            bg: AppColor.surfaceMuted,
                          ),
                      ],
                    ),
                    if (trip.purpose.contains('Bulky Tools') ||
                        trip.purpose.contains('Heavy Tools')) ...[
                      const SizedBox(height: 6),
                      BulkyToolsBadge(
                        compact: true,
                        onTap: () =>
                            BulkyToolsBadge.showAtoExplanationSheet(context),
                      ),
                    ],
                    const SizedBox(height: 8),

                    if (isNeedsReview) ...[
                      Text(
                        _reviewReasons[trip.id] ?? 'Check trip details',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColor.attentionStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Row 2: Route origin context on left, Status / Claim Badge on right
                    AdaptiveRow(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasDistinctRoute)
                          Expanded(
                            child: Text(
                              'from $originName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else if (!isNeedsReview)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColor.surfaceSunken,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              isBusiness ? 'Work Drive' : 'Personal Drive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isBusiness
                                    ? AppColors.deepNavy
                                    : AppColors.muted,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),
                        if (isNeedsReview)
                          OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              TripQuickResolveSheet.show(context,
                                  trip: trip, appState: appState);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: AppColor.attentionInk,
                              backgroundColor: AppColor.attentionTintSoft,
                              side: const BorderSide(
                                  color: AppColor.attentionTintStrong),
                              textStyle: AppType.secondary.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter'),
                            ),
                            icon: const Icon(AppIcons.warning,
                                size: AppIconSize.inline),
                            label: const Text('Review'),
                          )
                        else if (isBusiness) ...[
                          if (!isLogbook)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColor.positiveTint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColor.positiveTintStrong),
                              ),
                              child: Text(
                                '+${Formatters.currency(claimAmount)}',
                                style: const TextStyle(
                                  fontFeatures: AppType.tabular,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColor.positiveStrong,
                                ),
                              ),
                            )
                          else if (hasDistinctRoute)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColor.surfaceSunken,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'Work Drive',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ),
                        ] else if (hasDistinctRoute)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColor.surfaceSunken,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Personal Drive',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('dismissible_${trip.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      confirmDismiss: (direction) async {
        if (trip.review.isNotEmpty) {
          await WorkflowTripEditor.show(context,
              appState: appState, trip: trip);
          return false;
        }
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Classify as Business
          HapticFeedback.mediumImpact();
          final updated = trip.copyWith(
            classification: TripClassification.business,
            purpose: trip.purpose.trim().isEmpty || trip.purpose.contains('?')
                ? 'Client Site / Job'
                : trip.purpose,
          );
          appState.updateTrip(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColor.positiveStrong,
              content: const AdaptiveRow(
                children: [
                  Icon(AppIcons.business,
                      color: Colors.white, size: AppIconSize.inline),
                  SizedBox(width: 8),
                  Text('Classified as Business (Deductible)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Classify as Personal
          HapticFeedback.lightImpact();
          final updated = trip.copyWith(
            classification: TripClassification.personal,
            purpose: trip.purpose.trim().isEmpty || trip.purpose.contains('?')
                ? 'Personal travel'
                : trip.purpose,
          );
          appState.updateTrip(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.deepNavy,
              content: AdaptiveRow(
                children: [
                  Icon(AppIcons.personal,
                      color: Colors.white, size: AppIconSize.inline),
                  SizedBox(width: 8),
                  Text('Classified as Personal',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Return false to keep trip card in list while state updates cleanly without jarring removal animation
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColor.positiveStrong,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const AdaptiveRow(
          children: [
            Icon(AppIcons.business,
                color: Colors.white, size: AppIconSize.control),
            SizedBox(width: 8),
            Text(
              'Business',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.deepNavy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const AdaptiveRow(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Personal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(AppIcons.personal,
                color: Colors.white, size: AppIconSize.control),
          ],
        ),
      ),
      child: cardContent,
    );
  }

  Widget _buildFilterChip(String label, int count, {bool isAlert = false}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.deepNavy
              : (isAlert ? AppColors.amberLight : AppColors.card),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.deepNavy
                : (isAlert
                    ? AppColors.amberDark.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
        ),
        child: AdaptiveRow(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isAlert ? AppColors.amberDark : AppColors.ink),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isAlert ? AppColors.amberDark : AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isAlert ? Colors.white : AppColors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
