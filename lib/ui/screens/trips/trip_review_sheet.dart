import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import 'trip_detail_screen.dart';
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
    final trips = appState.evidenceReview.trips;
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;
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
                child: const Icon(LucideIcons.car,
                    color: AppColors.workBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Review trips',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink)),
                    Text(
                        '${trips.length} total trips logged (${Formatters.distance(businessKm)} business)',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              if (!isLogbook && appState.missingComplianceTrips.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.emeraldLight,
                    foregroundColor: AppColors.emerald,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text('Batch',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    CpkBatchReviewSheet.show(navigator.context, appState);
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.mapPin,
                        size: 48, color: AppColor.inkSubtle),
                    const SizedBox(height: 12),
                    const Text(
                      'No trips logged for this vehicle yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColor.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Auto-GPS or manual trips appear here for ATO review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColor.inkSubtle),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColor.brand,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add a trip'),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(MaterialPageRoute<void>(
                          builder: (_) => isLogbook
                              ? LogbookTripEntryScreen(appState: appState)
                              : CpkTripEntryScreen(appState: appState),
                        ));
                      },
                    ),
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
                  final isBusiness =
                      trip.classification == TripClassification.business;
                  final purposeLabel = trip.purpose.isNotEmpty
                      ? trip.purpose
                      : 'Purpose not added';

                  return Semantics(
                    button: true,
                    label:
                        'Open trip $purposeLabel, ${Formatters.distance(trip.distanceKm)}',
                    child: Material(
                      color: AppColor.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: R.cardR,
                        side: const BorderSide(color: AppColor.hairline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => TripDetailScreen.show(
                          context,
                          trip: trip,
                          appState: appState,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isBusiness
                                        ? AppColors.workBlueLight
                                        : AppColor.surfaceSunken,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isBusiness
                                        ? LucideIcons.briefcase
                                        : LucideIcons.home,
                                    color: isBusiness
                                        ? AppColors.workBlue
                                        : AppColor.inkSubtle,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              purposeLabel,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                  color: AppColor.ink),
                                            ),
                                          ),
                                          Text(
                                            Formatters.distance(
                                                trip.distanceKm),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                color: AppColor.ink),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            Formatters.dateTime(trip.date),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColor.inkSubtle),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isBusiness
                                                  ? AppColor.positiveTint
                                                  : AppColor.surfaceMuted,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isBusiness
                                                  ? (isLogbook
                                                      ? 'Business'
                                                      : 'Business (\$${(trip.distanceKm * appState.activeTaxRule.centsPerKmRate).toStringAsFixed(2)} claim)')
                                                  : 'Personal',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isBusiness
                                                    ? AppColor.positiveStrong
                                                    : AppColor.inkSubtle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (trip.originAddress != null &&
                                          trip.destinationAddress != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${trip.originAddress} → ${trip.destinationAddress}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColor.inkSubtle),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
