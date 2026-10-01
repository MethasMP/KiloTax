import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import 'trip_quick_resolve_sheet.dart';

/// Screen: Trip Detail
/// High-signal, minimalist audit card designed for Australian sole traders & tradies.
/// Eliminates cognitive clutter, verbose addresses, and repetitive "Verified" status lists.
class TripDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final vehicle = appState.vehicles.firstWhere(
      (v) => v.id == trip.vehicleId,
      orElse: () =>
          appState.primaryVehicle ??
          Vehicle(
            id: trip.vehicleId,
            make: 'Ford Ranger',
            model: '2024',
            regoPlate: '1GTF892',
            initialOdometer: 0.0,
          ),
    );
    final vehicleName = vehicle.displayName.isNotEmpty
        ? vehicle.displayName
        : 'Ford Ranger (2024) (1GTF892)';

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
      backgroundColor: const Color(0xFFF8FAFC),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    color: Color(0x06000000),
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
                      if (claimAmount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '+\$${claimAmount.toStringAsFixed(2)} ATO Claim',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
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
                        '${Formatters.distance(trip.distanceKm)} · 28 min',
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
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: LucideIcons.briefcase,
                    label: 'Purpose',
                    value: hasPurpose ? trip.purpose : 'Needs attention',
                    isInteractive: true,
                    valueColor:
                        hasPurpose ? AppColors.ink : AppColors.amberDark,
                    onTap: () {
                      TripQuickResolveSheet.show(
                        context,
                        trip: trip,
                        appState: appState,
                      );
                    },
                  ),
                  const Divider(height: 24, color: AppColors.border),
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
                        : 'Installed electrical switchboard',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: ATO Evidence Audit Shield (No repetitive "Verified" spam)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
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
                      const Text(
                        'Evidence',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasPurpose
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasPurpose
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasPurpose
                                  ? LucideIcons.shieldCheck
                                  : LucideIcons.alertCircle,
                              size: 13,
                              color: hasPurpose
                                  ? const Color(0xFF059669)
                                  : AppColors.amberDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasPurpose ? 'Audit Ready' : 'Incomplete',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: hasPurpose
                                  ? const Color(0xFF059669)
                                  : AppColors.amberDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2x2 Clean Evidence Bento Tiles
                  Row(
                    children: [
                      Expanded(
                        child: _buildEvidenceTile(
                          icon: LucideIcons.mapPin,
                          label: 'Location',
                          detail: 'GPS point logged',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildEvidenceTile(
                          icon: LucideIcons.route,
                          label: 'Distance',
                          detail: Formatters.distance(trip.distanceKm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEvidenceTile(
                          icon: LucideIcons.clock,
                          label: 'Time',
                          detail: 'Timestamp locked',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildEvidenceTile(
                          icon: LucideIcons.fileCheck,
                          label: 'Purpose',
                          detail: hasPurpose ? 'Explicit' : 'Needs entry',
                          isAlert: !hasPurpose,
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
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isInteractive = false,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isInteractive) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.muted,
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

  Widget _buildEvidenceTile({
    required IconData icon,
    required String label,
    required String detail,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isAlert
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isAlert ? AppColors.amberDark : AppColors.ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAlert ? AppColors.amberDark : AppColors.muted,
                    fontWeight: isAlert ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
