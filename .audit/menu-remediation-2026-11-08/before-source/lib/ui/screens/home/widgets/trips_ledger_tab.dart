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
import '../../../../core/theme/app_color.dart';

class TripsLedgerTab extends StatefulWidget {
  final AppState appState;

  const TripsLedgerTab({super.key, required this.appState});

  @override
  State<TripsLedgerTab> createState() => _TripsLedgerTabState();
}

class _TripsLedgerTabState extends State<TripsLedgerTab> {
  String _selectedFilter =
      'All'; // 'All', 'Needs review', 'Business', 'Personal'
  String?
      _selectedVehicleId; // null = follow active primary vehicle, or specific vehicle id

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final primaryVeh = appState.primaryVehicle;
    final activeVehicleId = _selectedVehicleId ?? primaryVeh?.id;

    // Vehicle-isolated trip streams (Prevents cross-vehicle pollution in ATO audit logs)
    final vehicleTrips = activeVehicleId != null
        ? appState.trips.where((t) => t.vehicleId == activeVehicleId).toList()
        : appState.trips;

    final filteredTrips = vehicleTrips.where((t) {
      if (_selectedFilter == 'Needs review') {
        return t.purpose.trim().isEmpty ||
            t.purpose.contains('?') ||
            t.classification == TripClassification.unclassified;
      }
      if (_selectedFilter == 'Business') {
        return t.classification == TripClassification.business;
      }
      if (_selectedFilter == 'Personal') {
        return t.classification == TripClassification.personal;
      }
      return true;
    }).toList();

    final activeVehicle = appState.vehicles.firstWhere(
      (v) => v.id == activeVehicleId,
      orElse: () =>
          primaryVeh ??
          Vehicle(
            id: 'default',
            make: 'All Vehicles',
            model: '',
            regoPlate: '',
            initialOdometer: 0.0,
          ),
    );

    final totalClaimKm = vehicleTrips
        .where((t) => t.isBusiness)
        .fold<double>(0.0, (sum, t) => sum + t.distanceKm);
    final claimAmountStr = Formatters.currency(
      activeVehicle.taxMethod == TaxMethod.centsPerKm
          ? (totalClaimKm.clamp(0.0, 5000.0) *
              appState.activeTaxRule.centsPerKmRate)
          : appState.taxSummary.logbookClaim,
    );

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
              'Trips Ledger',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              activeVehicle.displayName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actions: [
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
                    child: Row(
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
      body: Column(
        children: [
          // Segmented Filter Bar (Only shown when trips exist to avoid zero-counter clutter)
          if (vehicleTrips.isNotEmpty)
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('All', vehicleTrips.length),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Needs review',
                      vehicleTrips
                          .where((t) =>
                              t.purpose.trim().isEmpty ||
                              t.purpose.contains('?') ||
                              t.classification ==
                                  TripClassification.unclassified)
                          .length,
                      isAlert: vehicleTrips.any((t) =>
                          t.purpose.trim().isEmpty ||
                          t.purpose.contains('?') ||
                          t.classification == TripClassification.unclassified),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Business',
                      vehicleTrips
                          .where((t) =>
                              t.classification == TripClassification.business)
                          .length,
                    ),
                    if (activeVehicle.taxMethod == TaxMethod.logbook) ...[
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
          if (vehicleTrips.any((t) =>
              t.purpose.trim().isEmpty ||
              t.purpose.contains('?') ||
              t.classification == TripClassification.unclassified))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.amberDark.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.warning,
                      size: AppIconSize.inline, color: AppColors.amberDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${vehicleTrips.where((t) => t.purpose.trim().isEmpty || t.purpose.contains('?') || t.classification == TripClassification.unclassified).length} unclassified trips waiting',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final unclassifiedTrip = vehicleTrips.firstWhere((t) =>
                          t.purpose.trim().isEmpty ||
                          t.purpose.contains('?') ||
                          t.classification == TripClassification.unclassified);
                      TripQuickResolveSheet.show(context,
                          trip: unclassifiedTrip, appState: appState);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.deepNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Fast Review',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppColors.border),

          // Trips List View
          Expanded(
            child: filteredTrips.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Top Vehicle Ledger Summary Strip: Tailored Oxford Navy & Champagne Brass Hairline
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceNavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColor.navy600,
                              width: 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColor.scrimSoft,
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColor.positiveBright,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'FY25 AUDIT-PROOF LEDGER',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColor.navy300,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      claimAmountStr,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.7,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColor.navyLine,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: AppColor.navyRaised,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColor.navyLine,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      activeVehicle.taxMethod ==
                                              TaxMethod.centsPerKm
                                          ? '${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}¢ / KM'
                                          : 'LOGBOOK',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColor.brandTintStrong,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${totalClaimKm.toStringAsFixed(1)} / 5,000 km',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColor.onNavyMuted,
                                      letterSpacing: -0.1,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Centerpiece: Rugged Heritage Telemetry Hub (Heavy-duty Warm Alabaster Card with Tailored Insets)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColor.line,
                              width: 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColor.scrimSoft,
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  // British Racing Green Wax-Seal Instrument Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColor.positive,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColor.positive
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        LucideIcons.compass,
                                        size: AppIconSize.control,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 6.5,
                                              height: 6.5,
                                              decoration: const BoxDecoration(
                                                color: AppColor.positiveStrong,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'TELEMETRY STANDBY',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColor.positiveStrong,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Automated Trip Substantiation',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColor.ink,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(
                                  height: 1, color: AppColor.hairline),
                              const SizedBox(height: 16),

                              // Rugged Heritage Workflow: 3 Engineered Steps
                              _buildWorkflowStepRow(
                                stepNumber: '1',
                                icon: AppIcons.odometer,
                                title: 'Threshold Trigger (15 km/h)',
                                description:
                                    'WGS-84 sensor fusion captures coordinate fixes in background.',
                              ),
                              const SizedBox(height: 14),
                              _buildWorkflowStepRow(
                                stepNumber: '2',
                                icon: LucideIcons.lock,
                                title: 'Tamper-Proof Ledger Seal',
                                description:
                                    'Locks arrival coordinates and start/end odometer readings.',
                              ),
                              const SizedBox(height: 14),
                              _buildWorkflowStepRow(
                                stepNumber: '3',
                                icon: LucideIcons.receiptText,
                                title: 'Instant 91¢/km Substantiation',
                                description:
                                    'Accrues into your tax dossier ready for accountant sign-off.',
                              ),

                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColor.brand,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(AppIcons.add,
                                      size: AppIconSize.inline),
                                  label: Text(
                                    activeVehicle.taxMethod ==
                                            TaxMethod.centsPerKm
                                        ? 'Add Trip (+91¢/km)'
                                        : 'Record Drive',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    if (activeVehicle.taxMethod ==
                                        TaxMethod.centsPerKm) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CpkTripEntryScreen(
                                              appState: appState),
                                        ),
                                      );
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              LogbookTripEntryScreen(
                                                  appState: appState),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3. ATO Compliance Seal: Understated Statutory Grounding
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColor.line, width: 0.8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                LucideIcons.shieldCheck,
                                size: AppIconSize.inline,
                                color: AppColor.positiveStrong,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Compliant with ITAA 1997 Subdiv 28-B • Continuous GPS evidence chain',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.inkMuted,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: filteredTrips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      return _buildTripCard(
                          filteredTrips[index], appState, activeVehicle);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _cleanPlaceName(String? raw, {String fallback = 'Destination'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final parts = raw.split(',');
    final first = parts.first.trim();
    return first.isNotEmpty ? first : fallback;
  }

  IconData _getTripIcon(Trip trip) {
    if (trip.purpose.trim().isEmpty ||
        trip.purpose.contains('?') ||
        trip.classification == TripClassification.unclassified) {
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
    final isNeedsReview = trip.purpose.trim().isEmpty ||
        trip.purpose.contains('?') ||
        trip.classification == TripClassification.unclassified;

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
          child: Row(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isBusiness
                                ? destName
                                : (destName != 'Destination'
                                    ? destName
                                    : 'Personal Drive'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          distanceDateText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Row 2: Route origin context on left, Status / Claim Badge on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasDistinctRoute)
                          Expanded(
                            child: Text(
                              'from $originName',
                              style: const TextStyle(
                                fontSize: 12,
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
                                fontSize: 11,
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
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColor.attentionTintSoft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColor.attentionTintStrong),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles,
                                      size: 11, color: AppColors.amberDark),
                                  SizedBox(width: 4),
                                  Text(
                                    '1-Tap Purpose',
                                    style: TextStyle(
                                      fontSize: 11,
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
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
                                  fontSize: 11,
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
                                fontSize: 11,
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
              content: const Row(
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
              content: Row(
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
        child: const Row(
          children: [
            Icon(AppIcons.business,
                color: Colors.white, size: AppIconSize.control),
            SizedBox(width: 8),
            Text(
              'Business',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Personal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

  Widget _buildWorkflowStepRow({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColor.surfaceSunken,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColor.line, width: 0.8),
          ),
          child: Center(
            child: Icon(icon, size: AppIconSize.inline, color: AppColor.brand),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNumber. $title',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColor.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColor.inkSubtle,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
