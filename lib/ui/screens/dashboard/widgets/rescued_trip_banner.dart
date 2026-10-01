import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/in_flight_trip.dart';
import '../../../../services/tracking/geocoding_service.dart';
import '../../../../state/app_state.dart';

/// Banner widget displayed at the top of Dashboard when an in-flight trip
/// has been resurrected after an unexpected iOS app kill or crash.
/// Built with ultra-lazy 1-tap ergonomics for tradies sitting in their ute.
class RescuedTripBanner extends StatefulWidget {
  final AppState appState;
  final InFlightTrip orphanedTrip;

  const RescuedTripBanner({
    super.key,
    required this.appState,
    required this.orphanedTrip,
  });

  @override
  State<RescuedTripBanner> createState() => _RescuedTripBannerState();
}

class _RescuedTripBannerState extends State<RescuedTripBanner> {
  bool _isResolvingAddresses = true;
  String _startAddress = 'Starting Point';
  String _endAddress = 'Interrupted Location';
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _resolveAddresses();
  }

  Future<void> _resolveAddresses() async {
    final trip = widget.orphanedTrip;
    String start = trip.originAddress ?? 'Trip Origin';
    String end = trip.lastAddress ?? 'Interrupted Site';

    try {
      if (trip.originAddress == null && trip.startLatitude != 0.0) {
        start = await GeocodingService.reverseGeocode(
          trip.startLatitude,
          trip.startLongitude,
        );
      }
      if (trip.lastAddress == null && trip.lastLatitude != 0.0) {
        end = await GeocodingService.reverseGeocode(
          trip.lastLatitude,
          trip.lastLongitude,
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _startAddress = start;
        _endAddress = end;
        _isResolvingAddresses = false;
      });
    }
  }

  Future<void> _claimTrip() async {
    HapticFeedback.heavyImpact();
    setState(() => _isClaiming = true);

    await widget.appState.rescueOrphanedTrip(
      saveToLogbook: true,
      resolvedOrigin: _startAddress,
      resolvedDestination: _endAddress,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.deepNavy,
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: AppColors.emerald, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trip saved to Logbook! +${widget.orphanedTrip.distanceKm.toStringAsFixed(1)} km added for ATO.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _discardTrip() async {
    HapticFeedback.lightImpact();
    await widget.appState.discardOrphanedTrip();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.orphanedTrip;
    final rate = widget.appState.activeTaxRule.centsPerKmRate;
    final taxDeductionAud = trip.distanceKm * rate;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Warm amber background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFDE68A), // Amber highlight border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Status badge & Dismiss
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 13, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'RESCUED IN-FLIGHT DRIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${trip.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _discardTrip,
                  icon: const Icon(LucideIcons.x, size: 16, color: AppColors.muted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: 'Discard',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Main Message
            const Text(
              'Your previous drive was interrupted when the app closed. KiloTax protected your tax deduction data.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Route & Value summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.mapPin, size: 12, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _isResolvingAddresses ? 'Resolving route...' : '$_startAddress → $_endAddress',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepNavy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+\$${taxDeductionAud.toStringAsFixed(2)} Tax Claim',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions: 1-Tap Save to Logbook vs Discard
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isClaiming ? null : _claimTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.fileCheck, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Save to ATO Logbook',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _discardTrip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF92400E),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
