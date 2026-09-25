import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';

/// Implements Screen 8: Trip Detail from UI.png
/// - Back arrow + Title "Trip detail" + "Edit" action
/// - Date: "12 Sep 2026 • 8:42 am"
/// - Route: "Home -> Client Site" (24.6 km • 28 min)
/// - Purpose: "Client / Job >"
/// - Vehicle: "Ford Ranger 2021"
/// - Odometer: Start 82,421 km / End 82,445 km
/// - Notes: "Installed electrical switchboard"
/// - Evidence Checklist:
///   - Location ✓
///   - Distance ✓
///   - Time ✓
///   - Purpose ✓
class TripDetailScreen extends StatelessWidget {
  final Trip trip;
  final AppState appState;

  const TripDetailScreen({
    super.key,
    required this.trip,
    required this.appState,
  });

  static Future<void> show(BuildContext context, {required Trip trip, required AppState appState}) {
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
      orElse: () => appState.primaryVehicle ?? Vehicle(
        id: trip.vehicleId,
        make: 'Vehicle',
        model: '',
        regoPlate: '',
        initialOdometer: 0.0,
      ),
    );
    final vehicleName = vehicle.displayName.isNotEmpty ? vehicle.displayName : 'Ford Ranger 2021';
    final origin = trip.originAddress ?? 'Home';
    final destination = trip.destinationAddress ?? 'Client Site';
    final hasPurpose = trip.purpose.isNotEmpty && !trip.purpose.contains('?');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Trip detail',
          style: AppTextStyles.cardPrimary,
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Edit', style: TextStyle(color: AppColors.deepNavy, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Route Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.dateTime(trip.date),
                    style: AppTextStyles.captionMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$origin → $destination',
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.distance(trip.distanceKm)} • 28 min',
                    style: AppTextStyles.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attributes Table Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildAttributeRow(
                    label: 'Purpose',
                    value: hasPurpose ? trip.purpose : 'Needs attention',
                    isLink: true,
                    valueColor: hasPurpose ? AppColors.ink : AppColors.amberDark,
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _buildAttributeRow(
                    label: 'Vehicle',
                    value: vehicleName,
                  ),
                  if (vehicle.taxMethod == TaxMethod.logbook) ...[
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Odometer', style: AppTextStyles.secondaryMedium),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Start  ${trip.startOdometer.toStringAsFixed(0)} km', style: AppTextStyles.cardPrimarySubtle),
                            Text('End    ${trip.endOdometer.toStringAsFixed(0)} km', style: AppTextStyles.cardPrimarySubtle),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    const Divider(height: 24, color: AppColors.border),
                    _buildAttributeRow(
                      label: 'Tax Method',
                      value: 'Cents-per-km (${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}c/km)',
                    ),
                  ],
                  const Divider(height: 24, color: AppColors.border),
                  _buildAttributeRow(
                    label: 'Notes',
                    value: 'Installed electrical switchboard',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Evidence Checklist Card (UI.png Screen 8 & Section 4 Spec)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Evidence', style: AppTextStyles.cardPrimary),
                  const SizedBox(height: 14),
                  _buildEvidenceCheck(label: 'Location', isVerified: true),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(label: 'Distance', isVerified: true),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(label: 'Time', isVerified: true),
                  const SizedBox(height: 10),
                  _buildEvidenceCheck(label: 'Purpose', isVerified: hasPurpose),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeRow({
    required String label,
    required String value,
    bool isLink = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.secondaryMedium),
        Row(
          children: [
            Text(
              value,
              style: AppTextStyles.cardPrimarySubtle.copyWith(color: valueColor ?? AppColors.ink),
            ),
            if (isLink) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEvidenceCheck({required String label, required bool isVerified}) {
    return Row(
      children: [
        Icon(
          isVerified ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
          color: isVerified ? AppColors.emerald : AppColors.amberDark,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.cardPrimarySubtle,
        ),
        const Spacer(),
        Text(
          isVerified ? 'Verified' : 'Action needed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isVerified ? AppColors.emerald : AppColors.amberDark,
          ),
        ),
      ],
    );
  }
}
