import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_detail_screen.dart';
import '../../trips/trip_detection_screen.dart';
import '../../../../core/theme/app_color.dart';

/// 2026 Mobile UX Principle: Glanceable Live Heartbeat Widget
/// Displays the single latest recorded trip with clear destination, route origin,
/// and tax claim value, plus an intuitive 'View all →' shortcut to the full Trips Ledger.
class HomeRecentActivity extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  final VoidCallback? onLogDrive;

  const HomeRecentActivity({
    super.key,
    required this.appState,
    this.onViewAll,
    this.onLogDrive,
  });

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
        text.contains('timber') ||
        text.contains('depot') ||
        text.contains('trade')) {
      return LucideIcons.shoppingBag;
    }
    if (text.contains('site') ||
        text.contains('inspection') ||
        text.contains('reno') ||
        text.contains('fitout') ||
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

  @override
  Widget build(BuildContext context) {
    final primaryVehId = appState.primaryVehicle?.id;
    final trips = primaryVehId != null
        ? appState.trips.where((t) => t.vehicleId == primaryVehId).toList()
        : appState.trips;
    final hasActivity = trips.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Recent Activity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (hasActivity && onViewAll != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onViewAll!();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  alignment: Alignment.centerRight,
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all (${trips.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        AppIcons.forward,
                        size: AppIconSize.inline,
                        color: AppColors.brandPrimary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!hasActivity)
          _buildEmptyState(context)
        else ...[
          // Glanceable Latest Drive Hero Card
          _buildLatestTripHero(context, trips.first),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.vehicle,
              color: AppColors.brandPrimary,
              size: AppIconSize.navigation,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No drives recorded yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Work drives record automatically while moving, or you can log a trip right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          // Action Buttons: Touch Target >= 44x44
          SizedBox(
            height: 46,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (onLogDrive != null) {
                  onLogDrive!();
                } else {
                  TripDetectionScreen.show(context, appState);
                }
              },
              icon: const Icon(
                AppIcons.add,
                size: AppIconSize.inline,
                color: Colors.white,
              ),
              label: const Text(
                'Log Drive Manually',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestTripHero(BuildContext context, Trip trip) {
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
    final vehicle = appState.vehicles.cast<Vehicle?>().firstWhere(
          (v) => v?.id == trip.vehicleId,
          orElse: () => appState.primaryVehicle,
        );
    final isLogbook = trip.taxMethod == TaxMethod.logbook ||
        (vehicle?.taxMethod == TaxMethod.logbook);

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

    return Container(
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
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            TripDetailScreen.show(context, trip: trip, appState: appState);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 19),
                ),
                const SizedBox(width: 14),

                // Main Info: Clean 2-Row Layout
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Destination Title on left, Distance & Date on right
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
                                fontSize: 15,
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

                      // Row 2: Origin subtitle / Category Chip on left, Claim/Status Badge on right
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
                          else
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
                            ),
                          const SizedBox(width: 8),
                          if (isBusiness) ...[
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
                            const Text(
                              'Personal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
