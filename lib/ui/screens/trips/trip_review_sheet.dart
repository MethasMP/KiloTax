import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';
import 'widgets/cpk_batch_review_sheet.dart';

/// Spec #2 & #17: [ Review trips ] Sheet
/// Allows tradies to quickly inspect recorded trips, classifications and deduction values
class TripReviewSheet extends StatelessWidget {
  final AppState appState;

  const TripReviewSheet({super.key, required this.appState});

  static Future<void> show(BuildContext context, AppState appState) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripReviewSheet(appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = appState.trips;
    final businessKm = trips
        .where((t) => t.classification == TripClassification.business)
        .fold(0.0, (sum, t) => sum + t.distanceKm);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.car, color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trip Review & Audit Trail', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    Text('${trips.length} total trips logged (${Formatters.distance(businessKm)} business)', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              if (appState.missingComplianceTrips.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.emeraldLight,
                    foregroundColor: AppColors.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text('Batch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    CpkBatchReviewSheet.show(context, appState);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (trips.isEmpty) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.mapPin, size: 48, color: AppColors.muted),
                    SizedBox(height: 12),
                    Text('No trips recorded yet', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Use the + button on Dashboard to log your first drive.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.separated(
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final trip = trips[index];
                  final isBusiness = trip.classification == TripClassification.business;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isBusiness ? AppColors.workBlueLight : AppColors.muted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isBusiness ? LucideIcons.briefcase : LucideIcons.home,
                            color: isBusiness ? AppColors.workBlue : AppColors.muted,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      trip.purpose.isNotEmpty ? trip.purpose : 'Unknown Purpose',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                                    ),
                                  ),
                                  Text(
                                    Formatters.distance(trip.distanceKm),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.ink),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    Formatters.dateTime(trip.date),
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBusiness ? AppColors.emeraldLight : AppColors.background,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isBusiness ? 'Business (\$${(trip.distanceKm * AppConstants.centsPerKmRate2026).toStringAsFixed(2)} claim)' : 'Personal',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isBusiness ? AppColors.emerald : AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (trip.originAddress != null && trip.destinationAddress != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${trip.originAddress} → ${trip.destinationAddress}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
