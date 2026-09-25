import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';

/// Spec #7 & #8: 1-Tap Automatic Capture -> Human Confirmation
/// "Instead of 10 fields: What was this trip for?
///  [ Client / Job ] [ Supplier ] [ Work site ] [ Other ] -> Done."
class TripQuickResolveSheet extends StatelessWidget {
  final Trip trip;
  final AppState appState;

  final void Function(Trip resolvedTrip)? onTripResolved;

  const TripQuickResolveSheet({
    super.key,
    required this.trip,
    required this.appState,
    this.onTripResolved,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required AppState appState,
    void Function(Trip resolvedTrip)? onTripResolved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripQuickResolveSheet(
        trip: trip,
        appState: appState,
        onTripResolved: onTripResolved,
      ),
    );
  }

  void _resolveTrip(BuildContext context, String purpose, TripClassification classification) {
    HapticFeedback.mediumImpact();
    final updatedTrip = Trip(
      id: trip.id,
      vehicleId: trip.vehicleId,
      distanceKm: trip.distanceKm,
      date: trip.date,
      purpose: purpose,
      startOdometer: trip.startOdometer,
      endOdometer: trip.endOdometer,
      classification: classification,
      originAddress: trip.originAddress,
      destinationAddress: trip.destinationAddress,
      linkedExpenseIds: trip.linkedExpenseIds,
    );

    appState.updateTrip(updatedTrip);
    Navigator.of(context).pop();

    if (onTripResolved != null) {
      onTripResolved!(updatedTrip);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.emerald,
          content: Text('✓ Classified as "$purpose" — ATO claim audit-proof!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleDestination = trip.destinationAddress ?? 'Detected Trip Destination';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.mapPin, color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detected Trip Completed', style: AppTextStyles.captionMedium),
                    Text(
                      titleDestination,
                      style: AppTextStyles.cardPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  Formatters.distance(trip.distanceKm),
                  style: AppTextStyles.cardPrimarySubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What was this trip for? (1-Tap)',
            style: AppTextStyles.cardPrimary,
          ),
          const SizedBox(height: 4),
          const Text(
            'ATO requires an explicit business purpose to audit-proof your deduction.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          // 4 Big 1-Tap Buttons (Spec #7 & #8)
          Row(
            children: [
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.briefcase,
                  label: 'Client / Job',
                  color: AppColors.workBlue,
                  onTap: () => _resolveTrip(context, 'Client / Job', TripClassification.business),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.shoppingCart,
                  label: 'Supplier / Bunnings',
                  color: AppColors.emerald,
                  onTap: () => _resolveTrip(context, 'Supplier / Materials', TripClassification.business),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.hardHat,
                  label: 'Work Site',
                  color: AppColors.amber,
                  onTap: () => _resolveTrip(context, 'Work Site Inspection', TripClassification.business),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.home,
                  label: 'Personal / Other',
                  color: AppColors.muted,
                  onTap: () => _resolveTrip(context, 'Personal Drive', TripClassification.personal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPurposeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickPurposeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
