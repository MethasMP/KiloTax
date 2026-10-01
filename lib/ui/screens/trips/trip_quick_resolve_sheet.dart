import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';

/// Spec #7 & #8: Fast, Frictionless Trip Purpose Classification
/// Ultra-clean thumb-first ergonomics for tradies & sole traders.
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

  void _resolveTrip(
      BuildContext context, String purpose, TripClassification classification) {
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
      final isBiz = classification == TripClassification.business;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isBiz ? AppColors.emerald : AppColors.deepNavy,
          content: Text(
            isBiz
                ? '✓ Claim recorded — $purpose'
                : '✓ Classified as Personal drive',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawDestination = trip.destinationAddress ?? 'Trip Destination';
    final destinationParts = rawDestination.split(',');
    final destTitle = destinationParts.first.trim();
    final destSub = destinationParts.length > 1
        ? destinationParts.sublist(1).join(',').trim()
        : null;

    final claimEst = trip.distanceKm * appState.activeTaxRule.centsPerKmRate;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Trip Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    LucideIcons.mapPin,
                    color: AppColors.deepNavy,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.distance(trip.distanceKm),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (claimEst > 0)
                      Text(
                        '~\$${claimEst.toStringAsFixed(0)} claim',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action prompt - clean & uncluttered
          const Text(
            'What was this trip for?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),

          // 4 Purpose Buttons (Clean, ergonomic 2x2 grid)
          Row(
            children: [
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.briefcase,
                  label: 'Client / Job',
                  subtitle: 'Site work, client job',
                  accentColor: AppColors.workBlue,
                  onTap: () => _resolveTrip(
                      context, 'Client / Job', TripClassification.business),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.shoppingBag,
                  label: 'Supplier / Bunnings',
                  subtitle: 'Materials, tools, parts',
                  accentColor: AppColors.emerald,
                  onTap: () => _resolveTrip(context, 'Supplier / Materials',
                      TripClassification.business),
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
                  subtitle: 'Inspection, build site',
                  accentColor: AppColors.amber,
                  onTap: () => _resolveTrip(context, 'Work Site Inspection',
                      TripClassification.business),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickPurposeButton(
                  icon: LucideIcons.user,
                  label: 'Personal Drive',
                  subtitle: 'Private, non-tax trip',
                  accentColor: AppColors.muted,
                  onTap: () => _resolveTrip(
                      context, 'Personal Drive', TripClassification.personal),
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
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickPurposeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
