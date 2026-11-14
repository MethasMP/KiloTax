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
import '../../trips/trip_quick_resolve_sheet.dart';
import '../../evidence/evidence_review_screen.dart';
import '../../workflow/workflow_screen.dart';
import '../../workflow/workflow_trip_editor.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import 'scaffold_bottom_nav_bar.dart';
import '../../../../services/engine/evidence_review_service.dart';

class TripsLedgerTab extends StatefulWidget {
  final AppState appState;

  const TripsLedgerTab({super.key, required this.appState});

  @override
  State<TripsLedgerTab> createState() => _TripsLedgerTabState();
}

class _TripsLedgerTabState extends State<TripsLedgerTab> {
  Set<String> _reviewTripIds = {};
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
      financialYear: appState.activeTaxRule.financialYear,
      trips: appState.trips,
      expenses: appState.expenses,
    );
    final vehicleTrips = report.trips;
    _reviewTripIds = report.items
        .whereType<TripReviewItem>()
        .map((item) => item.tripId)
        .toSet();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              activeVehicle?.displayName ?? 'Your vehicle',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Trip to accountant workflow',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () {
                if (activeVehicleId != null) {
                  appState.selectVehicle(activeVehicleId);
                }
                WorkflowScreen.show(context, appState);
              }),
          if (vehicleTrips.isNotEmpty)
            IconButton(
                tooltip: 'Add trip',
                icon: const Icon(AppIcons.add),
                onPressed: () => _addTrip(context, appState)),
          IconButton(
            tooltip: 'Review evidence',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => EvidenceReviewScreen.show(context,
                appState: appState, vehicleId: activeVehicleId),
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
              child: Text('FY ${appState.activeTaxRule.financialYear}',
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

          // 3M Lean Optimization: Eliminate Muri (Overburden) & Muda (Waiting/Inventory)
          if (vehicleTrips.any((t) => _reviewTripIds.contains(t.id)))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    child: Text(
                      '${_reviewTripIds.length} ${_reviewTripIds.length == 1 ? "trip" : "trips"} to review',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final unclassifiedTrip = vehicleTrips
                          .firstWhere((t) => _reviewTripIds.contains(t.id));
                      TripQuickResolveSheet.show(context,
                          trip: unclassifiedTrip, appState: appState);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.deepNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Review next',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppColors.border),
        ])),
        if (filteredTrips.isEmpty)
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      vehicleTrips.isEmpty
                          ? 'No trips yet'
                          : 'No trips in this filter',
                      style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  Text(
                      vehicleTrips.isEmpty
                          ? 'Add a trip to start your driving record.'
                          : 'Choose another filter to see your recorded trips.',
                      style: AppTextStyles.secondaryMedium),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: () => _addTrip(context, appState),
                      icon: const Icon(AppIcons.add),
                      label: const Text('Add a trip')),
                ]),
          ))
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
              itemBuilder: (_, index) => _buildTripCard(
                  filteredTrips[index],
                  appState,
                  activeVehicle ??
                      Vehicle(
                          id: 'none',
                          make: '',
                          model: '',
                          regoPlate: '',
                          initialOdometer: 0)),
            ),
          ),
      ]),
    );
  }

  void _addTrip(BuildContext context, AppState appState) {
    if (_selectedVehicleId != null) appState.selectVehicle(_selectedVehicleId!);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => appState.primaryVehicle?.taxMethod == TaxMethod.logbook
            ? LogbookTripEntryScreen(appState: appState)
            : CpkTripEntryScreen(appState: appState)));
  }

  String _cleanPlaceName(String? raw, {String fallback = 'Destination'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parts = raw.split(',');
    final first = parts.first.trim();
    return first.isNotEmpty ? first : fallback;
  }

  IconData _getTripIcon(Trip trip) {
    if (_reviewTripIds.contains(trip.id)) {
      return LucideIcons.sparkles;
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
    if (isNeedsReview) return AppColors.amberDark;
    if (!isBusiness) return AppColors.muted;
    final text =
        '${trip.purpose} ${trip.destinationAddress ?? ""} ${trip.originAddress ?? ""}'
            .toLowerCase();
    if (text.contains('bunnings') ||
        text.contains('supplier') ||
        text.contains('materials') ||
        text.contains('tools') ||
        text.contains('timber')) {
      return AppColors.emerald;
    }
    if (text.contains('site') ||
        text.contains('reno') ||
        text.contains('fitout')) {
      return AppColor.attentionStrong;
    }
    return AppColors.deepNavy;
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

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final dateFormatted = '${trip.date.day} ${months[trip.date.month - 1]}';
    final distanceDateText =
        '${trip.distanceKm.toStringAsFixed(1)} km · $dateFormatted';

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNeedsReview
              ? AppColors.amber.withValues(alpha: 0.6)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColor.scrimSoft,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
                    // Row 1: Destination Title (destName) on left, Distance & Date on right
                    AdaptiveRow(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isBusiness
                                ? destName
                                : (destName != 'Destination'
                                    ? destName
                                    : (isNeedsReview
                                        ? 'Unclassified trip'
                                        : 'Personal Drive')),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          distanceDateText,
                          style: const TextStyle(
                            fontFeatures: AppType.tabular,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

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
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              TripQuickResolveSheet.show(context,
                                  trip: trip, appState: appState);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColor.attentionTintSoft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColor.attentionTintStrong),
                              ),
                              child: const AdaptiveRow(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles,
                                      size: 11, color: AppColors.amberDark),
                                  SizedBox(width: 4),
                                  Text(
                                    '1-Tap Purpose',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.amberDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
