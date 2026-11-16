import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/sensor_fusion_tracking_engine.dart';
import '../../../services/tracking/geocoding_service.dart';
import '../../../services/tracking/location_permission_service.dart';
import 'trip_detection_screen.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_typography.dart';

/// Screen: Genuine Hardware GPS Live Tracking HUD with Sensor Fusion & Dead Reckoning
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

class _TripLiveTrackingScreenState extends State<TripLiveTrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initRealGpsTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Emergency flush of in-flight trip state before iOS suspends or kills process
      widget.appState.updateLiveDriveDistance(
        _distanceKm,
        currentPosition: _lastPosition,
      );
    }
  }

  Future<void> _initRealGpsTracking() async {
    final permissionService = LocationPermissionService();
    final status = await permissionService.requestForegroundPermission();

    if (status == AppLocationPermissionStatus.serviceDisabled) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'LOCATION SERVICES DISABLED';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Location services are turned off. Please turn on GPS.'),
            action: SnackBarAction(
              label: 'Enable',
              onPressed: () => permissionService.openLocationSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    if (status == AppLocationPermissionStatus.denied) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'GPS PERMISSION DENIED';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Location permission is required for live trip tracking.'),
            action: SnackBarAction(
              label: 'Grant',
              onPressed: _initRealGpsTracking,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (status == AppLocationPermissionStatus.deniedForever) {
      if (mounted) {
        setState(() {
          _gpsStatusMessage = 'LOCATION BLOCKED (TAP SETTINGS)';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Location access is blocked. Please enable it in Settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => permissionService.openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

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
    } catch (e, stack) {
      debugPrint(
          '[TripLiveTracking] Warning acquiring initial GPS position: $e\n$stack');
      // Stream will attempt to pick up
    }

    if (!widget.appState.isDriving) {
      widget.appState.startLiveDrive(
        startPosition: _startPosition,
        originAddress: widget.originAddress,
        purpose: widget.initialPurpose,
      );
    } else {
      _distanceKm = widget.appState.activeDriveDistanceKm;
      if (widget.appState.activeDriveStartedAt != null) {
        _secondsElapsed = DateTime.now()
            .difference(widget.appState.activeDriveStartedAt!)
            .inSeconds;
      }
      _startPosition ??= widget.appState.activeDriveStartPosition;
      _lastPosition ??= widget.appState.activeDriveLastPosition;
    }

    _driveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // Only trigger update if moved at least 3 meters
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'KiloTax Live Tracking Active',
          notificationText:
              'Accurately recording your business trip for ATO tax compliance...',
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      );
    }

    _positionStreamSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (!mounted || _isPaused) return;

        // Apply Sensor Fusion & Dead Reckoning filter pipeline
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

        // Sync with dashboard telemetry capsule & persist snapshot
        widget.appState.updateLiveDriveDistance(
          _distanceKm,
          currentPosition: _lastPosition,
        );
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

  Future<void> _handleGpsDiagnosticTap() async {
    if (_isGpsLocked) return;
    HapticFeedback.lightImpact();

    final permissionService = LocationPermissionService();
    final status = await permissionService.checkStatus();

    switch (status) {
      case AppLocationPermissionStatus.serviceDisabled:
        await permissionService.openLocationSettings();
        break;
      case AppLocationPermissionStatus.deniedForever:
        await permissionService.openAppSettings();
        break;
      default:
        _initRealGpsTracking();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driveTimer?.cancel();
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    // P2 Lifecycle Decoupling: UI widget disposal must never end or discard an in-flight drive.
    // Drive termination is strictly an intentional user decision (_finishDrive / Discard)
    // or autonomous engine event, never an artifact of transient screen navigation.
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

    final vehicle = widget.appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;

    final detectedTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle?.id ?? 'default_vehicle',
      distanceKm: finalDistance,
      date: DateTime.now(),
      purpose: widget.initialPurpose,
      startOdometer: isLogbook ? lastOdo : 0.0,
      endOdometer: isLogbook ? (lastOdo + finalDistance) : 0.0,
      originAddress: startLoc,
      destinationAddress: endLoc,
      taxMethod: vehicle?.taxMethod ?? TaxMethod.centsPerKm,
    );

    // Explicitly transition live drive state to finished upon save
    widget.appState.endLiveDrive();

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

  void _disposeRecording() {
    _driveTimer?.cancel();
    _positionStreamSub?.cancel();
  }

  /// Leaving mid-recording: prompt the user whether to keep recording in background,
  /// discard, or end and save.
  Future<void> _handleExitRequest() async {
    final hasData = _secondsElapsed > 0 || _distanceKm > 0.05;
    if (!hasData) {
      _disposeRecording();
      widget.appState.endLiveDrive();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final choice = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Drive in progress'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '${_distanceKm.toStringAsFixed(1)} km recorded over ${_formatDuration(_secondsElapsed)}.\n\nYou can keep recording in the background, discard this drive, or end & save now.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Keep in background'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('End & save'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (choice == 'save') {
      await _finishDrive();
      return;
    }
    if (choice == 'discard') {
      _disposeRecording();
      widget.appState.endLiveDrive();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (choice == 'keep') {
      // Exit HUD while leaving drive running in AppState
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;
    final claimValue =
        _distanceKm * widget.appState.activeTaxRule.centsPerKmRate;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitRequest();
      },
      child: Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: _handleExitRequest,
        ),
        title: Text(
          'Live Hardware GPS Tracking',
          style: AppType.cardTitle.copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.xxl, vertical: S.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Real GPS Satellite Status Pill (Interactive on error)
              GestureDetector(
                onTap: _handleGpsDiagnosticTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: S.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isGpsLocked
                          ? AppColors.emerald.withValues(alpha: 0.5)
                          : AppColor.attentionStrong.withValues(alpha: 0.5),
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
                              color: _isGpsLocked
                                  ? AppColors.emerald
                                  : AppColor.attentionStrong,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: S.sm),
                      Text(
                        _gpsStatusMessage,
                        style: AppType.eyebrow.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Real Distance Hero Display (0.00 when stationary!)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _distanceKm.toStringAsFixed(2),
                  style: AppType.metricXL.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -2,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
              const SizedBox(height: S.labelGap),
              Text(
                'KILOMETRES (GPS ACTUAL)',
                style: AppType.secondary.copyWith(
                  color: AppColor.line,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: S.xxl),

              // Real Estimated Tax Claim Badge (CPK) or Logbook Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.sm),
                decoration: BoxDecoration(
                  color: isLogbook
                      ? AppColors.workBlue.withValues(alpha: 0.2)
                      : AppColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isLogbook
                          ? AppColors.workBlue.withValues(alpha: 0.5)
                          : AppColors.emerald.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLogbook ? LucideIcons.bookOpen : LucideIcons.trendingUp,
                      color: isLogbook ? AppColors.workBlueLight : AppColors.emerald,
                      size: 16,
                    ),
                    const SizedBox(width: S.sm),
                    Text(
                      isLogbook
                          ? 'Logbook Substantiation Drive'
                          : 'Claim Accumulating: ${Formatters.currency(claimValue)}',
                      style: AppType.bodyStrong.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Metrics Row (Duration & Real Hardware Speed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: S.xl, vertical: S.lg),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          _formatDuration(_secondsElapsed),
                          style: AppType.titleSmall.copyWith(
                            color: Colors.white,
                            fontFeatures: AppType.tabular,
                          ),
                        ),
                        const SizedBox(height: S.xxs),
                        Text(
                          'Duration',
                          style: AppType.secondary.copyWith(
                            color: AppColor.line,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                        height: 30,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.15)),
                    Column(
                      children: [
                        Text(
                          '${_currentSpeedKmh.toStringAsFixed(0)} km/h',
                          style: AppType.titleSmall.copyWith(
                            color: Colors.white,
                            fontFeatures: AppType.tabular,
                          ),
                        ),
                        const SizedBox(height: S.xxs),
                        Text(
                          'Hardware Speed',
                          style: AppType.secondary.copyWith(
                            color: AppColor.line,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: S.xxl),

              // Action Buttons (Pause & Finish)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: S.lg),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isPaused = !_isPaused);
                      },
                      icon: Icon(
                          _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: Colors.white),
                      label: Text(
                        _isPaused ? 'Resume' : 'Pause',
                        style: AppType.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
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
                        padding: const EdgeInsets.symmetric(vertical: S.lg),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _finishDrive,
                      icon: const Icon(LucideIcons.flag, size: 18),
                      label: Text(
                        'Finish Drive',
                        style: AppType.cardTitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: S.md),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
