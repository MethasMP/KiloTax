import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../services/engine/bulky_tools_suggestion_engine.dart';
import 'trip_quick_resolve_sheet.dart';
import 'widgets/bulky_tools_toggle_chip.dart';
import 'widgets/trade_gear_registration_sheet.dart';
import '../../../core/theme/app_color.dart';

/// Screen: Trip Detail
/// High-signal, minimalist audit card designed for Australian sole traders & tradies.
/// Eliminates cognitive clutter, verbose addresses, and repetitive "Verified" status lists.
class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  final AppState appState;

  const TripDetailScreen({
    super.key,
    required this.trip,
    required this.appState,
  });

  static Future<void> show(BuildContext context,
      {required Trip trip, required AppState appState}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(trip: trip, appState: appState),
      ),
    );
  }

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip _localTrip;
  late final bool _isOriginHome;
  late final bool _isDestinationHome;

  @override
  void initState() {
    super.initState();
    _localTrip = widget.trip;
    final originLower = (widget.trip.originAddress ?? '').trim().toLowerCase();
    final destLower = (widget.trip.destinationAddress ?? '').trim().toLowerCase();
    _isOriginHome = originLower.contains('home') || originLower.contains('residence');
    _isDestinationHome = destLower.contains('home') || destLower.contains('residence');
  }

  bool get _isHomeCommute => _isOriginHome || _isDestinationHome;

  Trip get _currentTrip {
    try {
      return widget.appState.trips.firstWhere(
        (t) => t.id == _localTrip.id,
        orElse: () => _localTrip,
      );
    } catch (_) {
      return _localTrip;
    }
  }

  Future<void> _toggleBulkyTools(bool enabled) async {
    if (enabled && _isHomeCommute) {
      final primary = widget.appState.primaryVehicle;
      if (primary?.tradeToolsRegisteredAt == null) {
        final registered = await TradeGearRegistrationSheet.show(
          context,
          appState: widget.appState,
        );
        if (registered != true) {
          return;
        }
      }
    }

    _applyBulkyToolsUpdate(enabled);
  }

  void _updateClassification(TripClassification classification) {
    HapticFeedback.selectionClick();
    final current = _currentTrip;
    if (current.classification == classification) return;

    String newPurpose = current.purpose;
    if (classification == TripClassification.personal) {
      if (newPurpose.contains('Bulky Tools')) {
        newPurpose = newPurpose
            .replaceAll(' (Bulky Tools Carried)', '')
            .replaceAll('Bulky Tools Carried', '')
            .replaceAll('Bulky Tools', '')
            .trim();
      }
      if (newPurpose.isEmpty ||
          newPurpose == '?' ||
          newPurpose == 'Work Site' ||
          newPurpose == 'Client / Job') {
        newPurpose = 'Personal Drive';
      }
    } else if (classification == TripClassification.business) {
      if (newPurpose == 'Personal Drive' ||
          newPurpose == '?' ||
          newPurpose.isEmpty) {
        newPurpose = 'Client / Job';
      }
    }

    final updated = current.copyWith(
      classification: classification,
      purpose: newPurpose,
    );
    setState(() {
      _localTrip = updated;
    });
    widget.appState.updateTrip(updated);
  }

  void _applyBulkyToolsUpdate(bool qualifies) {
    HapticFeedback.mediumImpact();
    final current = _currentTrip;
    String newPurpose;
    if (qualifies) {
      if (!current.purpose.contains('Bulky Tools')) {
        newPurpose = (current.purpose.isEmpty || current.purpose == '?')
            ? 'Work Site (Bulky Tools Carried)'
            : '${current.purpose} (Bulky Tools Carried)';
      } else {
        newPurpose = current.purpose;
      }
    } else {
      newPurpose = current.purpose
          .replaceAll(' (Bulky Tools Carried)', '')
          .replaceAll('Bulky Tools Carried', '')
          .replaceAll('Bulky Tools', '')
          .trim();
      if (newPurpose.isEmpty) newPurpose = 'Work Site';
    }

    final updated = current.copyWith(
      purpose: newPurpose,
      classification: qualifies
          ? TripClassification.business
          : (_isHomeCommute ? TripClassification.personal : current.classification),
    );
    setState(() {
      _localTrip = updated;
    });
    widget.appState.updateTrip(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: qualifies ? AppColors.emerald : AppColors.deepNavy,
        content: Text(
          qualifies
              ? '✓ Bulky Tools exemption claimed (s 8-1)'
              : 'Bulky Tools removed',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _currentTrip;
    final appState = widget.appState;
    final bulkySuggestion = BulkyToolsSuggestionEngine.evaluate(trip);
    final isBulkyToolsActive = trip.purpose.contains('Bulky Tools');
    final isBusiness = trip.classification == TripClassification.business;
    final isPersonal = trip.classification == TripClassification.personal;

    final vehicle = appState.vehicles.firstWhere(
      (v) => v.id == trip.vehicleId,
      orElse: () =>
          appState.primaryVehicle ??
          Vehicle(
            id: trip.vehicleId,
            make: 'Vehicle',
            model: 'not set',
            regoPlate: '',
            initialOdometer: 0.0,
          ),
    );
    final vehicleName = vehicle.displayName.isNotEmpty
        ? vehicle.displayName
        : 'Vehicle not set';

    final origin = trip.originAddress ?? 'Home';
    final destination = trip.destinationAddress ?? 'Work Site';
    final hasPurpose = trip.purpose.isNotEmpty && !trip.purpose.contains('?');

    // Parse location titles and secondary addresses cleanly
    final originParts = origin.split(',');
    final originTitle = originParts.first.trim();
    final originSub = originParts.length > 1
        ? originParts.sublist(1).join(',').trim()
        : null;

    final destParts = destination.split(',');
    final destTitle = destParts.first.trim();
    final destSub =
        destParts.length > 1 ? destParts.sublist(1).join(',').trim() : null;

    final claimAmount = trip.distanceKm * appState.activeTaxRule.centsPerKmRate;

    return Scaffold(
      backgroundColor: AppColor.surfaceSunken,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Trip detail',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              TripQuickResolveSheet.show(
                context,
                trip: trip,
                appState: appState,
                onTripResolved: (resolved) {
                  setState(() {
                    _localTrip = resolved;
                  });
                },
              );
            },
            icon: const Icon(LucideIcons.pencil,
                size: 14, color: AppColors.deepNavy),
            label: const Text(
              'Edit',
              style: TextStyle(
                color: AppColors.deepNavy,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card 1: Route Timeline Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColor.scrimSoft,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.dateTime(trip.date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      if (trip.classification == TripClassification.business)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColor.positiveTint,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: AppColor.positiveTintStrong),
                          ),
                          child: Text(
                            vehicle.taxMethod == TaxMethod.logbook
                                ? 'ATO Business Trip'
                                : '+\$${claimAmount.toStringAsFixed(2)} ATO Claim',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColor.positiveStrong,
                            ),
                          ),
                        )
                      else if (trip.classification == TripClassification.personal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceSunken,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Personal (Private)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceSunken,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Unclassified',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Route Timeline
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dots & Connector line
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 38,
                            color: AppColors.border,
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.deepNavy,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Place Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              originTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (originSub != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                originSub,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              destTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (destSub != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                destSub,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.gauge,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.distance(trip.distanceKm),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Trip Parameters & Vehicle
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColor.scrimSoft,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1-Tap Classification Toggle Row
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                _updateClassification(TripClassification.business),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isBusiness
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isBusiness
                                    ? const [
                                        BoxShadow(
                                          color: AppColor.scrimSoft,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.briefcase,
                                    size: 15,
                                    color: isBusiness
                                        ? AppColors.deepNavy
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Business',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isBusiness
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isBusiness
                                          ? AppColors.deepNavy
                                          : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                _updateClassification(TripClassification.personal),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isPersonal
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isPersonal
                                    ? const [
                                        BoxShadow(
                                          color: AppColor.scrimSoft,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.user,
                                    size: 15,
                                    color: isPersonal
                                        ? AppColors.deepNavy
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Personal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isPersonal
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isPersonal
                                          ? AppColors.deepNavy
                                          : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  if (!isPersonal) ...[
                    _buildDetailRow(
                      icon: LucideIcons.briefcase,
                      label: 'Purpose',
                      value: hasPurpose ? trip.purpose : 'Needs attention',
                      isInteractive: true,
                      maxLines: 2,
                      valueColor:
                          hasPurpose ? AppColors.ink : AppColors.amberDark,
                      onTap: () {
                        TripQuickResolveSheet.show(
                          context,
                          trip: trip,
                          appState: appState,
                          onTripResolved: (resolved) {
                            setState(() {
                              _localTrip = resolved;
                            });
                          },
                        );
                      },
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    if (_isHomeCommute) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.hammer,
                                  size: 16, color: AppColors.muted),
                              SizedBox(width: 10),
                              Text(
                                'Heavy Tools & Gear (>20kg)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Required by ATO (TR 2021/1) to claim trips to/from home when no secure storage exists on site.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          BulkyToolsToggleChip(
                            isSelected: isBulkyToolsActive,
                            isSuggested: bulkySuggestion.isSuggested,
                            suggestionLabel: bulkySuggestion.badgeText,
                            estimatedDeductionDelta: claimAmount > 0
                                ? '+${Formatters.currency(claimAmount)} AUD'
                                : null,
                            onChanged: (val) => _toggleBulkyTools(val),
                          ),
                          if (isBulkyToolsActive) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color:
                                    AppColor.positiveTint.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColor.positiveStrong
                                      .withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 15,
                                    color: AppColor.positiveStrong,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '1-Tap Confirmed: Tools >20kg carried & no secure site storage (ATO TR 2021/1 & Vogt\'s Case)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColor.positiveInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),
                    ],
                  ],
                  _buildDetailRow(
                    icon: LucideIcons.car,
                    label: 'Vehicle',
                    value: vehicleName,
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  if (vehicle.taxMethod == TaxMethod.logbook)
                    _buildDetailRow(
                      icon: LucideIcons.fileSpreadsheet,
                      label: 'Odometer',
                      value:
                          '${trip.startOdometer.toStringAsFixed(0)} → ${trip.endOdometer.toStringAsFixed(0)} km',
                    )
                  else
                    _buildDetailRow(
                      icon: LucideIcons.receipt,
                      label: 'Tax Method',
                      value:
                          'Cents-per-km (${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}¢/km)',
                    ),
                  const Divider(height: 24, color: AppColors.border),
                  _buildDetailRow(
                    icon: LucideIcons.clipboardList,
                    label: 'Notes',
                    value: trip.jobReference?.isNotEmpty == true
                        ? trip.jobReference!
                        : 'No note added',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Done action
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isInteractive = false,
    Color? valueColor,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    final row = Row(
      crossAxisAlignment:
          maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 2.0 : 0),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 1.0 : 0),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.ink,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isInteractive) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: EdgeInsets.only(top: maxLines > 1 ? 2.0 : 0),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: row,
        ),
      );
    }

    return row;
  }
}
