import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/sensor_fusion_tracking_engine.dart';
import '../../../services/tracking/geocoding_service.dart';
import 'trip_detection_screen.dart';

/// Screen: Genuine Hardware GPS Live Tracking HUD with Tesla Sensor Fusion & Dead Reckoning
/// Connects directly to device CoreLocation/Android Location sensor.
/// Zero fake simulation math: speed is 0 km/h and distance is 0.00 km when stationary.
class TripLiveTrackingScreen extends StatefulWidget {
  final AppState appState;
  final String originAddress;
  final String initialPurpose;

  const TripLiveTrackingScreen({
    super.key,
    required this.appState,
    this.originAddress = 'Current GPS Location',
    this.initialPurpose = 'Client / Job',
  });

  @override
  State<TripLiveTrackingScreen> createState() => _TripLiveTrackingScreenState();
}

class _TripLiveTrackingScreenState extends State<TripLiveTrackingScreen> with SingleTickerProviderStateMixin {
  final SensorFusionTrackingEngine _fusionEngine = SensorFusionTrackingEngine();
  Timer? _driveTimer;
  StreamSubscription<Position>? _positionStreamSub;

  int _secondsElapsed = 0;
  double _distanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _isPaused = false;
  bool _isGpsLocked = false;
  String _gpsStatusMessage = 'CONNECTING TO SATELLITES...';

  Position? _lastPosition;
  Position? _startPosition;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initRealGpsTracking();
  }

  Future<void> _initRealGpsTracking() async {
    // 1. Check Location Service enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'LOCATION SERVICES DISABLED';
        });
      }
      return;
    }

    // 2. Check & Request Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _gpsStatusMessage = 'GPS PERMISSION DENIED';
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'LOCATION BLOCKED IN SETTINGS';
        });
      }
      return;
    }

    // 3. Obtain initial GPS lock
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (mounted) {
        setState(() {
          _startPosition = initialPos;
          _lastPosition = initialPos;
          _isGpsLocked = true;
          _gpsStatusMessage = 'GPS LOCKED • HARDWARE ACCURATE';
        });
      }
    } catch (_) {
      // Stream will attempt to pick up
    }

    // 4. Notify appState that live drive is underway
    widget.appState.startLiveDrive();

    // 5. Start drive timer
    _driveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    // 6. Hardware GPS Location Stream with Anti-Drift Filtering
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Only trigger update if moved at least 3 meters
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (!mounted || _isPaused) return;

        // Apply Tesla-grade Sensor Fusion & Dead Reckoning filter pipeline
        final update = _fusionEngine.processFix(position);

        setState(() {
          _isGpsLocked = true;
          _gpsStatusMessage = update.isAnomalousJumpDiscarded
              ? 'GPS DEAD RECKONING • FILTER ACTIVE'
              : 'GPS LOCKED • SENSOR FUSION';

          _currentSpeedKmh = update.instantaneousSpeedKmh;
          _distanceKm += update.distanceDeltaKm;
          _lastPosition = update.currentPosition;
        });

        // Sync with dashboard telemetry capsule
        widget.appState.updateLiveDriveDistance(_distanceKm);
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isGpsLocked = false;
            _gpsStatusMessage = 'GPS SIGNAL LOST';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    Future.microtask(() {
      widget.appState.endLiveDrive();
    });
    super.dispose();
  }

  Future<void> _finishDrive() async {
    HapticFeedback.heavyImpact();
    _driveTimer?.cancel();
    _positionStreamSub?.cancel();

    final finalDistance = double.parse(_distanceKm.toStringAsFixed(2));
    final lastOdo = widget.appState.currentOdometer;

    String startLoc = widget.originAddress;
    String endLoc = 'Destination Site';

    if (_startPosition != null) {
      startLoc = await GeocodingService.reverseGeocode(
        _startPosition!.latitude,
        _startPosition!.longitude,
      );
    }

    if (_lastPosition != null) {
      endLoc = await GeocodingService.reverseGeocode(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
      );
    }

    final detectedTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: widget.appState.primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: finalDistance,
      date: DateTime.now(),
      purpose: widget.initialPurpose,
      startOdometer: lastOdo,
      endOdometer: lastOdo + finalDistance,
      originAddress: startLoc,
      destinationAddress: endLoc,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TripDetectionScreen(
          appState: widget.appState,
          detectedTrip: detectedTrip,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final claimValue = _distanceKm * AppConstants.activeTaxRule.centsPerKmRate;

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () {
            _driveTimer?.cancel();
            _positionStreamSub?.cancel();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Live Hardware GPS Tracking',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Real GPS Satellite Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isGpsLocked
                        ? AppColors.emerald.withValues(alpha: 0.5)
                        : const Color(0xFFF97316).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isGpsLocked ? AppColors.emerald : const Color(0xFFF97316),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _gpsStatusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Real Distance Hero Display (0.00 when stationary!)
              Text(
                _distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'KILOMETRES (GPS ACTUAL)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Real Estimated Tax Claim Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.trendingUp, color: AppColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Claim Accumulating: ${Formatters.currency(claimValue)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Metrics Row (Duration & Real Hardware Speed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          _formatDuration(_secondsElapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Duration',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.white.withValues(alpha: 0.15)),
                    Column(
                      children: [
                        Text(
                          '${_currentSpeedKmh.toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hardware Speed',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons (Pause & Finish)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isPaused = !_isPaused);
                      },
                      icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white),
                      label: Text(
                        _isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _finishDrive,
                      icon: const Icon(LucideIcons.flag, size: 18),
                      label: const Text(
                        'Finish Drive',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
