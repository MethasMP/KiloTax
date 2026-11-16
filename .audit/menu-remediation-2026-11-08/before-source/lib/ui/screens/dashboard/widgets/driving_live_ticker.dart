import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/trip.dart';
import '../../../../services/tracking/geocoding_service.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_detection_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';

/// Spotify-Inspired Telemetry Mini-Player / Live Driving Ticker
///
/// Displays real-time drive metrics (km and tax saved ticker),
/// animated status breathing jewel, and media-style controls (Stop & Save, Expand HUD).
class DrivingLiveTicker extends StatelessWidget {
  final AppState appState;

  const DrivingLiveTicker({super.key, required this.appState});

  void _onCapsuleTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripLiveTrackingScreen(appState: appState),
      ),
    );
  }

  void _onStopDrive(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final finalDistance =
        double.parse(appState.activeDriveDistanceKm.toStringAsFixed(2));
    final lastOdo = appState.currentOdometer;

    String? origin = appState.activeDriveOriginAddress;
    String? destination;

    try {
      if (origin == null && appState.activeDriveStartPosition != null) {
        origin = await GeocodingService.reverseGeocode(
          appState.activeDriveStartPosition!.latitude,
          appState.activeDriveStartPosition!.longitude,
        );
      }
      if (appState.activeDriveLastPosition != null) {
        destination = await GeocodingService.reverseGeocode(
          appState.activeDriveLastPosition!.latitude,
          appState.activeDriveLastPosition!.longitude,
        );
      } else {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          destination = await GeocodingService.reverseGeocode(
            pos.latitude,
            pos.longitude,
          );
        }
      }
    } catch (e) {
      debugPrint('[DrivingLiveTicker] Geocoding reverse resolution: $e');
    }

    final detectedTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: appState.primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: finalDistance > 0 ? finalDistance : 0.1,
      date: DateTime.now(),
      purpose: '',
      startOdometer: lastOdo,
      endOdometer: lastOdo + (finalDistance > 0 ? finalDistance : 0.1),
      originAddress: origin,
      destinationAddress: destination,
    );

    appState.endLiveDrive();

    if (context.mounted) {
      TripDetectionScreen.show(context, appState, trip: detectedTrip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = appState.activeDriveDistanceKm;
    final taxSaved = appState.activeDriveTaxSavedAud;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCapsuleTap(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Animated Equalizer Bars (Universal sign of active background process)
                const _EqualizerBars(),
                const SizedBox(width: 10),

                // Metrics: Live Ticker & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+\$${taxSaved.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Recording in background',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Media Control: Stop and log the drive. Ending a drive runs two
                // sequential geocode round-trips, so it must not be re-enterable.
                _StopDriveButton(onStop: () => _onStopDrive(context)),
                const SizedBox(width: 6),

                // Media Control: View Full HUD (Expand icon)
                Semantics(
                  button: true,
                  label: 'Open full tracking view',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _onCapsuleTap(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        LucideIcons.maximize2,
                        size: 16,
                        color: AppColors.deepNavy,
                      ),
                    ),
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

/// Minimal Live Telemetry Status Jewel (Subtle breathing pulse instead of audio equalizer bars)
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.10 + (t * 0.08)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Stop control for an in-progress drive.
///
/// Holds a re-entry latch because ending a drive performs two sequential
/// reverse-geocode round-trips; a second tap during that window would create a
/// duplicate trip. Also carries the 44dp minimum target and the semantic label
/// the bare text row previously lacked.
class _StopDriveButton extends StatefulWidget {
  final VoidCallback onStop;

  const _StopDriveButton({required this.onStop});

  @override
  State<_StopDriveButton> createState() => _StopDriveButtonState();
}

class _StopDriveButtonState extends State<_StopDriveButton> {
  bool _isStopping = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Stop recording and log this drive',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _isStopping
            ? null
            : () {
                setState(() => _isStopping = true);
                widget.onStop();
              },
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColor.criticalTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColor.criticalTintStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.square,
                  size: 12, color: AppColors.crimson),
              const SizedBox(width: 5),
              Text(
                _isStopping ? 'Saving' : 'Stop',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimson,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
