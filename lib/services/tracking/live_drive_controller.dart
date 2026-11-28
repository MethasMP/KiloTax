import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'sensor_fusion_tracking_engine.dart';

/// Persistent controller for manual live GPS trip tracking.
/// Lives in [AppState] so navigating away from [TripLiveTrackingScreen]
/// ("Keep in background") does NOT cancel the GPS stream or reset sensor fusion.
class LiveDriveController extends ChangeNotifier {
  final SensorFusionTrackingEngine _fusionEngine = SensorFusionTrackingEngine();

  Timer? _driveTimer;
  StreamSubscription<Position>? _positionStreamSub;
  final List<Position> _breadcrumbs = [];

  int _secondsElapsed = 0;
  double _distanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _isPaused = false;
  bool _isGpsLocked = false;
  bool _disposed = false;
  String _gpsStatusMessage = 'CONNECTING TO SATELLITES...';

  Position? _startPosition;
  Position? _lastPosition;
  DateTime? _lastHeartbeatAt;

  int get secondsElapsed => _secondsElapsed;
  double get distanceKm => _distanceKm;
  double get currentSpeedKmh => _currentSpeedKmh;
  bool get isPaused => _isPaused;
  bool get isGpsLocked => _isGpsLocked;
  String get gpsStatusMessage => _gpsStatusMessage;
  Position? get startPosition => _startPosition;
  Position? get lastPosition => _lastPosition;
  DateTime? get lastHeartbeatAt => _lastHeartbeatAt ?? _lastPosition?.timestamp;
  bool get isStreamActive => _positionStreamSub != null;
  List<Position> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  void togglePause() {
    if (_disposed) return;
    _isPaused = !_isPaused;
    notifyListeners();
  }

  /// Starts or resumes the persistent GPS position stream and timer.
  /// Safe to call repeatedly when re-opening [TripLiveTrackingScreen]; existing
  /// stream, fusion state, and breadcrumbs are preserved.
  Future<void> startOrResume({
    Position? initialPosition,
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
    void Function(double distanceKm, Position? currentPosition)? onDistanceUpdate,
    void Function(Object error)? onStreamError,
  }) async {
    if (_disposed) return;

    if (initialPosition != null) {
      if (_startPosition == null) {
        _startPosition = initialPosition;
        _fusionEngine.processFix(initialPosition);
      }
      _lastPosition ??= initialPosition;
      _lastHeartbeatAt = initialPosition.timestamp;
      if (_breadcrumbs.isEmpty) {
        _breadcrumbs.add(initialPosition);
      }
      _isGpsLocked = true;
      _gpsStatusMessage = 'GPS SIGNAL AVAILABLE';
    }

    _driveTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        _secondsElapsed++;
        notifyListeners();
      }
    });

    if (_positionStreamSub == null) {
      final locationSettings = _buildLocationSettings();
      final stream = positionStreamFactory != null
          ? positionStreamFactory(locationSettings)
          : Geolocator.getPositionStream(locationSettings: locationSettings);

      _positionStreamSub = stream.listen(
        (Position position) {
          if (_disposed || _isPaused) return;

          final update = _fusionEngine.processFix(position);
          _isGpsLocked = true;
          _gpsStatusMessage = update.isAnomalousJumpDiscarded
              ? 'GPS DEAD RECKONING • FILTER ACTIVE'
              : 'GPS LOCKED • SENSOR FUSION';

          _currentSpeedKmh = update.instantaneousSpeedKmh;
          _distanceKm += update.distanceDeltaKm;
          _lastPosition = update.currentPosition;
          _lastHeartbeatAt = position.timestamp;
          _startPosition ??= update.currentPosition;

          if (!update.isAnomalousJumpDiscarded &&
              (!update.isStationary || _breadcrumbs.isEmpty)) {
            _breadcrumbs.add(update.currentPosition);
          }

          onDistanceUpdate?.call(_distanceKm, _lastPosition);
          notifyListeners();
        },
        onError: (Object err) {
          if (_disposed) return;
          _isGpsLocked = false;
          _gpsStatusMessage = 'GPS SIGNAL LOST';
          onStreamError?.call(err);
          notifyListeners();
        },
        onDone: () {
          _positionStreamSub = null;
          if (_disposed) return;
          _isGpsLocked = false;
          _gpsStatusMessage = 'GPS SIGNAL LOST';
          notifyListeners();
        },
      );
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'KiloClaim Live Tracking Active',
          notificationText:
              'Accurately recording your business trip for ATO tax compliance...',
          notificationIcon:
              AndroidResource(name: 'ic_stat_kiloclaim', defType: 'drawable'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  /// Stops the GPS stream and resets all live tracking state.
  Future<void> stopAndReset() async {
    _driveTimer?.cancel();
    _driveTimer = null;
    final sub = _positionStreamSub;
    _positionStreamSub = null;
    await sub?.cancel();
    if (_disposed) return;
    _fusionEngine.reset();
    _breadcrumbs.clear();
    _secondsElapsed = 0;
    _distanceKm = 0.0;
    _currentSpeedKmh = 0.0;
    _isPaused = false;
    _isGpsLocked = false;
    _gpsStatusMessage = 'CONNECTING TO SATELLITES...';
    _startPosition = null;
    _lastPosition = null;
    _lastHeartbeatAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _driveTimer?.cancel();
    _driveTimer = null;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    super.dispose();
  }
}
