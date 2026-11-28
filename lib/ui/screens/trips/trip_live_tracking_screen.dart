import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../services/tracking/location_permission_service.dart';
import '../../../services/tracking/live_drive_controller.dart';
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
  late AnimationController _pulseController;

  LiveDriveController get _controller => widget.appState.liveDriveController;
  int get _secondsElapsed => _controller.secondsElapsed;
  double get _distanceKm => _controller.distanceKm;
  double get _currentSpeedKmh => _controller.currentSpeedKmh;
  bool get _isPaused => _controller.isPaused;
  bool get _isGpsLocked => _controller.isGpsLocked;
  String get _gpsStatusMessage => _controller.gpsStatusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initRealGpsTracking();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Emergency flush of in-flight trip state before iOS suspends or kills process
      widget.appState.updateLiveDriveDistance(
        _distanceKm,
        currentPosition: _controller.lastPosition,
      );
    }
  }

  Future<void> _initRealGpsTracking() async {
    final permissionService = LocationPermissionService();
    final status = await permissionService.requestForegroundPermission();

    if (status == AppLocationPermissionStatus.serviceDisabled) {
      if (mounted) {
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

    Position? initialPos = _controller.startPosition;
    if (initialPos == null) {
      try {
        initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        );
      } catch (e, stack) {
        debugPrint(
            '[TripLiveTracking] Warning acquiring initial GPS position: $e\n$stack');
      }
    }

    if (!widget.appState.isDriving) {
      widget.appState.startLiveDrive(
        startPosition: initialPos,
        originAddress: widget.originAddress,
        purpose: widget.initialPurpose,
      );
    }

    await widget.appState.startOrResumeLiveTracking(initialPosition: initialPos);
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
    _controller.removeListener(_onControllerChanged);
    _pulseController.dispose();
    // P2 Lifecycle Decoupling: UI widget disposal must never end or discard an in-flight drive.
    // The GPS stream and fusion engine live in AppState.liveDriveController.
    super.dispose();
  }

  Future<void> _finishDrive() async {
    HapticFeedback.heavyImpact();
    final trip = await widget.appState
        .finishLiveDriveForReviewWithEnrichment(distanceKm: _distanceKm);
    if (!mounted) return;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No distance recorded yet. Continue recording or discard this drive.'),
      ));
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          TripDetectionScreen(appState: widget.appState, detectedTrip: trip),
    ));
  }

  void _disposeRecording() {
    // Recording stream is owned by AppState.liveDriveController and stopped via endLiveDrive().
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
            icon:
                const Icon(Icons.close_rounded, color: Colors.white, size: 24),
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
            padding:
                const EdgeInsets.symmetric(horizontal: S.xxl, vertical: S.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Real GPS Satellite Status Pill (Interactive on error)
                GestureDetector(
                  onTap: _handleGpsDiagnosticTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: S.md, vertical: 6),
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
                  'KILOMETRES · GPS ESTIMATE',
                  style: AppType.secondary.copyWith(
                    color: AppColor.line,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: S.xxl),

                // Real Estimated Tax Claim Badge (CPK) or Logbook Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.lg, vertical: S.sm),
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
                        isLogbook
                            ? LucideIcons.bookOpen
                            : LucideIcons.trendingUp,
                        color: isLogbook
                            ? AppColors.workBlueLight
                            : AppColors.emerald,
                        size: 16,
                      ),
                      const SizedBox(width: S.sm),
                      Text(
                        isLogbook
                            ? 'Logbook Substantiation Drive'
                            : 'Review work purpose after this drive',
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.xl, vertical: S.lg),
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
                          _controller.togglePause();
                        },
                        icon: Icon(
                            _isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: Colors.white),
                        label: Text(
                          _isPaused ? 'Resume' : 'Pause',
                          style: AppType.body.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600),
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
