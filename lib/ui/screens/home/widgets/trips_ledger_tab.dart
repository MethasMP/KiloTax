import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../cpk/cpk_trip_entry_screen.dart';
import '../../trips/trip_detail_screen.dart';
import '../../trips/trip_detection_screen.dart';
import '../../trips/trip_quick_resolve_sheet.dart';

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
            Row(
              children: [
                Text(
                  activeVehicle.regoPlate.isNotEmpty
                      ? activeVehicle.regoPlate
                      : activeVehicle.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  activeVehicle.taxMethod == TaxMethod.centsPerKm
                      ? '${totalClaimKm.toStringAsFixed(0)} / 5,000 km'
                      : 'Week ${appState.currentLogbookWeek}/12',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  claimAmountStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: activeVehicle.taxMethod == TaxMethod.centsPerKm
                ? 'Add CPK Trip'
                : 'Log Trip',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.deepNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.plus,
                  size: 18, color: AppColors.deepNavy),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (activeVehicle.taxMethod == TaxMethod.centsPerKm) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CpkTripEntryScreen(appState: appState),
                  ),
                );
              } else {
                TripDetectionScreen.show(context, appState);
              }
            },
          ),
          if (appState.vehicles.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.car,
                  color: AppColors.deepNavy, size: 20),
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
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 16,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 116.0, right: 4.0),
        child: FloatingActionButton(
          heroTag: 'trips_ledger_fab',
          onPressed: () {
            HapticFeedback.mediumImpact();
            if (activeVehicle.taxMethod == TaxMethod.centsPerKm) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CpkTripEntryScreen(appState: appState),
                ),
              );
            } else {
              TripDetectionScreen.show(context, appState);
            }
          },
          backgroundColor: AppColors.deepNavy,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: const CircleBorder(),
          child: const Icon(LucideIcons.plus, size: 24),
        ),
      ),
      body: Column(
        children: [
          // Segmented Filter Bar
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
                            t.classification == TripClassification.unclassified)
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
                  const Icon(LucideIcons.alertTriangle,
                      size: 16, color: AppColors.amberDark),
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
                        'Fast Review →',
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Elegant Apple-Style Route Icon Surface
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              size: 32,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Typography: Confident, Minimalist
                          const Text(
                            'No Trips Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your drives will appear here automatically as you travel.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: filteredTrips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      return _buildTripCard(filteredTrips[index], appState);
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
      return LucideIcons.user;
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
    return LucideIcons.briefcase;
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
      return const Color(0xFFD97706);
    }
    return AppColors.deepNavy;
  }

  Widget _buildTripCard(Trip trip, AppState appState) {
    final isBusiness = trip.classification == TripClassification.business;
    final isNeedsReview = trip.purpose.trim().isEmpty ||
        trip.purpose.contains('?') ||
        trip.classification == TripClassification.unclassified;

    final destName =
        _cleanPlaceName(trip.destinationAddress, fallback: 'Destination');
    final originName =
        _cleanPlaceName(trip.originAddress, fallback: 'Origin');
    final hasDistinctRoute = trip.originAddress != null &&
        trip.originAddress != trip.destinationAddress &&
        originName != destName;

    final icon = _getTripIcon(trip);
    final accentColor = _getTripAccentColor(trip, isNeedsReview, isBusiness);
    final claimAmount =
        trip.distanceKm * appState.activeTaxRule.centsPerKmRate;

    return Container(
      key: ValueKey(trip.id),
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
            color: Color(0x04000000),
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
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),

              // Main content area: structured hierarchy without horizontal crunch
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Primary Destination + Financial Value Claim
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
                        if (isBusiness)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              '+${Formatters.currency(claimAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF059669),
                              ),
                            ),
                          )
                        else
                          Text(
                            '${trip.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),

                    // Row 2: Route origin context (if distinct)
                    if (hasDistinctRoute) ...[
                      const SizedBox(height: 2),
                      Text(
                        'from $originName',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Row 3: Dedicated Purpose Slot + Date & Distance
                    Row(
                      children: [
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
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles,
                                      size: 11,
                                      color: AppColors.amberDark),
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
                        else
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                trip.purpose.isNotEmpty
                                    ? trip.purpose
                                    : 'Business drive',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isBusiness
                                      ? AppColors.deepNavy
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(width: 8),
                        const Spacer(),

                        // Clean, minimal metadata (no tiny micro-icons)
                        Text(
                          '${trip.distanceKm.toStringAsFixed(1)} km · ${Formatters.date(trip.date)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
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
}
