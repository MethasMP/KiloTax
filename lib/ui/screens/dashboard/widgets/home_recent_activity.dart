import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_detail_screen.dart';

/// 2026 Mobile UX Principle: Glanceable Live Heartbeat Widget
/// Displays the single latest recorded trip with clear destination, route origin,
/// and tax claim value, plus an intuitive 'View all →' shortcut to the full Trips Ledger.
class HomeRecentActivity extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;

  const HomeRecentActivity({
    super.key,
    required this.appState,
    this.onViewAll,
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
      return LucideIcons.user;
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
        // Section Header with 'View all →' Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            if (hasActivity && onViewAll != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onViewAll!();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all (${trips.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(LucideIcons.carFront, color: AppColors.muted, size: 28),
                  SizedBox(height: 10),
                  Text(
                    'No drives recorded yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your work drives will appear here automatically',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Glanceable Latest Drive Hero Card
          _buildLatestTripHero(context, trips.first),
        ],
      ],
    );
  }

  Widget _buildLatestTripHero(BuildContext context, Trip trip) {
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

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Destination + Claim
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),

                      // Origin Subtitle
                      if (hasDistinctRoute) ...[
                        const SizedBox(height: 2),
                        Text(
                          'from $originName',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Purpose + Date & Distance
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                trip.purpose.isNotEmpty
                                    ? trip.purpose
                                    : (isBusiness ? 'Work drive' : 'Personal drive'),
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
      ),
    );
  }
}
