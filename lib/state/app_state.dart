import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/vehicle.dart';
import '../data/models/trip.dart';
import '../data/models/vehicle_expense.dart';
import '../data/models/tax_summary.dart';
import '../data/models/audit_evidence.dart';
import '../data/models/annual_odometer.dart';
import '../data/models/in_flight_trip.dart';
import '../data/models/logbook_period.dart';
import '../data/models/user_profile.dart';
import '../data/models/job_site.dart';
import '../services/tracking/job_site_geofence_engine.dart';
import '../services/notifications/notification_service.dart';
import '../services/engine/evidence_engine.dart';
import '../services/engine/evidence_review_service.dart';
import '../services/engine/tax_calculator_service.dart';
import '../services/evidence/evidence_vault_service.dart';
import '../services/sync/sync_engine_service.dart';
import '../services/storage/local_storage_service.dart';
import '../services/receipts/receipt_inbox_service.dart';
import '../services/receipts/receipt_workflow_policy.dart';
import '../services/receipts/receipt_document_integrity.dart';
import '../services/ocr/receipt_intelligence_service.dart';
import '../services/storage/receipt_image_optimization_service.dart';
import '../services/auth/supabase_auth_service.dart';
import '../services/engine/tax_rule_service.dart';
import '../services/tracking/location_permission_service.dart';
import '../services/tracking/autonomous_trip_detector.dart';
import '../services/tracking/hardware_bluetooth_service.dart';
import '../services/tracking/native_hardware_telemetry_bridge.dart';
import '../services/tracking/odometer_gap_reconciler.dart';
import '../services/tracking/live_drive_controller.dart';
import '../services/tracking/road_snap_routing_service.dart';
import '../services/tracking/geocoding_service.dart';
import '../services/tracking/wgs84_geodesic_engine.dart';
import '../services/tracking/trip_route_razor.dart';
import '../services/tracking/trip_stop_classifier.dart';
import '../services/tracking/odometer_calibration_engine.dart';
import '../services/tracking/tracking_watchdog_service.dart';
import '../services/audit/contemporaneous_sla_service.dart';
import '../services/evidence/ghost_trip_detector.dart';
import '../services/engine/privacy_redactor.dart';
import '../services/tax/ato_tax_period_engine.dart';
import '../core/constants/app_constants.dart';

enum SyncStatus { idle, syncing, success, error }

/// Drive Telemetry & Vitality Status
enum DriveTelemetryStatus {
  armed, // Standby, background motion & Bluetooth link armed
  driving, // Live work drive actively recording
}

class AppState extends ChangeNotifier {
  Vehicle? _primaryVehicle;
  final List<Vehicle> _vehicles = [];
  final List<Trip> _trips = [];
  final List<VehicleExpense> _expenses = [];
  final List<AuditEvidence> _evidenceList = [];
  final List<AnnualVehicleOdometer> _annualOdometers = [];
  final List<LogbookPeriod> _logbookPeriods = [];
  final List<JobSite> _jobSites = [];
  LogbookPeriod? _activeLogbookPeriod;
  final EvidenceVaultService _evidenceVaultService;

  LocalStorageService? _storageService;
  bool _isInitialized = false;

  // TELEMETRY & LIVE DRIVE STATE
  DriveTelemetryStatus _telemetryStatus = DriveTelemetryStatus.armed;
  double _activeDriveDistanceKm = 0.0;
  DateTime? _activeDriveStartedAt;
  Position? _activeDriveStartPosition;
  Position? _activeDriveLastPosition;
  String? _activeDriveOriginAddress;
  String _activeDrivePurpose = 'Business';
  DateTime? _lastTrackingHeartbeatAt;
  bool _isBluetoothLinked = false;
  UserProfile _userProfile = const UserProfile();
  late final AutonomousTripDetector _autonomousTripDetector =
      AutonomousTripDetector(
    odometerProvider: () => currentOdometer,
    vehicleIdProvider: () => _primaryVehicle?.id ?? 'primary_vehicle',
    userProfileProvider: () => _userProfile,
    jobSitesProvider: () => _jobSites,
  );
  final LiveDriveController _liveDriveController = LiveDriveController();
  StreamSubscription<Position>? _autonomousPositionSub;
  final RoadSnapRoutingService _roadSnapService = RoadSnapRoutingService();
  AppLocationPermissionStatus _locationPermissionStatus =
      AppLocationPermissionStatus.denied;

  // In-Flight Crash/Kill Recovery State
  InFlightTrip? _orphanedInFlightTrip;
  InFlightTrip? get orphanedInFlightTrip => _orphanedInFlightTrip;

  AppLocationPermissionStatus get locationPermissionStatus =>
      _locationPermissionStatus;

  Future<void> refreshLocationPermission() async {
    _locationPermissionStatus = await LocationPermissionService().checkStatus();
    notifyListeners();
  }

  // SUPABASE AUTH STATE
  final SupabaseAuthService _authService;
  AuthUser? _currentUser;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGuestMode = false;

  // SYNC ENGINE STATE
  final SyncEngineService _syncEngine;
  SyncStatus _syncStatus = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  String? _syncErrorMessage;
  SyncResult? _lastSyncResult;

  // DYNAMIC ATO COMPLIANCE TAX RULE SERVICE
  final TaxRuleService _taxRuleService;

  AppState({
    LocalStorageService? storageService,
    SupabaseAuthService? authService,
    SyncEngineService? syncEngine,
    TaxRuleService? taxRuleService,
    EvidenceVaultService? evidenceVaultService,
  })  : _storageService = storageService,
        _authService = authService ?? SupabaseAuthService(),
        _syncEngine = syncEngine ??
            SyncEngineService(
              tokenProvider: () =>
                  (authService ?? SupabaseAuthService()).currentAccessToken,
            ),
        _taxRuleService =
            taxRuleService ?? TaxRuleService(storageService: storageService),
        _evidenceVaultService = evidenceVaultService ?? EvidenceVaultService();

  bool get isInitialized => _isInitialized;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get currentAccessToken =>
      _authService.currentAccessToken ?? _currentUser?.accessToken;
  bool get isGuestMode => _isGuestMode;

  bool isAccountantExportSessionCurrent(String? owner, String? token) =>
      !_disposed &&
      !_accountTransitionInProgress &&
      _currentUser?.id == owner &&
      (owner == null || currentAccessToken == token);

  Future<void> setGuestMode(bool isGuest) async {
    _isGuestMode = isGuest;
    await _storageService?.setGuestMode(isGuest);
    notifyListeners();
  }

  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get syncErrorMessage => _syncErrorMessage;
  SyncResult? get lastSyncResult => _lastSyncResult;
  AtoTaxRule get activeTaxRule => _taxRuleService.currentRule;
  TaxRuleService get taxRuleService => _taxRuleService;
  EvidenceVaultService get evidenceVaultService => _evidenceVaultService;

  Vehicle? get primaryVehicle => _primaryVehicle;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<Trip> get trips => List.unmodifiable(_trips);
  List<VehicleExpense> get expenses => List.unmodifiable(_expenses);
  String? get receiptStorageWarning => _storageService?.expenseRecoveryWarning;
  List<AuditEvidence> get evidenceList => List.unmodifiable(_evidenceList);
  List<AnnualVehicleOdometer> get annualOdometers =>
      List.unmodifiable(_annualOdometers);
  List<JobSite> get jobSites => List.unmodifiable(_jobSites);
  List<LogbookPeriod> get logbookPeriods => List.unmodifiable(_logbookPeriods);
  LogbookPeriod? get activeLogbookPeriod => _activeLogbookPeriod;

  /// Returns recent distinct custom purposes logged across trips (up to 4)
  List<String> get recentPurposes {
    final list = <String>[];
    for (final trip in _trips.reversed) {
      final p = trip.purpose
          .replaceAll(' (Bulky Tools Carried)', '')
          .replaceAll('Bulky Tools Carried', '')
          .trim();
      if (p.isNotEmpty &&
          p != '?' &&
          p != 'Personal Drive' &&
          p != 'Client / Job' &&
          p != 'Supplier / Materials' &&
          p != 'Work Site Inspection' &&
          !list.contains(p)) {
        list.add(p);
        if (list.length >= 4) break;
      }
    }
    return list;
  }

  void _upsertLogbookPeriod(LogbookPeriod period) {
    final idx = _logbookPeriods.indexWhere((p) => p.id == period.id);
    if (idx != -1) {
      _logbookPeriods[idx] = period;
    } else {
      _logbookPeriods.add(period);
    }
    _storageService?.saveLogbookPeriods(_logbookPeriods);
  }

  // TELEMETRY GETTERS & ACTIONS
  DriveTelemetryStatus get telemetryStatus => _telemetryStatus;
  bool get isDriving => _telemetryStatus == DriveTelemetryStatus.driving;
  double get activeDriveDistanceKm => _activeDriveDistanceKm;
  DateTime? get activeDriveStartedAt => _activeDriveStartedAt;
  Position? get activeDriveStartPosition => _activeDriveStartPosition;
  Position? get activeDriveLastPosition => _activeDriveLastPosition;
  String? get activeDriveOriginAddress => _activeDriveOriginAddress;
  bool get isBluetoothLinked => _isBluetoothLinked;
  AutonomousTripDetector get autonomousTripDetector => _autonomousTripDetector;
  LiveDriveController get liveDriveController => _liveDriveController;
  List<Position> get activeDriveBreadcrumbs => _liveDriveController.breadcrumbs;

  /// Latest telemetry heartbeat observed across live tracking, autonomous fixes,
  /// or persisted in-flight crash-recovery snapshots.
  DateTime? get lastTrackingHeartbeatAt {
    final candidates = <DateTime>[
      if (_lastTrackingHeartbeatAt != null) _lastTrackingHeartbeatAt!,
      if (_liveDriveController.lastHeartbeatAt != null)
        _liveDriveController.lastHeartbeatAt!,
      if (_orphanedInFlightTrip != null) _orphanedInFlightTrip!.lastUpdatedAt,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> startOrResumeLiveTracking({
    Position? initialPosition,
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
  }) {
    return _liveDriveController.startOrResume(
      initialPosition: initialPosition,
      positionStreamFactory: positionStreamFactory,
      onDistanceUpdate: (distanceKm, currentPos) {
        updateLiveDriveDistance(distanceKm, currentPosition: currentPos);
      },
    );
  }

  double get activeDriveTaxSavedAud {
    final rate = activeTaxRule.centsPerKmRate;
    return _activeDriveDistanceKm * rate;
  }

  void startLiveDrive({
    Position? startPosition,
    String? originAddress,
    String purpose = 'Business',
  }) {
    if (_telemetryStatus == DriveTelemetryStatus.driving) {
      debugPrint(
          '[AppState] startLiveDrive called while already driving; preserving active drive');
      return;
    }

    _telemetryStatus = DriveTelemetryStatus.driving;
    _activeDriveDistanceKm = 0.0;
    _activeDriveStartedAt = DateTime.now();
    _activeDriveStartPosition = startPosition;
    _activeDriveLastPosition = startPosition;
    _activeDriveOriginAddress = originAddress;
    _activeDrivePurpose = purpose;
    _lastTrackingHeartbeatAt = startPosition?.timestamp ?? _activeDriveStartedAt;

    // Immediately persist initial in-flight snapshot
    if (startPosition != null) {
      final tripId =
          'inflight_${_activeDriveStartedAt!.millisecondsSinceEpoch}';
      final inFlight = InFlightTrip(
        id: tripId,
        vehicleId: _primaryVehicle?.id ?? 'default_vehicle',
        purpose: purpose,
        startedAt: _activeDriveStartedAt!,
        lastUpdatedAt: DateTime.now(),
        distanceKm: 0.0,
        startLatitude: startPosition.latitude,
        startLongitude: startPosition.longitude,
        lastLatitude: startPosition.latitude,
        lastLongitude: startPosition.longitude,
        originAddress: originAddress,
        startOdometer: currentOdometer,
      );
      _storageService?.saveInFlightTrip(inFlight);
    }

    notifyListeners();
  }

  void updateLiveDriveDistance(double distanceKm, {Position? currentPosition}) {
    if (_telemetryStatus == DriveTelemetryStatus.driving) {
      if (currentPosition != null) {
        _activeDriveLastPosition = currentPosition;
      }
      _lastTrackingHeartbeatAt = currentPosition?.timestamp ?? DateTime.now();
      final bool distanceChanged =
          (distanceKm - _activeDriveDistanceKm).abs() >= 0.05 ||
              _activeDriveDistanceKm == 0.0;

      if (distanceChanged) {
        _activeDriveDistanceKm = distanceKm;
        notifyListeners();

        // Persist snapshot to disk (Survives sudden iOS force-kill/Jetsam)
        if (_activeDriveStartPosition != null) {
          final lat = currentPosition?.latitude ??
              _activeDriveLastPosition?.latitude ??
              _activeDriveStartPosition!.latitude;
          final lng = currentPosition?.longitude ??
              _activeDriveLastPosition?.longitude ??
              _activeDriveStartPosition!.longitude;

          final inFlight = InFlightTrip(
            id: 'inflight_${_activeDriveStartedAt?.millisecondsSinceEpoch ?? 0}',
            vehicleId: _primaryVehicle?.id ?? 'default_vehicle',
            purpose: _activeDrivePurpose,
            startedAt: _activeDriveStartedAt ?? DateTime.now(),
            lastUpdatedAt: DateTime.now(),
            distanceKm: distanceKm,
            startLatitude: _activeDriveStartPosition!.latitude,
            startLongitude: _activeDriveStartPosition!.longitude,
            lastLatitude: lat,
            lastLongitude: lng,
            originAddress: _activeDriveOriginAddress,
            startOdometer: currentOdometer,
          );
          _storageService?.saveInFlightTrip(inFlight);
        }
      }
    }
  }

  Trip? finishLiveDriveForReview(
      {double? distanceKm, String? destinationAddress}) {
    final result = _buildAndRecordLiveTrip(
      distanceKm: distanceKm,
      destinationAddress: destinationAddress,
    );
    if (result == null) return null;
    unawaited(_enrichFinishedTrip(
      result.trip,
      result.breadcrumbs,
      result.startPos,
      result.endPos,
      destinationAddressOverride: destinationAddress,
    ));
    return result.trip;
  }

  Future<Trip?> finishLiveDriveForReviewWithEnrichment(
      {double? distanceKm, String? destinationAddress}) async {
    final result = _buildAndRecordLiveTrip(
      distanceKm: distanceKm,
      destinationAddress: destinationAddress,
    );
    if (result == null) return null;
    return _enrichFinishedTrip(
      result.trip,
      result.breadcrumbs,
      result.startPos,
      result.endPos,
      destinationAddressOverride: destinationAddress,
    );
  }

  ({
    Trip trip,
    List<Position> breadcrumbs,
    Position? startPos,
    Position? endPos,
  })? _buildAndRecordLiveTrip({
    double? distanceKm,
    String? destinationAddress,
  }) {
    final vehicle = _primaryVehicle;
    final distance = distanceKm ?? _activeDriveDistanceKm;
    if (!isDriving || vehicle == null || !distance.isFinite || distance <= 0) {
      return null;
    }
    final started = _activeDriveStartedAt ?? DateTime.now();
    final stopped = DateTime.now();
    final tracksOdometer = vehicle.taxMethod == TaxMethod.logbook;
    final opening = tracksOdometer ? currentOdometer : 0.0;
    final startPos =
        _activeDriveStartPosition ?? _liveDriveController.startPosition;
    final endPos =
        _activeDriveLastPosition ?? _liveDriveController.lastPosition;
    final breadcrumbs = List<Position>.from(_liveDriveController.breadcrumbs);

    final trip = Trip(
      id: 'gps_${started.microsecondsSinceEpoch}',
      vehicleId: vehicle.id,
      date: started,
      stoppedAt: stopped,
      stoppedDuration: stopped.difference(started).inSeconds,
      distanceKm: distance,
      purpose: '',
      classification: TripClassification.unclassified,
      startOdometer: opening,
      endOdometer: tracksOdometer ? opening + distance : 0.0,
      originAddress: _activeDriveOriginAddress,
      destinationAddress: destinationAddress,
      startLat: startPos?.latitude,
      startLng: startPos?.longitude,
      endLat: endPos?.latitude,
      endLng: endPos?.longitude,
      taxMethod: vehicle.taxMethod,
      evidenceSource: 'gps_recorded',
    );
    recordTrip(trip);
    endLiveDrive();
    return (
      trip: trip,
      breadcrumbs: breadcrumbs,
      startPos: startPos,
      endPos: endPos,
    );
  }

  Future<Trip> _enrichFinishedTrip(
    Trip trip,
    List<Position> breadcrumbs,
    Position? startPos,
    Position? endPos, {
    String? destinationAddressOverride,
  }) async {
    String? polyline = trip.routePolyline;
    String? resolvedDest = destinationAddressOverride ?? trip.destinationAddress;

    try {
      if (breadcrumbs.length >= 2) {
        final route = await _roadSnapService.matchTrace(breadcrumbs);
        polyline = route.geometryPolyline ?? polyline;
      } else if (startPos != null && endPos != null) {
        final route = await _roadSnapService.calculateRoadDistanceKm(
          startLat: startPos.latitude,
          startLon: startPos.longitude,
          endLat: endPos.latitude,
          endLon: endPos.longitude,
        );
        polyline = route.geometryPolyline ?? polyline;
      }
    } catch (e) {
      debugPrint('[AppState] Route snap enrichment skipped: $e');
    }

    try {
      if ((resolvedDest == null || resolvedDest.isEmpty) && endPos != null) {
        resolvedDest = await GeocodingService.reverseGeocode(
          endPos.latitude,
          endPos.longitude,
        );
      }
    } catch (e) {
      debugPrint('[AppState] Reverse geocode enrichment skipped: $e');
    }

    if (_disposed) return trip;
    if (polyline != trip.routePolyline ||
        resolvedDest != trip.destinationAddress) {
      final enriched = trip.copyWith(
        routePolyline: polyline,
        destinationAddress: resolvedDest,
      );
      final idx = _trips.indexWhere((t) => t.id == trip.id);
      if (idx != -1) {
        _trips[idx] = enriched;
        _storageService?.saveTrips(_trips);
        if (!_disposed) notifyListeners();
      }
      return enriched;
    }
    return trip;
  }

  void endLiveDrive() {
    _telemetryStatus = DriveTelemetryStatus.armed;
    _activeDriveDistanceKm = 0.0;
    _activeDriveStartedAt = null;
    _activeDriveStartPosition = null;
    _activeDriveLastPosition = null;
    _activeDriveOriginAddress = null;
    _storageService?.clearInFlightTrip();
    unawaited(_liveDriveController.stopAndReset());
    notifyListeners();
  }

  /// Rescues an orphaned in-flight trip that was interrupted by an iOS process kill
  Future<void> rescueOrphanedTrip({
    required bool saveToLogbook,
    String? resolvedOrigin,
    String? resolvedDestination,
  }) async {
    final orphan = _orphanedInFlightTrip;
    if (orphan == null) return;

    if (saveToLogbook && orphan.distanceKm > 0.1) {
      final trip = Trip(
        id: 'rescued_${orphan.id}',
        vehicleId: orphan.vehicleId,
        distanceKm: double.parse(orphan.distanceKm.toStringAsFixed(2)),
        date: orphan.startedAt,
        purpose: orphan.purpose,
        startOdometer: orphan.startOdometer,
        endOdometer: orphan.startOdometer + orphan.distanceKm,
        originAddress: resolvedOrigin ?? orphan.originAddress ?? 'Start Site',
        destinationAddress:
            resolvedDestination ?? orphan.lastAddress ?? 'Interrupted Site',
        classification: TripClassification.unclassified,
        evidenceSource: 'rescued_crash_continuity',
      );
      recordTrip(trip);
    }

    _orphanedInFlightTrip = null;
    await _storageService?.clearInFlightTrip();
    notifyListeners();
  }

  /// Discards the orphaned trip snapshot
  Future<void> discardOrphanedTrip() async {
    _orphanedInFlightTrip = null;
    await _storageService?.clearInFlightTrip();
    notifyListeners();
  }

  void toggleBluetoothLink(bool linked) {
    _isBluetoothLinked = linked;
    notifyListeners();
  }

  /// Verifies real-time hardware Bluetooth connectivity against the primary vehicle's paired device
  Future<void> checkRealBluetoothConnection() async {
    final vehicle = _primaryVehicle;
    if (vehicle == null ||
        vehicle.bluetoothDeviceName == null ||
        vehicle.bluetoothDeviceName!.isEmpty) {
      if (_isBluetoothLinked) {
        _isBluetoothLinked = false;
        notifyListeners();
      }
      return;
    }

    try {
      final targetName = vehicle.bluetoothDeviceName!.toLowerCase().trim();

      final audioDevices =
          await HardwareBluetoothService().getActiveAudioBluetoothDevices();
      if (_primaryVehicle?.id != vehicle.id ||
          _primaryVehicle?.bluetoothDeviceName != vehicle.bluetoothDeviceName) {
        return;
      }
      final hasAudio = audioDevices.any(
          (d) => HardwareBluetoothService().isDeviceMatching(d, targetName));
      if (hasAudio) {
        if (!_isBluetoothLinked) {
          _isBluetoothLinked = true;
          notifyListeners();
        }
        return;
      }

      final isSupported = await FlutterBluePlus.isSupported;
      if (isSupported) {
        final sysDevices = await FlutterBluePlus.systemDevices([]);
        if (_primaryVehicle?.id != vehicle.id ||
            _primaryVehicle?.bluetoothDeviceName !=
                vehicle.bluetoothDeviceName) {
          return;
        }
        final hasBle = sysDevices.any((d) {
          final n = (d.platformName.isNotEmpty ? d.platformName : d.advName)
              .toLowerCase()
              .trim();
          return n == targetName;
        });
        if (hasBle) {
          if (!_isBluetoothLinked) {
            _isBluetoothLinked = true;
            notifyListeners();
          }
          return;
        }
      }

      // Neither is connected: reflect disconnected state
      if (_isBluetoothLinked) {
        _isBluetoothLinked = false;
        notifyListeners();
      }
    } catch (e) {
      if (_primaryVehicle?.id == vehicle.id &&
          _primaryVehicle?.bluetoothDeviceName == vehicle.bluetoothDeviceName &&
          _isBluetoothLinked) {
        _isBluetoothLinked = false;
        notifyListeners();
      }
      debugPrint('[AppState] Could not verify Bluetooth connection: $e');
    }
  }

  /// Starts low-power standby autonomous monitoring when background permission
  /// is granted and a primary vehicle is configured. High-accuracy GPS is only
  /// engaged after departure is confirmed (via LiveDriveController / native engine),
  /// keeping idle standby battery impact under 2% per day.
  Future<void> startAutonomousMonitoring({
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
  }) async {
    if (_autonomousPositionSub != null) return;
    if (_primaryVehicle == null) return;
    if (positionStreamFactory == null &&
        _locationPermissionStatus !=
            AppLocationPermissionStatus.grantedBackground) {
      return;
    }

    try {
      final settings = defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? AppleSettings(
              accuracy: LocationAccuracy.low,
              distanceFilter: 150,
              activityType: ActivityType.other,
              pauseLocationUpdatesAutomatically: true,
              allowBackgroundLocationUpdates: true,
              showBackgroundLocationIndicator: false,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.low,
              distanceFilter: 150,
            );

      final stream = positionStreamFactory != null
          ? positionStreamFactory(settings)
          : Geolocator.getPositionStream(locationSettings: settings);

      _autonomousPositionSub = stream.listen(
        (pos) => ingestAutonomousFix(pos),
        onError: (Object e) {
          debugPrint('[AppState] Autonomous monitoring stream warning: $e');
        },
      );
    } catch (e) {
      debugPrint('[AppState] Autonomous monitoring unavailable: $e');
    }
  }

  /// Stops the autonomous background GPS monitoring stream.
  Future<void> stopAutonomousMonitoring() async {
    await _autonomousPositionSub?.cancel();
    _autonomousPositionSub = null;
  }

  /// Ingests a new continuous GPS fix into the AutonomousTripDetector
  void ingestAutonomousFix(Position fix) async {
    if (!fix.isMocked) {
      _lastTrackingHeartbeatAt = fix.timestamp;
    }
    final newState = await _autonomousTripDetector.processFix(
      fix,
      isBluetoothCarConnected: _isBluetoothLinked,
    );
    if (newState == AutonomousDetectorState.activeDriving && !isDriving) {
      startLiveDrive(startPosition: fix);
    } else if (newState == AutonomousDetectorState.finalized) {
      final trip = _autonomousTripDetector.finalizedTrip;
      if (trip != null) {
        handleFinalizedAutonomousTrip(trip);
      }
      endLiveDrive();
    }
  }

  /// Handles finalized autonomous trip with 5-minute Trip Stitching & Passenger Verification
  void handleFinalizedAutonomousTrip(Trip trip) {
    // Task 2: Trip Stitching Buffer (Anti-Fragmentation for 2-Minute Quick Stops)
    // If the previous trip finalized within the last 5 minutes (300s) and is geographically adjacent (<= 500m),
    // stitch them together instead of producing fragmented records.
    Trip? stitchedTrip;
    if (_trips.isNotEmpty) {
      final previousTrip = _trips.first;
      final previousEndTime = previousTrip.stoppedAt ?? previousTrip.date;
      final timeSinceLastTrip = trip.date.difference(previousEndTime);
      bool isSpatiallyClose = true;
      if (previousTrip.endLat != null &&
          previousTrip.endLng != null &&
          trip.startLat != null &&
          trip.startLng != null) {
        final gapMeters = Wgs84GeodesicEngine.calculateDistanceMeters(
          lat1: previousTrip.endLat!,
          lon1: previousTrip.endLng!,
          lat2: trip.startLat!,
          lon2: trip.startLng!,
        );
        isSpatiallyClose = gapMeters <= 500.0;
      }

      if (!timeSinceLastTrip.isNegative &&
          timeSinceLastTrip.inMinutes <= 5 &&
          isSpatiallyClose &&
          previousTrip.vehicleId == (_primaryVehicle?.id ?? trip.vehicleId)) {
        final combinedDistance = previousTrip.distanceKm + trip.distanceKm;
        stitchedTrip = previousTrip.copyWith(
          distanceKm: combinedDistance,
          endOdometer: previousTrip.startOdometer + combinedDistance,
          destinationAddress:
              trip.destinationAddress ?? previousTrip.destinationAddress,
          endLat: trip.endLat ?? previousTrip.endLat,
          endLng: trip.endLng ?? previousTrip.endLng,
          stoppedAt: trip.stoppedAt ?? previousTrip.stoppedAt,
          routePolyline: trip.routePolyline ?? previousTrip.routePolyline,
          detectedPoi: trip.detectedPoi ?? previousTrip.detectedPoi,
          isPassengerUnverified: !_isBluetoothLinked,
        );
        // Replace previous fragmented trip with the stitched continuous trip
        _trips.removeAt(0);
        _trips.insert(0, stitchedTrip);
        _storageService?.saveTrips(_trips);
        notifyListeners();
      }
    }

    if (stitchedTrip == null) {
      final effectiveTrip = (trip.startOdometer == 0.0 && currentOdometer > 0.0
          ? trip.copyWith(
              startOdometer: currentOdometer,
              endOdometer: currentOdometer + trip.distanceKm,
              vehicleId: _primaryVehicle?.id ?? trip.vehicleId,
              isPassengerUnverified: !_isBluetoothLinked,
            )
          : trip.copyWith(
              isPassengerUnverified: !_isBluetoothLinked,
            ));
      recordTrip(effectiveTrip);
    }
  }

  void updatePrimaryVehicleBluetoothDevice(
    String? deviceName, {
    String? bluetoothUuid,
  }) {
    if (_primaryVehicle == null) return;
    _primaryVehicle = _primaryVehicle!.copyWith(
      bluetoothDeviceName: deviceName,
      clearBluetoothDevice: deviceName == null || deviceName.isEmpty,
    );
    final idx = _vehicles.indexWhere((v) => v.id == _primaryVehicle!.id);
    if (idx != -1) {
      _vehicles[idx] = _primaryVehicle!;
    }
    _storageService?.saveVehicles(_vehicles);
    _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);
    _isBluetoothLinked = false;
    checkRealBluetoothConnection();

    // Push down to iOS/Android Native Bluetooth State Restoration
    unawaited(NativeHardwareTelemetryBridge().syncTargetBluetoothName(
      deviceName,
      bluetoothUuid: bluetoothUuid,
    ));

    notifyListeners();
  }

  bool get hasVehicle => _primaryVehicle != null;
  bool get hasSeenOnboarding => _storageService?.hasSeenOnboarding() ?? false;

  Future<void> completeOnboarding() async {
    await _storageService?.setHasSeenOnboarding(true);
    notifyListeners();
  }

  /// Initialize local persistence and restore saved state from disk
  Future<void> init({LocalStorageService? storageService}) async {
    if (storageService != null) {
      _storageService = storageService;
    }
    _storageService ??= await LocalStorageService.init();
    await _storageService!.recoverRestoreIntent();

    if (_storageService != null) {
      _isGuestMode = _storageService!.isGuestMode();
      _vehicles.clear();
      _vehicles.addAll(_storageService!.loadVehicles());

      final savedPrimaryId = _storageService!.loadPrimaryVehicleId();
      if (savedPrimaryId != null && _vehicles.isNotEmpty) {
        _primaryVehicle = _vehicles.firstWhere(
          (v) => v.id == savedPrimaryId,
          orElse: () => _vehicles.first,
        );
      } else if (_vehicles.isNotEmpty) {
        _primaryVehicle = _vehicles.firstWhere((v) => v.isPrimary,
            orElse: () => _vehicles.first);
      }

      _trips.clear();
      _trips.addAll(_storageService!.loadTrips());

      _expenses.clear();
      _expenses.addAll(_storageService!.loadExpenses());
      _rebuildExpenseLinks();

      _evidenceList.clear();
      _evidenceList.addAll(_storageService!.loadEvidence());

      _annualOdometers.clear();
      _annualOdometers.addAll(_storageService!.loadAnnualOdometers());

      _jobSites.clear();
      _jobSites.addAll(_storageService!.loadJobSites());

      _logbookPeriods.clear();
      _logbookPeriods.addAll(_storageService!.loadLogbookPeriods());
      _activeLogbookPeriod = _logbookPeriods
          .where((p) =>
              p.status == LogbookStatus.inProgress ||
              p.status == LogbookStatus.completedPendingReview)
          .firstOrNull;

      _userProfile = _storageService!.loadUserProfile();
    }

    // Restore or listen to Supabase Auth state
    _currentUser = _authService.getCurrentUser();
    await _authSubscription?.cancel();
    _authSubscription = _authService.onAuthStateChange?.listen((data) async {
      while (_backupRestoreGate != null || _workflowSaveGate != null) {
        final backupGate = _backupRestoreGate;
        final workflowGate = _workflowSaveGate;
        if (backupGate != null) await backupGate.future;
        if (workflowGate != null) await workflowGate.future;
      }
      final session = data.session;
      if (session != null) {
        final metadata = session.user.userMetadata ?? {};
        final displayName =
            (metadata['full_name'] ?? metadata['name']) as String?;
        final avatarUrl =
            (metadata['avatar_url'] ?? metadata['picture']) as String?;

        _currentUser = AuthUser(
          id: session.user.id,
          email: session.user.email ?? '',
          provider: session.user.appMetadata['provider'] ?? 'oauth',
          displayName: displayName,
          avatarUrl: avatarUrl,
          accessToken: session.accessToken,
        );
        _isGuestMode = false;
        unawaited(_storageService?.setGuestMode(false));
        unawaited(restoreFromCloud());
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });

    await _taxRuleService.init();

    _taxRuleService.syncLatestOfficialRates().then((updated) {
      if (updated) {
        notifyListeners();
      }
    });

    LocationPermissionService().checkStatus().then((status) {
      _locationPermissionStatus = status;
      if (status == AppLocationPermissionStatus.grantedBackground &&
          _primaryVehicle != null) {
        unawaited(startAutonomousMonitoring());
      }
      notifyListeners();
    }).catchError((e, stack) {
      debugPrint(
          '[AppState] Warning checking location permission status: $e\n$stack');
    });

    if (_primaryVehicle != null) {
      _isBluetoothLinked = false;
      checkRealBluetoothConnection();
    } else {
      _isBluetoothLinked = false;
    }

    if (_storageService != null) {
      final savedInFlight = _storageService!.loadInFlightTrip();
      if (savedInFlight != null && savedInFlight.distanceKm > 0.05) {
        _orphanedInFlightTrip = savedInFlight;
        debugPrint(
            '[AppState] Resurrected orphaned in-flight trip: ${savedInFlight.distanceKm} km, started at ${savedInFlight.startedAt}');
      }
    }

    if (_primaryVehicle != null) {
      unawaited(NativeHardwareTelemetryBridge()
          .syncTargetBluetoothName(_primaryVehicle!.bluetoothDeviceName));
      unawaited(ingestCompletedNativeTrips());
    }

    _isInitialized = true;
    if (_currentUser != null) {
      unawaited(restoreFromCloud());
    }
    notifyListeners();
  }

  /// Fetches and ingests any trips recorded by the native iOS/Android background daemon
  /// while Flutter was suspended or terminated. Safe to call on init and app resume.
  Future<void> ingestCompletedNativeTrips() async {
    final vehicle = _primaryVehicle;
    if (vehicle == null) return;

    try {
      final nativeTrips =
          await NativeHardwareTelemetryBridge().fetchCompletedNativeTrips();
      final ingestedIds = <String>[];
      for (final item in nativeTrips) {
        final dist = (item['distanceKm'] as num?)?.toDouble() ?? 0.0;
        if (dist > 0.1) {
          final startMs =
              item['startedAt'] as num? ?? DateTime.now().millisecondsSinceEpoch;
          final completedMs = item['completedAt'] as num?;
          final startLatRaw = (item['startLatitude'] as num?)?.toDouble();
          final startLngRaw = (item['startLongitude'] as num?)?.toDouble();
          final endLatRaw = (item['endLatitude'] as num?)?.toDouble();
          final endLngRaw = (item['endLongitude'] as num?)?.toDouble();

          final startLat =
              (startLatRaw != null && startLatRaw != 0.0) ? startLatRaw : null;
          final startLng =
              (startLngRaw != null && startLngRaw != 0.0) ? startLngRaw : null;
          final endLat =
              (endLatRaw != null && endLatRaw != 0.0) ? endLatRaw : null;
          final endLng =
              (endLngRaw != null && endLngRaw != 0.0) ? endLngRaw : null;

          final tripId = item['id'] as String? ??
              'native_${DateTime.now().millisecondsSinceEpoch}';
          if (_trips.any((t) => t.id == tripId)) {
            ingestedIds.add(tripId);
            continue;
          }

          final startedAt = DateTime.fromMillisecondsSinceEpoch(startMs.toInt());
          final stoppedAt = completedMs != null
              ? DateTime.fromMillisecondsSinceEpoch(completedMs.toInt())
              : null;

          final source =
              item['source'] as String? ?? 'native_bluetooth_auto';
          final btMatched = item['vehicleBluetoothMatched'] as bool? ??
              (source == 'native_bluetooth_auto');

          final trip = Trip(
            id: tripId,
            vehicleId: vehicle.id,
            distanceKm: dist,
            date: startedAt,
            stoppedAt: stoppedAt,
            stoppedDuration: stoppedAt
                ?.difference(startedAt)
                .inSeconds
                .clamp(0, 86400),
            startLat: startLat,
            startLng: startLng,
            endLat: endLat,
            endLng: endLng,
            purpose: '',
            classification: TripClassification.unclassified,
            taxMethod: vehicle.taxMethod,
            startOdometer: currentOdometer,
            endOdometer: currentOdometer + dist,
            evidenceSource: source,
            review: {
              'vehicleBluetoothMatched': btMatched,
            },
          );
          recordTrip(trip);
          ingestedIds.add(tripId);
          debugPrint(
              '[AppState] Auto-ingested native trip: $dist km from native background daemon.');
        }
      }
      if (ingestedIds.isNotEmpty) {
        await NativeHardwareTelemetryBridge()
            .acknowledgeNativeTripsIngested(ingestedIds);
      }
    } catch (e) {
      debugPrint('[AppState] Note querying completed native trips: $e');
    }
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);
    if (vehicle.isPrimary || _primaryVehicle == null) {
      _primaryVehicle = vehicle;
      _storageService?.savePrimaryVehicleId(vehicle.id);
      _isBluetoothLinked = false;
      checkRealBluetoothConnection();
    }
    _storageService?.saveVehicles(_vehicles);
    notifyListeners();
  }

  void selectVehicle(String vehicleId) {
    final found = _vehicles.firstWhere((v) => v.id == vehicleId,
        orElse: () => _primaryVehicle!);
    _primaryVehicle = found;
    _storageService?.savePrimaryVehicleId(found.id);
    _isBluetoothLinked = false;
    checkRealBluetoothConnection();
    notifyListeners();
  }

  /// Starting Baseline Odometer of Primary Vehicle
  double get startingOdometer => _primaryVehicle?.initialOdometer ?? 0.0;

  /// Current Live Odometer of Primary Vehicle (Starting Odo + Total Distance Driven)
  double get currentOdometer =>
      getVehicleCurrentOdometer(_primaryVehicle?.id ?? '');

  /// Get Current Odometer for a specific vehicle by ID
  double getVehicleCurrentOdometer(String vehicleId) {
    final odo = getLastKnownOdometer(vehicleId);
    if (odo > 0.0) return odo;

    final vehicle = _vehicles.firstWhere(
      (v) => v.id == vehicleId,
      orElse: () =>
          _primaryVehicle ??
          Vehicle(
            id: vehicleId,
            make: '',
            model: '',
            regoPlate: '',
            initialOdometer: 0.0,
          ),
    );
    return vehicle.initialOdometer;
  }

  /// Get the last recorded odometer reading from trips for a vehicle (0.0 if no trips exist)
  double getLastKnownOdometer(String vehicleId, {String? excludeTripId}) {
    final vehicleTrips = _trips
        .where((t) =>
            t.vehicleId == vehicleId &&
            !t.isDeleted &&
            (excludeTripId == null || t.id != excludeTripId))
        .toList();

    if (vehicleTrips.isNotEmpty) {
      final tripsWithOdo =
          vehicleTrips.where((t) => t.endOdometer > 0.0).toList();
      if (tripsWithOdo.isNotEmpty) {
        return tripsWithOdo
            .map((t) => t.endOdometer)
            .reduce((a, b) => a > b ? a : b);
      }
    }

    return 0.0;
  }

  /// Odometer Integrity: Maximum allowed Starting Odometer
  /// If trips already exist for this vehicle, starting odometer CANNOT exceed the first trip's startOdometer
  double? get maxAllowedStartingOdometer =>
      _primaryVehicle == null
          ? null
          : maxAllowedStartingOdometerForVehicle(_primaryVehicle!.id);

  double? maxAllowedStartingOdometerForVehicle(String vehicleId) {
    final readings = _trips.where((trip) =>
        trip.vehicleId == vehicleId &&
        !trip.isDeleted &&
        trip.startOdometer.isFinite &&
        trip.startOdometer > 0);
    if (readings.isEmpty) return null;
    return readings.map((trip) => trip.startOdometer).reduce(
        (first, second) => first < second ? first : second);
  }

  (bool isValid, String? errorMessage) validateStartingOdometer(double newOdo,
      {String? vehicleId}) {
    if (!newOdo.isFinite || newOdo < 0) {
      return (false, 'Enter a finite, non-negative starting odometer.');
    }
    final targetId = vehicleId ?? _primaryVehicle?.id;
    if (targetId == null || !_vehicles.any((v) => v.id == targetId)) {
      return (false, 'Choose a vehicle before changing its odometer.');
    }
    final maxAllowed = maxAllowedStartingOdometerForVehicle(targetId);
    if (maxAllowed != null && newOdo > maxAllowed) {
      return (
        false,
        'Cannot exceed first trip start odometer (${maxAllowed.toStringAsFixed(0)} km). Otherwise previous trips become invalid under ATO rules.'
      );
    }
    return (true, null);
  }

  bool updateStartingOdometer(double newOdo, {String? vehicleId}) {
    final (isValid, _) =
        validateStartingOdometer(newOdo, vehicleId: vehicleId);
    if (!isValid) return false;
    final targetId = vehicleId ?? _primaryVehicle?.id;
    final idx = _vehicles.indexWhere((v) => v.id == targetId);
    if (idx == -1) return false;
    final updated = _vehicles[idx].copyWith(initialOdometer: newOdo);
    _vehicles[idx] = updated;
    if (_primaryVehicle?.id == targetId) _primaryVehicle = updated;
    _storageService?.saveVehicles(_vehicles);
    notifyListeners();
    _autoSyncInBackground();
    return true;
  }

  /// Validate new current odometer reading (must be >= current odometer)
  (bool isValid, String? errorMessage) validateNewCurrentOdometer(
      double newOdo) {
    if (newOdo < currentOdometer) {
      return (
        false,
        'Dashboard reading (${newOdo.toStringAsFixed(0)} km) cannot be less than current recorded odometer (${currentOdometer.toStringAsFixed(0)} km).'
      );
    }
    return (true, null);
  }

  List<OdometerGap> odometerGapsForVehicle(String vehicleId) {
    final vehicles = _vehicles.where((v) => v.id == vehicleId);
    if (vehicles.isEmpty) return const [];
    return OdometerGapReconciler.findGaps(
        vehicleId: vehicleId,
        baseline: vehicles.first.initialOdometer,
        trips: _trips);
  }

  List<OdometerGap> get pendingOdometerGaps => _primaryVehicle == null
      ? const []
      : odometerGapsForVehicle(_primaryVehicle!.id);

  bool get isOdometerChainGapless => pendingOdometerGaps.isEmpty;

  double detectOdometerGap(double nextStartOdometer) {
    final diff = nextStartOdometer - currentOdometer;
    return diff > 0.1 ? diff : 0.0;
  }

  OdometerGap? findFirstOdometerGap() =>
      pendingOdometerGaps.isEmpty ? null : pendingOdometerGaps.first;

  /// Used immediately before saving a missing trip to reject stale/overlapping input.
  bool isUnrecordedOdometerSpan(
          {required String vehicleId,
          required double startOdo,
          required double endOdo,
          String? legacyTripId}) =>
      odometerGapsForVehicle(vehicleId).any((gap) =>
          gap.legacyTripId == legacyTripId && gap.contains(startOdo, endOdo));

  /// Bridges an unrecorded odometer gap as either Personal or Work travel to maintain gapless compliance
  void fillOdometerGap({
    required double gapEndOdometer,
    required bool isBusiness,
    double? gapStartOdometer,
    String? purpose,
    String? origin,
    String? destination,
  }) {
    final startOdo = gapStartOdometer ?? currentOdometer;
    if (gapEndOdometer <= startOdo) return;
    final distance = gapEndOdometer - startOdo;
    final trip = Trip(
      id: 'gap_bridge_${DateTime.now().microsecondsSinceEpoch}',
      vehicleId: _primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: distance,
      date: DateTime.now(),
      purpose:
          purpose ?? (isBusiness ? 'Work drive (Bridging)' : 'Personal travel'),
      startOdometer: startOdo,
      endOdometer: gapEndOdometer,
      taxMethod: _primaryVehicle?.taxMethod ?? TaxMethod.logbook,
      evidenceSource: 'manual_gap_resolution',
      classification: isBusiness
          ? TripClassification.business
          : TripClassification.personal,
      originAddress: origin ?? (isBusiness ? 'Work Site' : '[Private Journey]'),
      destinationAddress:
          destination ?? (isBusiness ? 'Client Site' : '[Private Journey]'),
    );
    recordTrip(trip);
  }

  UserProfile get userProfile => _userProfile;

  /// Updates user profile (including home base geofence coordinates) and persists to local storage.
  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await _storageService?.saveUserProfile(_userProfile);
    notifyListeners();
  }

  bool _disposed = false;
  int _cloudRestoreEpoch = 0;
  bool _savingWorkflow = false;
  Completer<void>? _workflowSaveGate;
  Completer<void>? _backupRestoreGate;
  bool _accountTransitionInProgress = false;

  /// Save the reviewed evidence before notifying UI or scheduling cloud sync.
  Future<void> reviewWorkflowTrip({
    required String tripId,
    required TripClassification classification,
    required String purpose,
    required double businessKm,
    String? jobId,
    String allocationReason = '',
  }) async {
    if (_backupRestoreGate != null || _accountTransitionInProgress) {
      throw StateError('Account or backup is changing. Try again shortly.');
    }
    if (_savingWorkflow) {
      throw StateError('Another record is being saved. Try again.');
    }
    final index = _trips.indexWhere((t) => t.id == tripId && !t.isDeleted);
    if (index < 0) throw StateError('This trip is no longer available.');
    final trip = _trips[index];
    if (!businessKm.isFinite ||
        businessKm < 0 ||
        businessKm > trip.distanceKm) {
      throw ArgumentError(
          'Business distance must be within the recorded trip distance.');
    }
    if (classification == TripClassification.business &&
        (!EvidenceReviewService.hasMeaningfulBusinessPurpose(purpose) ||
            businessKm <= 0)) {
      throw ArgumentError('Add the actual business reason and distance.');
    }
    if (classification == TripClassification.business &&
        businessKm < trip.distanceKm &&
        allocationReason.trim().isEmpty) {
      throw ArgumentError('Explain how you separated the private distance.');
    }
    final jobs = _jobSites.where((j) => j.id == jobId);
    if (jobId != null && jobs.isEmpty) {
      throw ArgumentError('Choose an available job.');
    }
    final job = jobs.isEmpty ? null : jobs.first;
    final decision = <String, dynamic>{
      'classification': classification.name,
      'purpose': classification == TripClassification.personal
          ? 'Personal journey'
          : purpose.trim(),
      'businessKm':
          classification == TripClassification.business ? businessKm : 0.0,
      'jobId': classification == TripClassification.personal ? null : jobId,
      'allocationReason': allocationReason.trim(),
      'confirmedAt': DateTime.now().toUtc().toIso8601String(),
      'actor': 'user',
      'version': 1,
    };
    final updated = trip.copyWith(
      classification: classification,
      purpose: decision['purpose'] as String,
      jobId: job?.id,
      jobReference: job == null ? null : '${job.name} — ${job.clientName}',
      clearJob: job == null || classification == TripClassification.personal,
      review: {
        ...decision,
        'history': [...(trip.review['history'] as List? ?? []), decision],
      },
    );
    final next = [..._trips]..[index] = updated;
    _savingWorkflow = true;
    final workflowGate = Completer<void>();
    _workflowSaveGate = workflowGate;
    try {
      if (_storageService != null && !await _storageService!.saveTrips(next)) {
        throw StateError('Could not save this trip. Please try again.');
      }
      _trips[index] = updated;
      notifyListeners();
      _autoSyncInBackground();
    } finally {
      _savingWorkflow = false;
      _workflowSaveGate = null;
      workflowGate.complete();
    }
  }

  Future<void> assignWorkflowExpense(
      {required String expenseId, String? tripId, String? jobId}) async {
    if (_backupRestoreGate != null || _accountTransitionInProgress) {
      throw StateError('Account or backup is changing. Try again shortly.');
    }
    if (_savingWorkflow) {
      throw StateError('Another record is being saved. Try again.');
    }
    final index =
        _expenses.indexWhere((e) => e.id == expenseId && !e.isDeleted);
    if (index < 0) throw StateError('This receipt is no longer available.');
    final expense = _expenses[index];
    final matching = _trips.where((t) => t.id == tripId && !t.isDeleted);
    final trip = matching.isEmpty ? null : matching.first;
    if (tripId != null &&
        (trip == null || trip.vehicleId != expense.vehicleId)) {
      throw ArgumentError('Choose a trip for the same vehicle.');
    }
    if (jobId != null && !_jobSites.any((j) => j.id == jobId)) {
      throw ArgumentError('Choose an available job.');
    }
    final resolvedJob = jobId ?? trip?.jobId;
    final next = [..._expenses]..[index] = expense.copyWith(
        linkedTripId: tripId,
        clearLinkedTripId: tripId == null,
        jobId: resolvedJob,
        clearJob: resolvedJob == null,
      );
    _savingWorkflow = true;
    final workflowGate = Completer<void>();
    _workflowSaveGate = workflowGate;
    try {
      if (_storageService != null &&
          !await _storageService!.saveExpenses(next)) {
        throw StateError('Could not save this receipt link. Please try again.');
      }
      _expenses[index] = next[index];
      _rebuildExpenseLinks();
      await _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    } finally {
      _savingWorkflow = false;
      _workflowSaveGate = null;
      workflowGate.complete();
    }
  }

  // Expenses own the link, so interrupted saves can safely reconstruct the trip index.
  void _rebuildExpenseLinks() {
    for (var i = 0; i < _trips.length; i++) {
      final trip = _trips[i];
      _trips[i] = trip.copyWith(
          linkedExpenseIds: _expenses
              .where((e) =>
                  !e.isDeleted &&
                  e.vehicleId == trip.vehicleId &&
                  e.linkedTripId == trip.id)
              .map((e) => e.id)
              .toList());
    }
  }

  // --- JOB SITES / POI ENGINE ---
  Future<void> addJobSite(JobSite site) async {
    final next = [..._jobSites];
    final idx = next.indexWhere((s) => s.id == site.id);
    if (idx != -1) {
      next[idx] = site;
    } else {
      next.add(site);
    }
    if (_storageService != null && !await _storageService!.saveJobSites(next)) {
      throw StateError('Could not save this job.');
    }
    _jobSites
      ..clear()
      ..addAll(next);
    notifyListeners();
    _autoSyncInBackground();
  }

  Future<void> removeJobSite(String siteId) async {
    final index = _jobSites.indexWhere((s) => s.id == siteId);
    if (index < 0) return;
    await addJobSite(
        _jobSites[index].copyWith(isActive: false, updatedAt: DateTime.now()));
  }

  /// Evaluates whether coordinates fall within a known JobSite geofence (150m default).
  JobSiteMatchResult? matchJobSiteEndpoints({
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
  }) {
    return JobSiteGeofenceEngine.matchTripEndpoints(
      jobSites: _jobSites,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
  }

  /// Sets home base coordinates and optional address for geofenced commute detection.
  Future<void> setHomeBase({
    required double latitude,
    required double longitude,
    String? address,
    double radiusMeters = 200.0,
  }) async {
    final updated = _userProfile.copyWith(
      homeLatitude: latitude,
      homeLongitude: longitude,
      homeAddress: address ?? _userProfile.homeAddress,
      homeRadiusMeters: radiusMeters,
    );
    await updateUserProfile(updated);
  }

  /// Checks if given coordinates fall within user's home base geofence (200m default).
  bool isPositionHome(double latitude, double longitude) {
    if (!_userProfile.hasHomeCoordinates) return false;
    final dist = Geolocator.distanceBetween(
      latitude,
      longitude,
      _userProfile.homeLatitude!,
      _userProfile.homeLongitude!,
    );
    return dist <= _userProfile.homeRadiusMeters;
  }

  /// ATO Home-to-Work Compliance Validator (TR 2021/1):
  /// ATO Home-to-Work Compliance Validator (TR 2021/1 & TR 95/34):
  /// Checks whether travel starting at home and ending at a work site qualifies
  /// as a deductible business trip. Under ATO rules, commuting from home is deductible
  /// only when transporting heavy trade tools and the site has no secure lock-up.
  (bool isCompliant, String? warning) validateHomeToWorkCompliance({
    required String origin,
    required String destination,
    required String purpose,
    required bool isBulkyToolsCarried,
    bool hasNoSecureStorage = true,
    double? originLat,
    double? originLon,
    double? destinationLat,
    double? destinationLon,
  }) {
    final bool isHomeOrigin;
    if (originLat != null &&
        originLon != null &&
        _userProfile.hasHomeCoordinates) {
      final distance = Geolocator.distanceBetween(
        originLat,
        originLon,
        _userProfile.homeLatitude!,
        _userProfile.homeLongitude!,
      );
      isHomeOrigin = distance <= _userProfile.homeRadiusMeters;
    } else {
      final origLower = origin.trim().toLowerCase();
      isHomeOrigin =
          origLower.contains('home') || origLower.contains('residence');
    }

    final destLower = destination.trim().toLowerCase();
    final isWorkDest = destLower.contains('work') ||
        destLower.contains('job') ||
        destLower.contains('site') ||
        destLower.contains('client') ||
        destLower.contains('depot');

    if (isHomeOrigin && isWorkDest) {
      if (!isBulkyToolsCarried) {
        return (
          false,
          'Home trips count as private travel unless carrying heavy trade tools (>20kg).'
        );
      }
      if (!hasNoSecureStorage) {
        return (
          false,
          'Home trips cannot be claimed if the job site has secure tool lock-up.'
        );
      }
    }
    return (true, null);
  }

  /// Saves Day 1 or Day 84 odometer photo with anti-fraud cryptographic hash integrity
  /// and automatically archives an immutable record into the Unified Evidence Vault.
  Future<(bool success, String? error)> saveOdometerPhotoWithIntegrity({
    required bool isStart,
    required String photoPath,
    required String imageHash,
    required DateTime captureDate,
    Map<String, dynamic>? watermarkMetadata,
  }) async {
    if (_primaryVehicle == null) {
      return (false, 'No active vehicle selected.');
    }

    // Anti-fraud guard: Ensure the user cannot reuse the exact same photo for start and end
    if (isStart) {
      if (_primaryVehicle!.endOdometerImageHash != null &&
          _primaryVehicle!.endOdometerImageHash == imageHash) {
        return (
          false,
          'Image already used. Start and finish odometer photos must be taken separately.'
        );
      }
    } else {
      if (_primaryVehicle!.startOdometerImageHash != null &&
          _primaryVehicle!.startOdometerImageHash == imageHash) {
        return (
          false,
          'Image already used. Finish odometer photo cannot be identical to starting photo.'
        );
      }
    }

    // Vault-level cross-entity anti-fraud check
    final isDuplicateInVault =
        _evidenceList.any((e) => e.imageSha256 == imageHash);
    if (isDuplicateInVault) {
      return (
        false,
        'Duplicate photo rejected. This image has already been registered in your evidence vault.'
      );
    }

    final updated = isStart
        ? _primaryVehicle!.copyWith(
            startOdometerPhotoPath: photoPath,
            startOdometerVerifiedAt: captureDate,
            startOdometerImageHash: imageHash,
          )
        : _primaryVehicle!.copyWith(
            endOdometerPhotoPath: photoPath,
            endOdometerVerifiedAt: captureDate,
            endOdometerImageHash: imageHash,
          );

    _primaryVehicle = updated;
    final idx = _vehicles.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      _vehicles[idx] = updated;
    }
    _storageService?.saveVehicles(_vehicles);

    // Record into Unified Evidence Vault
    final evidence = AuditEvidence(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}_${isStart ? "start" : "end"}',
      vehicleId: _primaryVehicle!.id,
      evidenceType:
          isStart ? EvidenceType.odometerStart : EvidenceType.odometerEnd,
      storagePath: photoPath,
      imageSha256: imageHash,
      capturedAt: captureDate,
      captureSource: 'camera_live',
      watermarkMetadata: watermarkMetadata ??
          {
            'regoPlate': _primaryVehicle!.regoPlate,
            'timestamp': captureDate.toIso8601String(),
          },
    );
    _evidenceList.add(evidence);
    _storageService?.saveEvidence(_evidenceList);

    notifyListeners();
    _autoSyncInBackground();
    return (true, null);
  }

  /// Records verified evidence (receipts, tools setup, etc.) directly into the vault
  void recordAuditEvidence(AuditEvidence evidence) {
    _evidenceList.add(evidence);
    _storageService?.saveEvidence(_evidenceList);
    notifyListeners();
    _autoSyncInBackground();
  }

  /// Records or updates the statutory annual odometer reading (ITAA 1997 s 28-125)
  void recordAnnualOdometer(AnnualVehicleOdometer record) {
    final idx = _annualOdometers.indexWhere(
      (a) =>
          a.vehicleId == record.vehicleId &&
          a.financialYear == record.financialYear,
    );
    if (idx != -1) {
      _annualOdometers[idx] = record;
    } else {
      _annualOdometers.add(record);
    }
    _storageService?.saveAnnualOdometers(_annualOdometers);
    notifyListeners();
    _autoSyncInBackground();
  }

  /// Finds the annual odometer record for a given vehicle and financial year.
  AnnualVehicleOdometer? getAnnualOdometer(
      String vehicleId, String financialYear) {
    return _annualOdometers.cast<AnnualVehicleOdometer?>().firstWhere(
          (a) => a?.vehicleId == vehicleId && a?.financialYear == financialYear,
          orElse: () => null,
        );
  }

  /// ATO 5-Year Logbook Exemption Guard (ITAA 1997 s 28-125):
  /// Checks if the vehicle requires a June 30 closing odometer reading for the current FY.
  /// Applicable when:
  /// 1. Vehicle tax method is logbook and vehicle has established logbook.
  /// 2. Vehicle is within Years 1-5 of the logbook window.
  /// 3. Current date is near EOFY (June or July) or closing odometer has not yet been recorded.
  bool isAnnualOdometerRequired({DateTime? date}) {
    final vehicle = _primaryVehicle;
    if (vehicle == null || vehicle.taxMethod != TaxMethod.logbook) {
      return false;
    }
    final now = date ?? DateTime.now();
    // Near EOFY check: month is June (6) or July (7)
    final isNearEofy = now.month == 6 || now.month == 7;

    final periodEngine = const AtoTaxPeriodEngine();
    // In June, closing is for current FY ending June 30
    // In July, closing is for the FY that just closed June 30
    final targetFy = now.month == 7
        ? AtoFinancialYear(now.year - 1)
        : periodEngine.forDate(now);
    final fyLabel = targetFy.shortLabel;

    final record = getAnnualOdometer(vehicle.id, fyLabel);
    final isMissingClosing = record == null || record.closingOdometer == null;

    // Check if vehicle has an active logbook started
    if (vehicle.logbookStartDate == null) {
      return false;
    }

    // Vehicle in years 1-5 of logbook
    final yearsSinceStart =
        now.difference(vehicle.logbookStartDate!).inDays / 365.25;
    if (yearsSinceStart > 5.0) {
      return false; // Logbook expired, needs new 12-week logbook
    }

    return isNearEofy && isMissingClosing;
  }

  /// Saves trade gear / bulky tools profile to the primary vehicle and persists to evidence vault & local storage
  Future<void> saveTradeGearProfile({
    required String description,
    required String photoPath,
    required String imageHash,
  }) async {
    if (_primaryVehicle == null) return;
    final now = DateTime.now();
    final updated = _primaryVehicle!.copyWith(
      tradeToolsDescription: description,
      tradeToolsPhotoPath: photoPath,
      tradeToolsImageHash: imageHash,
      tradeToolsRegisteredAt: now,
    );
    _primaryVehicle = updated;
    final idx = _vehicles.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      _vehicles[idx] = updated;
    }
    _storageService?.saveVehicles(_vehicles);

    // Record into Unified Evidence Vault
    final evidence = AuditEvidence(
      id: 'ev_${now.millisecondsSinceEpoch}_trade_gear',
      vehicleId: updated.id,
      evidenceType: EvidenceType.heavyToolsSetup,
      storagePath: photoPath,
      imageSha256: imageHash,
      capturedAt: now,
      captureSource: 'camera_live',
      watermarkMetadata: {
        'regoPlate': updated.regoPlate,
        'description': description,
        'timestamp': now.toIso8601String(),
      },
    );
    _evidenceList.add(evidence);
    _storageService?.saveEvidence(_evidenceList);

    notifyListeners();
    _autoSyncInBackground();
  }

  /// Set Day 1 or Day 84 Odometer Cluster Photo evidence for 12-week statutory logbook
  void setLogbookOdometerPhotos({
    String? startPhotoPath,
    String? endPhotoPath,
    DateTime? startVerifiedAt,
    DateTime? endVerifiedAt,
  }) {
    if (_primaryVehicle == null) return;
    final updated = _primaryVehicle!.copyWith(
      startOdometerPhotoPath:
          startPhotoPath ?? _primaryVehicle!.startOdometerPhotoPath,
      startOdometerVerifiedAt:
          startVerifiedAt ?? _primaryVehicle!.startOdometerVerifiedAt,
      endOdometerPhotoPath:
          endPhotoPath ?? _primaryVehicle!.endOdometerPhotoPath,
      endOdometerVerifiedAt:
          endVerifiedAt ?? _primaryVehicle!.endOdometerVerifiedAt,
    );
    _primaryVehicle = updated;
    final idx = _vehicles.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      _vehicles[idx] = updated;
    }
    _storageService?.saveVehicles(_vehicles);
    notifyListeners();
    _autoSyncInBackground();
  }

  /// Check if there are local un-synced trips or expenses
  bool get hasUnsyncedChanges {
    if (_lastSyncedAt == null) {
      return _trips.isNotEmpty || _expenses.isNotEmpty;
    }
    final hasNewTrips = _trips.any((t) => t.date.isAfter(_lastSyncedAt!));
    final hasNewExpenses = _expenses.any((e) => e.date.isAfter(_lastSyncedAt!));
    return hasNewTrips || hasNewExpenses;
  }

  // ODOMETER MONOTONICITY INTEGRITY (ATO Subdivision 28-F)
  bool _hasOdometerMonotonicityViolation = false;
  String? _lastOdometerAnomalyWarning;

  bool get hasOdometerMonotonicityViolation =>
      _hasOdometerMonotonicityViolation;
  String? get lastOdometerAnomalyWarning => _lastOdometerAnomalyWarning;

  /// Record a new trip with offline-first persistence & invariant guards
  void recordTrip(Trip trip) {
    // Guard against corrupted 0-distance or inverted odometer writes
    if (trip.distanceKm <= 0.0 || trip.endOdometer < trip.startOdometer) {
      debugPrint(
          '[KiloClaim Integrity Guard] Ignored invalid zero/negative drive record.');
      return;
    }

    // Auto-enrich trip with known JobSite POI geofence if available
    final effectiveTrip = _jobSites.isNotEmpty
        ? JobSiteGeofenceEngine.enrichTripWithJobSite(
            trip: trip,
            jobSites: _jobSites,
            startLatitude: _activeDriveStartPosition?.latitude,
            endLatitude: _activeDriveLastPosition?.latitude,
            startLongitude: _activeDriveStartPosition?.longitude,
            endLongitude: _activeDriveLastPosition?.longitude,
          )
        : trip;

    // Check if trip already exists by ID (Idempotent write)
    final existingIdx = _trips.indexWhere((t) => t.id == effectiveTrip.id);
    final isNewTrip = existingIdx == -1;

    // Missing spans are derived from observed readings. Never manufacture a trip
    // or classify unobserved travel while ingesting another record.

    // Inter-Trip Odometer Monotonicity Invariant (ATO Subdivision 28-F):
    // For Logbook method vehicles, trips must advance monotonically (trip.startOdometer >= previousTrip.endOdometer)
    final vehicle = _vehicles.firstWhere(
      (v) => v.id == trip.vehicleId,
      orElse: () =>
          _primaryVehicle ??
          Vehicle(
            id: trip.vehicleId,
            make: '',
            model: '',
            regoPlate: '',
            initialOdometer: 0.0,
          ),
    );

    if (vehicle.taxMethod == TaxMethod.logbook) {
      final existingVehicleTrips = _trips
          .where((t) =>
              t.vehicleId == trip.vehicleId &&
              t.id != trip.id &&
              !t.isDeleted &&
              t.endOdometer > 0)
          .toList();
      if (existingVehicleTrips.isNotEmpty) {
        final overlaps = existingVehicleTrips.where((previous) =>
            trip.startOdometer < previous.endOdometer - 0.1 &&
            trip.endOdometer > previous.startOdometer + 0.1);
        if (overlaps.isNotEmpty) {
          final previousTrip = overlaps.first;
          _hasOdometerMonotonicityViolation = true;
          final warningMsg =
              '[ATO Subdivision 28-F Monotonicity Warning] Odometer non-monotonicity detected for vehicle ${vehicle.regoPlate} (${vehicle.id}): '
              'trip.startOdometer (${trip.startOdometer.toStringAsFixed(1)}) < '
              'previousTrip.endOdometer (${previousTrip.endOdometer.toStringAsFixed(1)}). '
              'Preserving drive record to prevent offline data loss.';
          _lastOdometerAnomalyWarning = warningMsg;
          debugPrint(warningMsg);
        }
      }
    }

    if (existingIdx != -1) {
      _trips[existingIdx] = effectiveTrip;
    } else {
      _trips.add(effectiveTrip);
    }

    // Automated First Odometer Snapshot Latch:
    // When a vehicle is in active logbook mode and this is its first trip in the period,
    // automatically latch starting odometer to trip.startOdometer without manual guesswork.
    if (isNewTrip &&
        vehicle.taxMethod == TaxMethod.logbook &&
        vehicle.logbookStartDate != null) {
      final periodStart = DateTime(
        vehicle.logbookStartDate!.year,
        vehicle.logbookStartDate!.month,
        vehicle.logbookStartDate!.day,
      );
      final logbookTripsPrior = _trips
          .where((t) =>
              t.vehicleId == vehicle.id &&
              !t.date.isBefore(periodStart) &&
              t.id != trip.id)
          .toList();

      if (logbookTripsPrior.isEmpty &&
          vehicle.initialOdometer <= 0 &&
          trip.startOdometer > 0) {
        final updatedVehicle =
            vehicle.copyWith(initialOdometer: trip.startOdometer);
        if (_primaryVehicle?.id == vehicle.id) {
          _primaryVehicle = updatedVehicle;
        }
        final vIdx = _vehicles.indexWhere((v) => v.id == vehicle.id);
        if (vIdx != -1) {
          _vehicles[vIdx] = updatedVehicle;
        }
        _storageService?.saveVehicles(_vehicles);

        if (_activeLogbookPeriod != null &&
            _activeLogbookPeriod!.vehicleId == vehicle.id) {
          _activeLogbookPeriod =
              _activeLogbookPeriod!.copyWith(startOdometer: trip.startOdometer);
          _upsertLogbookPeriod(_activeLogbookPeriod!);
        }
      }
    }

    _storageService?.saveTrips(_trips);
    notifyListeners();
    // Silent Background Sync
    _autoSyncInBackground();
  }

  /// Update an existing trip preserving continuous chain integrity
  void updateTrip(Trip trip) {
    final idx = _trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      _trips[idx] = trip;
      _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  /// EVIDENCE GRAPH CASCADE: Delete a trip and unlink all associated expenses.
  /// Sets `clearLinkedTripId: true` on any expense pointing to this trip.
  void deleteTrip(String tripId) {
    // 1. Unlink all expenses linked to this trip
    bool expensesChanged = false;
    for (int i = 0; i < _expenses.length; i++) {
      if (_expenses[i].linkedTripId == tripId) {
        _expenses[i] = _expenses[i].copyWith(clearLinkedTripId: true);
        expensesChanged = true;
      }
    }
    if (expensesChanged) {
      _storageService?.saveExpenses(_expenses);
    }

    // 2. Remove or mark trip as deleted
    final tripIdx = _trips.indexWhere((t) => t.id == tripId);
    if (tripIdx != -1) {
      _trips.removeAt(tripIdx);
      _storageService?.saveTrips(_trips);
    }

    notifyListeners();
    _autoSyncInBackground();
  }

  /// Spec #4 & #5: Activate 12-Week Logbook Period for Primary Vehicle
  /// Automatically latches starting odometer to first trip's startOdometer if trips exist.
  void startLogbookPeriod(
      {required DateTime startDate, double? startingOdometer}) {
    if (_primaryVehicle == null) return;
    final old = _primaryVehicle!;

    // Find any existing trips for this vehicle on or after the startDate to auto-latch start odometer
    final relevantTrips = _trips
        .where((t) =>
            t.vehicleId == old.id &&
            !t.date.isBefore(
                DateTime(startDate.year, startDate.month, startDate.day)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Automated First Odometer Snapshot Latch
    final latchedStartOdo =
        (relevantTrips.isNotEmpty && relevantTrips.first.startOdometer > 0)
            ? relevantTrips.first.startOdometer
            : (startingOdometer ?? old.initialOdometer);

    _primaryVehicle = old.copyWith(
      initialOdometer: latchedStartOdo,
      taxMethod: TaxMethod.logbook,
      logbookStartDate: startDate,
    );
    final idx = _vehicles.indexWhere((v) => v.id == old.id);
    if (idx != -1) {
      _vehicles[idx] = _primaryVehicle!;
    }
    _storageService?.saveVehicles(_vehicles);
    _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);

    final periodEngine = const AtoTaxPeriodEngine();
    final establishedFy = periodEngine.forDate(startDate).shortLabel;
    final validUntilFy = periodEngine
        .forDate(startDate.add(const Duration(days: 365 * 5)))
        .shortLabel;

    _activeLogbookPeriod = LogbookPeriod(
      id: 'logbook_${old.id}_${startDate.millisecondsSinceEpoch}',
      vehicleId: old.id,
      startDate: startDate,
      endDate: startDate.add(const Duration(days: 84)),
      startOdometer: latchedStartOdo,
      status: LogbookStatus.inProgress,
      establishedFinancialYear: establishedFy,
      validUntilFinancialYear: validUntilFy,
    );
    _upsertLogbookPeriod(_activeLogbookPeriod!);

    // Unvault fuel/running expenses that were safely held during CPK mode
    unvaultCpkFuelExpenses();

    notifyListeners();
    _autoSyncInBackground();
  }

  /// Completes the 12-week logbook period under ITAA 1997 s 28-G:
  /// - Automatically latches start odometer to first trip's startOdometer
  /// - Automatically latches closing odometer to final trip's endOdometer
  /// - Calculates certified business percentage and locks in LogbookStatus.completedPendingReview
  /// - Latches closing odometer into AnnualVehicleOdometer for the financial year
  LogbookPeriod? completeLogbookPeriod({
    String? vehicleId,
    DateTime? completionDate,
  }) {
    final vId = vehicleId ?? _primaryVehicle?.id;
    if (vId == null) return null;
    final vehicle = _vehicles.firstWhere(
      (v) => v.id == vId,
      orElse: () => _primaryVehicle!,
    );

    final start = vehicle.logbookStartDate ??
        DateTime.now().subtract(const Duration(days: 84));
    final periodStart = DateTime(start.year, start.month, start.day);
    final end = completionDate ?? start.add(const Duration(days: 84));
    final periodEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final periodTrips = _trips
        .where((t) =>
            t.vehicleId == vId &&
            !t.date.isBefore(periodStart) &&
            !t.date.isAfter(periodEnd))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Automated First/Last Odometer Snapshot Latch
    final latchedStartOdo =
        (periodTrips.isNotEmpty && periodTrips.first.startOdometer > 0)
            ? periodTrips.first.startOdometer
            : vehicle.initialOdometer;
    final latchedEndOdo = periodTrips.isNotEmpty
        ? periodTrips.last.endOdometer
        : getVehicleCurrentOdometer(vId);

    // Calculate certified statutory business percentage
    final totalKm = periodTrips.fold(0.0, (sum, t) => sum + t.distanceKm);
    final businessKm = periodTrips
        .where((t) => t.isBusiness)
        .fold(0.0, (sum, t) => sum + t.businessDistanceKm);
    final businessPct = totalKm > 0 ? (businessKm / totalKm) * 100.0 : 0.0;

    final periodEngine = const AtoTaxPeriodEngine();
    final establishedFy = periodEngine.forDate(start).shortLabel;
    final validUntilFy = periodEngine
        .forDate(start.add(const Duration(days: 365 * 5)))
        .shortLabel;

    final completedPeriod = LogbookPeriod(
      id: 'logbook_${vId}_${start.millisecondsSinceEpoch}',
      vehicleId: vId,
      startDate: start,
      endDate: end,
      startOdometer: latchedStartOdo,
      endOdometer: latchedEndOdo,
      status: LogbookStatus.completedPendingReview,
      certifiedBusinessPercentage: businessPct,
      establishedFinancialYear: establishedFy,
      validUntilFinancialYear: validUntilFy,
      certifiedAt: completionDate ?? DateTime.now(),
    );

    _activeLogbookPeriod = completedPeriod;
    _upsertLogbookPeriod(completedPeriod);

    // Latch closing odometer into AnnualVehicleOdometer for this financial year
    final targetFy = periodEngine.forDate(end).shortLabel;
    final existingAnnual = getAnnualOdometer(vId, targetFy);
    final updatedAnnual = (existingAnnual != null)
        ? existingAnnual.copyWith(
            closingOdometer: latchedEndOdo,
            closingDate: periodTrips.isNotEmpty ? periodTrips.last.date : end,
          )
        : AnnualVehicleOdometer(
            id: 'annual_${vId}_$targetFy',
            vehicleId: vId,
            financialYear: targetFy,
            openingDate: start,
            openingOdometer: latchedStartOdo,
            closingDate: periodTrips.isNotEmpty ? periodTrips.last.date : end,
            closingOdometer: latchedEndOdo,
          );
    recordAnnualOdometer(updatedAnnual);

    notifyListeners();
    _autoSyncInBackground();
    return completedPeriod;
  }

  /// Unvaults vehicle expenses that were previously held in vault solely because
  /// of Cents-per-km double-dipping rules. Once switched to Logbook, they are 100% claimable.
  void unvaultCpkFuelExpenses() {
    bool changed = false;
    for (int i = 0; i < _expenses.length; i++) {
      final exp = _expenses[i];
      if (exp.isVaultOnly && exp.vaultReason == 'cents_per_km_running_cost') {
        _expenses[i] = exp.copyWith(
          isVaultOnly: false,
          clearVaultReason: true,
        );
        changed = true;
      }
    }
    if (changed) {
      _storageService?.saveExpenses(_expenses);
    }
  }

  /// EVIDENCE GRAPH: Connect an expense (e.g. Bunnings/Fuel receipt) to a specific Trip
  void linkExpenseToTrip({required String expenseId, required String tripId}) {
    final target = _trips.where((t) => t.id == tripId && !t.isDeleted);
    final source = _expenses.where((e) => e.id == expenseId && !e.isDeleted);
    if (target.isEmpty ||
        source.isEmpty ||
        target.first.vehicleId != source.first.vehicleId) {
      return;
    }
    final expIndex = _expenses.indexWhere((e) => e.id == expenseId);
    if (expIndex != -1) {
      final oldExp = _expenses[expIndex];
      // If previously linked to another trip, unlink from it first
      if (oldExp.linkedTripId != null && oldExp.linkedTripId != tripId) {
        final prevTripIndex =
            _trips.indexWhere((t) => t.id == oldExp.linkedTripId);
        if (prevTripIndex != -1) {
          final prevTrip = _trips[prevTripIndex];
          _trips[prevTripIndex] = prevTrip.copyWith(
            linkedExpenseIds: prevTrip.linkedExpenseIds
                .where((id) => id != expenseId)
                .toList(),
          );
        }
      }

      _expenses[expIndex] = oldExp.copyWith(linkedTripId: tripId);
      _storageService?.saveExpenses(_expenses);
    }

    final tripIndex = _trips.indexWhere((t) => t.id == tripId);
    if (tripIndex != -1) {
      final oldTrip = _trips[tripIndex];
      if (!oldTrip.linkedExpenseIds.contains(expenseId)) {
        _trips[tripIndex] = oldTrip.copyWith(
          linkedExpenseIds: [...oldTrip.linkedExpenseIds, expenseId],
        );
        _storageService?.saveTrips(_trips);
      }
    }
    notifyListeners();
    _autoSyncInBackground();
  }

  /// EVIDENCE GRAPH: Disconnect an expense from a trip
  void unlinkExpenseFromTrip({required String expenseId}) {
    final expIndex = _expenses.indexWhere((e) => e.id == expenseId);
    if (expIndex != -1) {
      final oldExp = _expenses[expIndex];
      final currentTripId = oldExp.linkedTripId;
      _expenses[expIndex] = oldExp.copyWith(clearLinkedTripId: true);
      _storageService?.saveExpenses(_expenses);

      if (currentTripId != null) {
        final tripIndex = _trips.indexWhere((t) => t.id == currentTripId);
        if (tripIndex != -1) {
          final oldTrip = _trips[tripIndex];
          _trips[tripIndex] = oldTrip.copyWith(
            linkedExpenseIds: oldTrip.linkedExpenseIds
                .where((id) => id != expenseId)
                .toList(),
          );
          _storageService?.saveTrips(_trips);
        }
      }
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  Future<void> _adoptGuestReceipts(String account) async {
    try {
      for (final vehicle in _vehicles) {
        final guest = await ReceiptInboxService.open('guest', vehicle.id);
        await guest.migrateGuestTo(account);
      }
    } catch (e) {
      debugPrint(
          '[Receipt inbox] Guest receipts retained for migration retry: $e');
    }
  }

  /// Merges a validated backup without silently overwriting an existing record.
  Future<void> restoreLocalBackup(Map<String, dynamic> payload,
      {String? expectedAccount}) async {
    if (_accountTransitionInProgress) {
      throw StateError(
          'Account is changing. Restore the backup after signing in.');
    }
    final owner = expectedAccount ?? (_currentUser?.id ?? 'guest');
    if ((_currentUser?.id ?? 'guest') != owner) {
      throw StateError('Account changed. Choose the backup again.');
    }
    if (_savingWorkflow) {
      throw StateError('A record is being saved. Try restoring again shortly.');
    }
    if (_backupRestoreGate != null) {
      throw StateError('Another backup is being restored.');
    }
    final gate = Completer<void>();
    _backupRestoreGate = gate;
    try {
      List<Map<String, dynamic>> rows(String key) =>
          (payload[key] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      List<Map<String, dynamic>> merge(
          List<Map<String, dynamic>> old, List<Map<String, dynamic>> incoming) {
        final byId = {for (final item in incoming) item['id'] as String: item};
        // Existing records take precedence. Restoring the same archive is idempotent.
        for (final item in old) {
          byId[item['id'] as String] = item;
        }
        return byId.values.toList();
      }

      final vehicles =
          merge(_vehicles.map((e) => e.toJson()).toList(), rows('vehicles'))
              .map(Vehicle.fromJson)
              .toList();
      final trips = merge(_trips.map((e) => e.toJson()).toList(), rows('trips'))
          .map(Trip.fromJson)
          .toList();
      final expenses =
          merge(_expenses.map((e) => e.toJson()).toList(), rows('expenses'))
              .map(VehicleExpense.fromJson)
              .toList();
      final evidence =
          merge(_evidenceList.map((e) => e.toJson()).toList(), rows('evidence'))
              .map(AuditEvidence.fromJson)
              .toList();
      final annual = merge(_annualOdometers.map((e) => e.toJson()).toList(),
              rows('annualOdometers'))
          .map(AnnualVehicleOdometer.fromJson)
          .toList();
      final jobs =
          merge(_jobSites.map((e) => e.toJson()).toList(), rows('jobSites'))
              .map(JobSite.fromJson)
              .toList();
      for (final expense in expenses) {
        if (!vehicles.any((v) => v.id == expense.vehicleId)) {
          throw const FormatException(
              'Backup receipt has no matching vehicle.');
        }
        if (expense.allocationError != null) {
          throw FormatException(expense.allocationError!);
        }
      }
      final snapshot = <String, dynamic>{
        'vehicles': vehicles.map((e) => e.toJson()).toList(),
        'trips': trips.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'annualOdometers': annual.map((e) => e.toJson()).toList(),
        'jobSites': jobs.map((e) => e.toJson()).toList(),
        'primaryVehicleId': _primaryVehicle?.id ?? payload['primaryVehicleId'],
        'userProfile':
            _vehicles.isEmpty ? payload['userProfile'] : _userProfile.toJson(),
      };
      _storageService ??= await LocalStorageService.init();
      await _storageService!.restoreSnapshot(snapshot);
      _vehicles
        ..clear()
        ..addAll(vehicles);
      _trips
        ..clear()
        ..addAll(trips);
      _expenses
        ..clear()
        ..addAll(expenses);
      _evidenceList
        ..clear()
        ..addAll(evidence);
      _annualOdometers
        ..clear()
        ..addAll(annual);
      _jobSites
        ..clear()
        ..addAll(jobs);
      _primaryVehicle = _vehicles
              .where((v) => v.id == snapshot['primaryVehicleId'])
              .firstOrNull ??
          _vehicles.firstOrNull;
      if (snapshot['userProfile'] != null) {
        _userProfile = UserProfile.fromJson(
            Map<String, dynamic>.from(snapshot['userProfile'] as Map));
      }
      _rebuildExpenseLinks();
      notifyListeners();
    } finally {
      _backupRestoreGate = null;
      gate.complete();
    }
  }

  Future<void> saveWorkflowReceipt(VehicleExpense expense) async {
    if (_backupRestoreGate != null) {
      throw StateError('Backup restoration is finishing. Try again shortly.');
    }
    final ownerAtStart = _currentUser?.id;
    final coreIssues = const ReceiptWorkflowPolicy().coreIssues(expense);
    if (coreIssues.isNotEmpty) throw FormatException(coreIssues.join('. '));
    final approvalIssues =
        const ReceiptWorkflowPolicy().approvalIssues(expense);
    if (approvalIssues.isNotEmpty) {
      throw FormatException(approvalIssues.join('. '));
    }
    final raw = expense.receiptAudit?.rawOcrText;
    if (raw != null &&
        const ReceiptIntelligenceService().analyseText(raw).hasMixedItems &&
        expense.allocations.isEmpty) {
      throw const FormatException(
          'Split mixed vehicle and private items before recording.');
    }
    if (expense.receiptAudit?.currentFields.containsKey('date') == true &&
        expense.receiptAudit!.currentFields['date'] == null) {
      throw const FormatException('Choose the purchase date before recording.');
    }
    final audit = expense.receiptAudit;
    if (audit?.reviewStatus == ReceiptReviewStatus.confirmed) {
      final pages =
          (audit!.currentFields['pagePaths'] as List?)?.cast<String>() ??
              [if (expense.receiptPath != null) expense.receiptPath!];
      await ReceiptDocumentIntegrity.inspect(pages,
          expectedHashes:
              (audit.currentFields['pageHashes'] as List?)?.cast<String>() ??
                  [if (audit.imageSha256 != null) audit.imageSha256!]);
    }
    if (audit?.reviewStatus == ReceiptReviewStatus.confirmed &&
        audit!.reviewedRevision != null &&
        audit.reviewedRevision != audit.revision) {
      throw StateError(
          'Receipt details changed after confirmation. Review again.');
    }
    if (_currentUser?.id != ownerAtStart) {
      throw StateError('Account changed before saving this receipt.');
    }
    if (_backupRestoreGate != null || _accountTransitionInProgress) {
      throw StateError('Account or backup is changing. Try again shortly.');
    }
    if (_savingWorkflow) {
      throw StateError('Another record is being saved. Try again.');
    }
    if (expense.allocationError != null) {
      throw ArgumentError(expense.allocationError);
    }
    final unchangedLegacyLink = _expenses.any((e) =>
        e.id == expense.id &&
        e.vehicleId == expense.vehicleId &&
        e.linkedTripId == expense.linkedTripId);
    if (!unchangedLegacyLink &&
        expense.linkedTripId != null &&
        !_trips.any((t) =>
            t.id == expense.linkedTripId &&
            t.vehicleId == expense.vehicleId &&
            !t.isDeleted)) {
      throw ArgumentError('Choose an available trip for the same vehicle.');
    }
    final next = [..._expenses];
    final index = next.indexWhere((e) => e.id == expense.id);
    if (index < 0) {
      next.add(expense);
    } else {
      next[index] = expense;
    }
    _savingWorkflow = true;
    final workflowGate = Completer<void>();
    _workflowSaveGate = workflowGate;
    try {
      if (_storageService != null &&
          !await _storageService!.saveExpenses(next)) {
        throw StateError('Could not save this receipt. Try again.');
      }
      _expenses
        ..clear()
        ..addAll(next);
      _rebuildExpenseLinks();
      await _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    } finally {
      _savingWorkflow = false;
      _workflowSaveGate = null;
      workflowGate.complete();
    }
  }

  void recordExpense(VehicleExpense expense) {
    final existing = _expenses.indexWhere((e) => e.id == expense.id);
    if (existing >= 0) {
      updateExpense(expense);
      return;
    }
    _expenses.add(expense);
    _storageService?.saveExpenses(_expenses);

    // If expense was created with a linkedTripId, update that trip's linkedExpenseIds
    if (expense.linkedTripId != null) {
      final tripIndex = _trips.indexWhere((t) => t.id == expense.linkedTripId);
      if (tripIndex != -1) {
        final trip = _trips[tripIndex];
        if (!trip.linkedExpenseIds.contains(expense.id)) {
          _trips[tripIndex] = trip.copyWith(
            linkedExpenseIds: [...trip.linkedExpenseIds, expense.id],
          );
          _storageService?.saveTrips(_trips);
        }
      }
    }

    notifyListeners();
    _autoSyncInBackground();
  }

  void updateExpense(VehicleExpense expense) {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      final oldExp = _expenses[idx];
      // If linkedTripId changed, clean up previous trip link and add to new
      if (oldExp.linkedTripId != expense.linkedTripId) {
        if (oldExp.linkedTripId != null) {
          final prevTripIndex =
              _trips.indexWhere((t) => t.id == oldExp.linkedTripId);
          if (prevTripIndex != -1) {
            final prevTrip = _trips[prevTripIndex];
            _trips[prevTripIndex] = prevTrip.copyWith(
              linkedExpenseIds: prevTrip.linkedExpenseIds
                  .where((id) => id != expense.id)
                  .toList(),
            );
            _storageService?.saveTrips(_trips);
          }
        }
        if (expense.linkedTripId != null) {
          final nextTripIndex =
              _trips.indexWhere((t) => t.id == expense.linkedTripId);
          if (nextTripIndex != -1) {
            final nextTrip = _trips[nextTripIndex];
            if (!nextTrip.linkedExpenseIds.contains(expense.id)) {
              _trips[nextTripIndex] = nextTrip.copyWith(
                linkedExpenseIds: [...nextTrip.linkedExpenseIds, expense.id],
              );
              _storageService?.saveTrips(_trips);
            }
          }
        }
      }

      _expenses[idx] = expense;
      _storageService?.saveExpenses(_expenses);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  /// EVIDENCE GRAPH CASCADE: Delete an expense and remove it from any trip's `linkedExpenseIds`.
  void deleteExpense(String expenseId) {
    // 1. Remove expenseId from any trip's linkedExpenseIds
    bool tripsChanged = false;
    for (int i = 0; i < _trips.length; i++) {
      if (_trips[i].linkedExpenseIds.contains(expenseId)) {
        _trips[i] = _trips[i].copyWith(
          linkedExpenseIds: _trips[i]
              .linkedExpenseIds
              .where((id) => id != expenseId)
              .toList(),
        );
        tripsChanged = true;
      }
    }
    if (tripsChanged) {
      _storageService?.saveTrips(_trips);
    }

    // 2. Remove expense from _expenses
    final expIdx = _expenses.indexWhere((e) => e.id == expenseId);
    if (expIdx != -1) {
      _expenses.removeAt(expIdx);
      _storageService?.saveExpenses(_expenses);
    }

    notifyListeners();
    _autoSyncInBackground();
  }

  void _autoSyncInBackground() {
    if (!isAuthenticated || currentUser == null) return;
    if (_primaryVehicle != null && _syncStatus != SyncStatus.syncing) {
      triggerSyncToCloud();
    }
  }

  EvidenceEngine createEvidenceEngine({String? financialYear}) {
    final vehicle = _primaryVehicle ??
        Vehicle(
          id: 'default',
          make: '',
          model: '',
          regoPlate: '',
          initialOdometer: 0.0,
        );

    final targetFy =
        (financialYear ?? activeTaxRule.financialYear).replaceAll('–', '-');
    const periodEngine = AtoTaxPeriodEngine();

    final scopedTrips = _trips.where((t) {
      if (t.vehicleId != vehicle.id) return false;
      final tripFy =
          periodEngine.forDate(t.date).shortLabel.replaceAll('–', '-');
      return tripFy == targetFy;
    });

    final scopedExpenses = _expenses.where((e) {
      if (e.vehicleId != vehicle.id) return false;
      final expenseFy =
          periodEngine.forDate(e.date).shortLabel.replaceAll('–', '-');
      return expenseFy == targetFy;
    });

    final engine = EvidenceEngine(vehicle: vehicle);
    for (final t in scopedTrips) {
      engine.recordTrip(t);
    }
    for (final e in scopedExpenses) {
      engine.recordExpense(e);
    }
    return engine;
  }

  /// 12-WEEK STATUTORY COMPLIANCE: Current week in 12-week period (1-12)
  int get currentLogbookWeek {
    final start = _primaryVehicle?.logbookStartDate ?? DateTime.now();
    final diffDays = DateTime.now().difference(start).inDays;
    final week = (diffDays / 7).floor() + 1;
    return week.clamp(1, 12);
  }

  /// 12-WEEK STATUTORY COMPLIANCE: Current day in 84-day period (1-84)
  int get currentLogbookDay {
    final start = _primaryVehicle?.logbookStartDate ?? DateTime.now();
    final diffDays = DateTime.now().difference(start).inDays;
    return (diffDays + 1).clamp(1, 84);
  }

  /// 12-WEEK STATUTORY COMPLIANCE: Progress percentage (0.0 - 1.0)
  double get logbookProgressPercentage => currentLogbookWeek / 12.0;

  /// ATO FINANCIAL YEAR (FY) BOUNDARY GUARD:
  /// Evaluates whether the statutory 84-day logbook window straddles across 30 June
  bool get logbookStraddlesFinancialYear {
    final start = _primaryVehicle?.logbookStartDate;
    if (start == null) return false;
    final end = start.add(const Duration(days: 84));
    // Check if 30 June falls strictly between start and end
    final june30Current = DateTime(start.year, 6, 30, 23, 59, 59);
    final june30Next = DateTime(start.year + 1, 6, 30, 23, 59, 59);

    return (start.isBefore(june30Current) && end.isAfter(june30Current)) ||
        (start.isBefore(june30Next) && end.isAfter(june30Next));
  }

  /// Apportionment detail when straddling financial years
  String get logbookFyApportionmentAdvisory {
    if (!logbookStraddlesFinancialYear) return '';
    final start = _primaryVehicle?.logbookStartDate ?? DateTime.now();
    final boundaryYear = start.month > 6 ? start.year + 1 : start.year;
    final june30 = DateTime(boundaryYear, 6, 30);
    final daysInFy1 = june30.difference(start).inDays + 1;
    final daysInFy2 = 84 - daysInFy1;
    return '12-week window spans across 30 June: $daysInFy1 days in FY${boundaryYear - 1}–$boundaryYear, $daysInFy2 days in FY$boundaryYear–${boundaryYear + 1}. Business % applies proportionally.';
  }

  /// Automated check for substantiation gap warning (> 14 consecutive unlogged days)
  /// on the active 12-week logbook period.
  bool get hasActiveLogbookSubstantiationGapWarning {
    return activeLogbookGapEvaluation?.hasWarning ?? false;
  }

  /// Detailed evaluation of unlogged gaps and representative travel pattern for active logbook.
  LogbookGapEvaluation? get activeLogbookGapEvaluation {
    if (_primaryVehicle == null ||
        _primaryVehicle!.taxMethod != TaxMethod.logbook) {
      return null;
    }
    final start = _primaryVehicle!.logbookStartDate;
    if (start == null) return null;

    final period = _activeLogbookPeriod ??
        LogbookPeriod(
          id: 'temp_${_primaryVehicle!.id}',
          vehicleId: _primaryVehicle!.id,
          startDate: start,
          endDate: start.add(const Duration(days: 84)),
          startOdometer: startingOdometer,
          establishedFinancialYear:
              const AtoTaxPeriodEngine().forDate(start).shortLabel,
          validUntilFinancialYear: const AtoTaxPeriodEngine()
              .forDate(start.add(const Duration(days: 365 * 5)))
              .shortLabel,
        );

    final tripDates = _trips
        .where((t) => t.vehicleId == _primaryVehicle!.id)
        .map((t) => t.date)
        .toList();

    return period.evaluateSubstantiationPattern(tripDates);
  }

  /// Automated trigger check for statutory EOFY alerts (June 15, June 28, June 30)
  Future<List<KiloClaimNotification>> checkEofyReminders(
      {DateTime? date, NotificationService? customNotificationService}) async {
    final notifService =
        customNotificationService ?? await NotificationService.getInstance();
    return notifService.evaluateEofyAlertPipeline(
      vehicles: _vehicles,
      isMissingClosingOdometer: (vehicleId, fyLabel) {
        final record = getAnnualOdometer(vehicleId, fyLabel);
        return record == null || record.closingOdometer == null;
      },
      currentDate: date,
    );
  }

  /// COMPLIANCE STATE: Trips with missing purpose or unclassified status
  Future<void> evaluateWeeklyEvidenceReview(
      {DateTime? now, NotificationService? notificationService}) async {
    final date = now ?? DateTime.now();
    final notifications =
        notificationService ?? await NotificationService.getInstance();
    const reviewer = EvidenceReviewService();
    for (final vehicle in List<Vehicle>.of(_vehicles)) {
      if (vehicle.deletedAt != null) continue;
      final snapshot = reviewer.evaluate(
          vehicle: vehicle,
          financialYear: const AtoTaxPeriodEngine().forDate(date).shortLabel,
          trips: _trips,
          expenses: _expenses);
      final files = await reviewer.inspectReceipts(snapshot.expenses);
      final report = reviewer.evaluate(
          vehicle: vehicle,
          financialYear: snapshot.financialYear,
          trips: _trips,
          expenses: _expenses,
          receiptFiles: files);
      await notifications.notifyWeeklyEvidenceReview(report: report, now: date);
    }
  }

  EvidenceReviewReport get evidenceReview =>
      const EvidenceReviewService().evaluate(
        vehicle: _primaryVehicle,
        financialYear: activeTaxRule.financialYear,
        trips: _trips,
        expenses: _expenses,
        hasOdometerGaps: pendingOdometerGaps.isNotEmpty,
      );

  List<Trip> get missingComplianceTrips {
    final report = evidenceReview;
    final ids = report.items
        .whereType<TripReviewItem>()
        .map((item) => item.tripId)
        .toSet();
    return report.trips.where((trip) => ids.contains(trip.id)).toList();
  }

  /// Fix a trip purpose directly in 1 tap
  void resolveTripPurpose(String tripId, String newPurpose) {
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx != -1) {
      final old = _trips[idx];
      _trips[idx] = old.copyWith(
        purpose: newPurpose,
        classification: TripClassification.business,
      );
      _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  /// Tier 1: 1-Tap Batch Approve multiple unclassified/pending work trips
  void batchApproveTrips({
    required List<String> tripIds,
    String? defaultPurpose,
    String? jobReference,
  }) {
    if (tripIds.isEmpty) return;
    bool changed = false;

    for (int i = 0; i < _trips.length; i++) {
      final t = _trips[i];
      if (tripIds.contains(t.id)) {
        final assignedPurpose =
            (defaultPurpose != null && defaultPurpose.isNotEmpty)
                ? defaultPurpose
                : (t.purpose.isNotEmpty && !t.purpose.contains('?')
                    ? t.purpose
                    : 'Client Site Visit');

        _trips[i] = t.copyWith(
          classification: TripClassification.business,
          purpose: assignedPurpose,
          jobReference: jobReference ?? t.jobReference,
        );
        changed = true;
      }
    }

    if (changed) {
      _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  /// Tag a trip with a specific job / client reference
  void tagTripJob({required String tripId, required String jobReference}) {
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx != -1) {
      _trips[idx] = _trips[idx].copyWith(jobReference: jobReference);
      _storageService?.saveTrips(_trips);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  /// Switch active Tax Method for Primary Vehicle
  void updatePrimaryVehicleTaxMethod(TaxMethod newMethod) {
    if (_primaryVehicle == null) return;
    final old = _primaryVehicle!;
    _primaryVehicle = old.copyWith(
      taxMethod: newMethod,
      logbookStartDate: old.logbookStartDate ?? DateTime.now(),
    );
    final idx = _vehicles.indexWhere((v) => v.id == old.id);
    if (idx != -1) {
      _vehicles[idx] = _primaryVehicle!;
    }
    _storageService?.saveVehicles(_vehicles);
    _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);
    notifyListeners();
  }

  /// Tax Summary isolated strictly to Primary Vehicle and active Financial Year
  TaxSummary get taxSummary {
    final vehicleId = _primaryVehicle?.id;
    final targetFy = activeTaxRule.financialYear.replaceAll('–', '-');
    const periodEngine = AtoTaxPeriodEngine();

    final scopedTrips = _trips.where((t) {
      if (vehicleId != null && t.vehicleId != vehicleId) return false;
      final tripFy =
          periodEngine.forDate(t.date).shortLabel.replaceAll('–', '-');
      return tripFy == targetFy;
    }).toList();

    final scopedExpenses = _expenses.where((e) {
      if (vehicleId != null && e.vehicleId != vehicleId) return false;
      final expenseFy =
          periodEngine.forDate(e.date).shortLabel.replaceAll('–', '-');
      return expenseFy == targetFy;
    }).toList();

    return TaxCalculatorService.evaluateSummary(
      trips: scopedTrips,
      expenses: scopedExpenses,
      taxRule: activeTaxRule,
    );
  }

  /// DYNAMIC ATO AUDIT READINESS SCORE (0–100%) scoped to Primary Vehicle
  int get taxReadinessScore {
    final vehicle = _primaryVehicle;
    final hasVeh = vehicle != null;
    final hasTaxMethod = hasVeh;
    final isLogbook = vehicle?.taxMethod == TaxMethod.logbook;
    final hasOdo = (vehicle?.initialOdometer ?? 0) > 0;
    final report = evidenceReview;
    final scopedTrips = report.trips;
    final missingTrips = report.items.whereType<TripReviewItem>().toList();
    final totalTrips = scopedTrips.length;
    final classifiedTrips = totalTrips - missingTrips.length;
    final scopedExpenses =
        report.expenses.where((expense) => !expense.isVaultOnly).toList();
    final totalExpenses = scopedExpenses.length;
    final receiptsBackedUp = totalExpenses == 0 ||
        scopedExpenses.every((e) =>
            (e.receiptPath?.trim().isNotEmpty ?? false) &&
            e.receiptAudit?.reviewStatus == ReceiptReviewStatus.confirmed);

    // =========================================================================
    // DETERMINISTIC AUDIT READINESS FORMULA (4 Pillars = 100% Exact)
    // Pillar 1: Vehicle Configuration (25%)
    // Pillar 2: ATO Strategy Selected (25%)
    // Pillar 3: Contemporary Travel Basis Established (25%)
    // Pillar 4: Records Substantiated & Verified (25%)
    // =========================================================================
    int score = 0;

    // Pillar 1: Vehicle Profile Configured
    if (hasVeh) score += 25;

    // Pillar 2: ATO Tax Method Assigned
    if (hasTaxMethod) score += 25;

    // Pillar 3: Contemporary Travel Basis Established
    // CPK requires actual recorded drive logs (totalTrips > 0)
    // Logbook requires valid opening odometer reading (hasOdo)
    final bool hasBasis = isLogbook ? hasOdo : (totalTrips > 0);
    if (hasBasis) score += 25;

    // Pillar 4: Substantiation & Compliance Verification
    // CPK: All logged trips must be classified as business with valid purpose
    // Logbook: All logged trips classified AND receipts backed up with verified review
    if (totalTrips > 0) {
      if (isLogbook) {
        if (missingTrips.isEmpty && receiptsBackedUp) {
          score += 25;
        } else {
          final tripRatio = classifiedTrips / totalTrips;
          score += (tripRatio * (receiptsBackedUp ? 25 : 12.5)).round();
        }
      } else {
        // CPK Method
        if (missingTrips.isEmpty) {
          score += 25;
        } else {
          score += ((classifiedTrips / totalTrips) * 25).round();
        }
      }
    }

    return score.clamp(0, 100);
  }

  /// Expenses that must be confirmed before accountant export.
  List<VehicleExpense> get unclassifiedExpenses {
    final report = evidenceReview;
    final ids = report.items
        .whereType<ExpenseReviewItem>()
        .where((item) =>
            item.reasons.contains(ExpenseReviewReason.unconfirmedDetails) ||
            item.reasons.contains(ExpenseReviewReason.missingPhoto))
        .map((item) => item.expenseId)
        .toSet();
    return report.expenses
        .where((expense) => ids.contains(expense.id))
        .toList();
  }

  /// Daily Evidence Streak (Consecutive days with at least 1 trip or expense logged)
  int get evidenceStreakDays {
    final activityDates = <DateTime>{};
    for (final t in _trips) {
      activityDates.add(DateTime(t.date.year, t.date.month, t.date.day));
    }
    for (final e in _expenses) {
      activityDates.add(DateTime(e.date.year, e.date.month, e.date.day));
    }

    if (activityDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayDate;

    // If no activity today, check if streak holds from yesterday
    if (!activityDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!activityDates.contains(checkDate)) return 0;
    }

    while (activityDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Backward-compatible alias for triggerSyncToCloud
  Future<SyncResult> syncToCloud() => triggerSyncToCloud();

  /// Trigger Zero-Knowledge Cloud Sync to Supabase
  Future<SyncResult> triggerSyncToCloud() async {
    // Strictly gate on authentication to prevent unauthenticated hits to Supabase REST endpoints
    if (!isAuthenticated || currentUser == null) {
      final res = SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: 'User is not authenticated. Sync aborted.',
      );
      _syncStatus = SyncStatus.idle;
      _syncErrorMessage = null;
      notifyListeners();
      return res;
    }

    if (_primaryVehicle == null) {
      final res = SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: 'No primary vehicle configured to sync.',
      );
      _syncStatus = SyncStatus.error;
      _syncErrorMessage = res.errorMessage;
      notifyListeners();
      return res;
    }

    _syncStatus = SyncStatus.syncing;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      final results = <SyncResult>[];
      final vehiclesToSync =
          _vehicles.isEmpty ? [_primaryVehicle!] : List<Vehicle>.of(_vehicles);
      for (final vehicle in vehiclesToSync) {
        results.add(await _syncEngine.syncToCloud(
            vehicle: vehicle,
            trips: _trips.where((t) => t.vehicleId == vehicle.id).toList(),
            expenses:
                _expenses.where((e) => e.vehicleId == vehicle.id).toList(),
            userToken: currentAccessToken,
            userId: _currentUser?.id,
            requireAuth: true));
      }
      if (_jobSites.isNotEmpty) {
        results.add(await _syncEngine.syncJobSitesToCloud(
          jobSites: _jobSites,
          userToken: currentAccessToken,
          userId: _currentUser?.id,
          requireAuth: true,
        ));
      }
      final failures = results.where((r) => !r.success).toList();
      final res = SyncResult(
          success: failures.isEmpty,
          syncedTrips: results.fold(0, (n, r) => n + r.syncedTrips),
          syncedExpenses: results.fold(0, (n, r) => n + r.syncedExpenses),
          rejectedOrIgnored: results.fold(0, (n, r) => n + r.rejectedOrIgnored),
          errorMessage: failures.isEmpty
              ? null
              : failures.map((r) => r.errorMessage ?? 'Sync failed').join(' '));

      _lastSyncResult = res;
      if (res.success) {
        _syncStatus = SyncStatus.success;
        _lastSyncedAt = DateTime.now();
      } else {
        _syncStatus = SyncStatus.error;
        _syncErrorMessage = res.errorMessage;
      }
      notifyListeners();
      return res;
    } catch (e) {
      final errRes = SyncResult(
        success: false,
        syncedTrips: 0,
        syncedExpenses: 0,
        rejectedOrIgnored: 0,
        errorMessage: e.toString(),
      );
      _syncStatus = SyncStatus.error;
      _syncErrorMessage = e.toString();
      _lastSyncResult = errRes;
      notifyListeners();
      return errRes;
    }
  }

  /// RESTORE FROM CLOUD: Pulls vehicles, trips, and expenses back into state and local storage
  /// Essential for disaster recovery / app reinstall.
  Future<CloudRestoreResult> restoreFromCloud() async {
    final owner = _currentUser?.id;
    final token = currentAccessToken;
    final epoch = ++_cloudRestoreEpoch;
    bool isCurrent() =>
        !_disposed &&
        epoch == _cloudRestoreEpoch &&
        _currentUser?.id == owner &&
        currentAccessToken == token &&
        !_accountTransitionInProgress;
    CloudRestoreResult superseded() => CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        errorMessage: 'Restore cancelled because the session changed.');
    if (!isCurrent()) return superseded();
    // Strictly gate on authentication to prevent unauthenticated hits to Supabase REST endpoints
    if (!isAuthenticated || currentUser == null) {
      final res = CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        corruptedRecordsCount: 0,
        errorMessage: 'User is not authenticated. Restore aborted.',
      );
      _syncStatus = SyncStatus.idle;
      _syncErrorMessage = null;
      notifyListeners();
      return res;
    }

    _syncStatus = SyncStatus.syncing;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      Directory? cacheDir;
      try {
        cacheDir =
            await ReceiptImageOptimizationService().getEvidenceVaultDirectory();
      } catch (e) {
        debugPrint('[AppState] Could not access evidence vault directory: $e');
      }

      if (!isCurrent()) return superseded();
      final result = await _syncEngine.restoreFromCloud(
        userToken: token,
        userId: owner,
        requireAuth: true,
        localCacheDir: cacheDir,
      );
      if (!isCurrent()) return superseded();
      if (result.success ||
          result.vehicles.isNotEmpty ||
          result.trips.isNotEmpty ||
          result.expenses.isNotEmpty ||
          result.jobSites.isNotEmpty) {
        if (result.vehicles.isNotEmpty) {
          // Non-destructive merge: preserve local vehicles while merging cloud updates
          for (final cloudVehicle in result.vehicles) {
            final idx = _vehicles.indexWhere((v) => v.id == cloudVehicle.id);
            if (idx != -1) {
              _vehicles[idx] = cloudVehicle;
            } else {
              _vehicles.add(cloudVehicle);
            }
          }
          if (_primaryVehicle == null ||
              !_vehicles.any((v) => v.id == _primaryVehicle!.id)) {
            _primaryVehicle = _vehicles.firstWhere((v) => v.isPrimary,
                orElse: () => _vehicles.first);
          } else {
            _primaryVehicle =
                _vehicles.firstWhere((v) => v.id == _primaryVehicle!.id);
          }
          _storageService?.saveVehicles(_vehicles);
          _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);
        }
        if (result.trips.isNotEmpty) {
          // Non-destructive merge: preserve un-synced offline trips created locally
          for (final cloudTrip in result.trips) {
            final idx = _trips.indexWhere((t) => t.id == cloudTrip.id);
            if (idx != -1) {
              _trips[idx] = cloudTrip;
            } else {
              _trips.add(cloudTrip);
            }
          }
          _trips.sort((a, b) => a.date.compareTo(b.date));
          _storageService?.saveTrips(_trips);
        }
        if (result.expenses.isNotEmpty) {
          // Non-destructive merge: preserve un-synced offline receipts
          for (final cloudExp in result.expenses) {
            final idx = _expenses.indexWhere((e) => e.id == cloudExp.id);
            if (idx != -1) {
              _expenses[idx] = cloudExp;
            } else {
              _expenses.add(cloudExp);
            }
          }
          _expenses.sort((a, b) => a.date.compareTo(b.date));
          _storageService?.saveExpenses(_expenses);
        }
        _rebuildExpenseLinks();
        await _storageService?.saveTrips(_trips);
        if (!isCurrent()) return superseded();
        if (result.jobSites.isNotEmpty) {
          // Non-destructive merge: preserve locally created JobSites
          for (final cloudSite in result.jobSites) {
            final idx = _jobSites.indexWhere((s) => s.id == cloudSite.id);
            if (idx != -1) {
              _jobSites[idx] = cloudSite;
            } else {
              _jobSites.add(cloudSite);
            }
          }
          _storageService?.saveJobSites(_jobSites);
        }
        _syncStatus = result.success ? SyncStatus.success : SyncStatus.error;
        _syncErrorMessage = result.success ? null : result.errorMessage;
        if (result.success) _lastSyncedAt = DateTime.now();
      } else {
        _syncStatus = SyncStatus.error;
        _syncErrorMessage = result.errorMessage;
      }
      notifyListeners();
      return result;
    } catch (e) {
      if (!isCurrent()) return superseded();
      _syncStatus = SyncStatus.error;
      _syncErrorMessage = e.toString();
      notifyListeners();
      return CloudRestoreResult(
        success: false,
        vehicles: [],
        trips: [],
        expenses: [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Pre-warms DNS and TLS session to Supabase Auth to eliminate cold-start delay
  void prewarmAuthConnection() {
    _authService.prewarmConnection();
  }

  /// Sign In with Apple via Supabase Auth
  /// Supports [onLocalSuccess] for instant optimistic UI transition without waiting for server network hops.
  Future<AuthResult> signInWithApple({
    void Function(AuthUser optimisticUser)? onLocalSuccess,
  }) async {
    _accountTransitionInProgress = true;
    await _backupRestoreGate?.future;
    await _workflowSaveGate?.future;
    try {
      final result = await _authService.signInWithApple(
        onLocalSuccess: (optimisticUser) {
          _currentUser = optimisticUser;
          _isGuestMode = false;
          unawaited(_storageService?.setGuestMode(false));
          notifyListeners();
          if (onLocalSuccess != null) {
            onLocalSuccess(optimisticUser);
          }
        },
      );
      if (result.success && result.user != null) {
        await _adoptGuestReceipts(result.user!.id);
        _currentUser = result.user;
        _isGuestMode = false;
        unawaited(_storageService?.setGuestMode(false));
        notifyListeners();
        // Non-destructive adoption: immediately upload local guest data to cloud
        if (_primaryVehicle != null) {
          triggerSyncToCloud().catchError((e) {
            debugPrint('[AppState] Auto-sync on Apple sign-in warning: $e');
            return SyncResult(
              success: false,
              syncedTrips: 0,
              syncedExpenses: 0,
              rejectedOrIgnored: 0,
              errorMessage: e.toString(),
            );
          });
        }
      }
      return result;
    } finally {
      _accountTransitionInProgress = false;
    }
  }

  /// Sign In with Google via Supabase Auth
  /// Supports [onLocalSuccess] for instant optimistic UI transition without waiting for server network hops.
  Future<AuthResult> signInWithGoogle({
    void Function(AuthUser optimisticUser)? onLocalSuccess,
  }) async {
    _accountTransitionInProgress = true;
    await _backupRestoreGate?.future;
    await _workflowSaveGate?.future;
    try {
      final result = await _authService.signInWithGoogle(
        onLocalSuccess: (optimisticUser) {
          _currentUser = optimisticUser;
          _isGuestMode = false;
          unawaited(_storageService?.setGuestMode(false));
          notifyListeners();
          if (onLocalSuccess != null) {
            onLocalSuccess(optimisticUser);
          }
        },
      );
      if (result.success && result.user != null) {
        await _adoptGuestReceipts(result.user!.id);
        _currentUser = result.user;
        _isGuestMode = false;
        unawaited(_storageService?.setGuestMode(false));
        notifyListeners();
        // Non-destructive adoption: immediately upload local guest data to cloud
        if (_primaryVehicle != null) {
          triggerSyncToCloud().catchError((e) {
            debugPrint('[AppState] Auto-sync on Google sign-in warning: $e');
            return SyncResult(
              success: false,
              syncedTrips: 0,
              syncedExpenses: 0,
              rejectedOrIgnored: 0,
              errorMessage: e.toString(),
            );
          });
        }
      }
      return result;
    } finally {
      _accountTransitionInProgress = false;
    }
  }

  /// Sign Out from Supabase Auth and perform comprehensive teardown:
  /// 1. Disconnects Google and Supabase sessions
  /// 2. Clears active user in memory
  /// 3. Resets vehicle, trips, and expenses to zero state
  /// 4. Purges local cache to protect privacy
  /// 5. Automatically directs the app back to Welcome/Onboarding
  /// Resilient Sign Out (Guaranteed Complete Teardown)
  /// Adheres to OWASP ASVS v4.0.3 (Session Management) & Apple HIG Security:
  /// 1. Server-Side Token Revocation (Supabase Cloud + Google OAuth Disconnect)
  /// 2. Optional Hardware/Local Storage Purge (default: false preserves offline tax evidence on trusted device)
  /// 3. In-Memory Zeroization of active user session
  /// 4. Synchronous UI Notification for Non-Blocking Navigation Reset
  Future<void> signOut({bool wipeLocalData = false}) async {
    _accountTransitionInProgress = true;
    await _backupRestoreGate?.future;
    await _workflowSaveGate?.future;
    try {
      // Pre-flight: If user chose full wipe, attempt a cloud push first to ensure zero data loss
      if (wipeLocalData && _primaryVehicle != null && hasUnsyncedChanges) {
        try {
          await triggerSyncToCloud();
        } catch (e) {
          debugPrint(
              '[KiloClaim Security] Pre-flight cloud sync warning during wipe: $e');
        }
      }

      await _authService.signOut();
    } catch (e) {
      debugPrint(
          '[KiloClaim Security] Non-fatal error during remote token revocation: $e');
    } finally {
      if (wipeLocalData) {
        try {
          await ReceiptInboxService.deleteAccount(_currentUser?.id ?? 'guest',
              knownVehicleIds: _vehicles.map((v) => v.id));
        } catch (e) {
          debugPrint('[Receipt inbox] Local cleanup requires retry: $e');
        }
        try {
          if (_storageService != null) {
            await _storageService!.clearAll();
          }
        } catch (e) {
          debugPrint('[KiloClaim Security] Error clearing local storage: $e');
        }

        try {
          await _evidenceVaultService.clearLocalVault();
        } catch (e) {
          debugPrint(
              '[KiloClaim Security] Error clearing evidence vault during sign out wipe: $e');
        }
        _isGuestMode = false;
      } else {
        // If data kept on device storage, switch to clean guest mode
        _isGuestMode = true;
        await _storageService?.setGuestMode(true);
      }

      // Zero out in-memory local data on sign out to prevent cross-session persistence
      _primaryVehicle = null;
      _vehicles.clear();
      _trips.clear();
      _expenses.clear();
      _evidenceList.clear();
      _annualOdometers.clear();
      _syncStatus = SyncStatus.idle;
      _syncErrorMessage = null;
      _lastSyncResult = null;
      _hasOdometerMonotonicityViolation = false;
      _lastOdometerAnomalyWarning = null;
      _lastTrackingHeartbeatAt = null;

      _currentUser = null;
      _accountTransitionInProgress = false;

      notifyListeners();
    }
  }

  /// In-App Account Deletion per Apple Guideline 5.1.1(v) & Privacy Compliance:
  /// 1. Requires server acknowledgement before clearing recoverable local data
  /// 2. Clears all local storage, preferences, and cached evidence binaries
  /// 3. Zeroes out all in-memory vehicles, trips, expenses, and evidence
  /// 4. Resets app to pristine onboarding state and notifies UI listeners
  Future<bool> deleteAccount() async {
    _accountTransitionInProgress = true;
    await _backupRestoreGate?.future;
    await _workflowSaveGate?.future;
    try {
      try {
        if (!await _authService.deleteAccount()) return false;
      } catch (e) {
        debugPrint('[KiloClaim Security] Error deleting remote account: $e');
        return false;
      }
      try {
        await ReceiptInboxService.deleteAccount(_currentUser?.id ?? 'guest',
            knownVehicleIds: _vehicles.map((v) => v.id));
        if (_storageService != null) {
          await _storageService!.clearAll();
        }
      } catch (e) {
        debugPrint(
            '[KiloClaim Security] Error clearing local storage during account deletion: $e');
      }

      try {
        await _evidenceVaultService.clearLocalVault();
      } catch (e) {
        debugPrint(
            '[KiloClaim Security] Error clearing evidence vault during account deletion: $e');
      }

      // Zero out in-memory local data
      _primaryVehicle = null;
      _vehicles.clear();
      _trips.clear();
      _expenses.clear();
      _evidenceList.clear();
      _annualOdometers.clear();
      _syncStatus = SyncStatus.idle;
      _syncErrorMessage = null;
      _lastSyncResult = null;
      _hasOdometerMonotonicityViolation = false;
      _lastOdometerAnomalyWarning = null;
      _lastSyncedAt = null;
      _lastTrackingHeartbeatAt = null;
      _isGuestMode = false;

      // In-Memory Auth Zeroization
      _currentUser = null;

      // Instant Reactive Navigation Trigger to reset to clean onboarding state
      notifyListeners();
      return true;
    } finally {
      _accountTransitionInProgress = false;
    }
  }

  /// Guest / Local Mode Data Purge:
  /// Clears all local database records, cached evidence binaries, and preferences,
  /// resetting the app to a fresh onboarding zero-state without contacting remote auth backend.
  Future<void> resetLocalData() async {
    _accountTransitionInProgress = true;
    await _backupRestoreGate?.future;
    await _workflowSaveGate?.future;
    try {
      await ReceiptInboxService.deleteAccount(_currentUser?.id ?? 'guest',
          knownVehicleIds: _vehicles.map((v) => v.id));
      if (_storageService != null) {
        await _storageService!.clearAll();
      }
    } catch (e) {
      debugPrint(
          '[KiloClaim Security] Error clearing local storage during data reset: $e');
    }

    try {
      await _evidenceVaultService.clearLocalVault();
    } catch (e) {
      debugPrint(
          '[KiloClaim Security] Error clearing evidence vault during data reset: $e');
    }

    // Zero out in-memory local data
    _primaryVehicle = null;
    _vehicles.clear();
    _trips.clear();
    _expenses.clear();
    _evidenceList.clear();
    _annualOdometers.clear();
    _syncStatus = SyncStatus.idle;
    _syncErrorMessage = null;
    _lastSyncResult = null;
    _hasOdometerMonotonicityViolation = false;
    _lastOdometerAnomalyWarning = null;
    _lastSyncedAt = null;
    _lastTrackingHeartbeatAt = null;

    // In-Memory Auth Zeroization
    _currentUser = null;

    // Instant Reactive Navigation Trigger to reset to clean onboarding state
    _accountTransitionInProgress = false;
    notifyListeners();
  }

  /// Applies a Post-Trip Route Razor trim or split atomically, updating the
  /// primary leg and recording any separated personal/secondary leg.
  void applyRouteRazorResult(RouteRazorResult result) {
    final idx = _trips.indexWhere((t) => t.id == result.primaryTrip.id);
    if (idx != -1) {
      _trips[idx] = result.primaryTrip;
    } else {
      _trips.insert(0, result.primaryTrip);
    }
    _trips.insert(idx != -1 ? idx + 1 : 1, result.secondaryTrip);
    _storageService?.saveTrips(_trips);
    notifyListeners();
  }

  /// Finds same-day consecutive business trip chains eligible under ITAA 1997 s 28-125(3).
  List<SameDayChainCandidate> findSameDayChainCandidates({String? vehicleId}) {
    final targetId = vehicleId ?? _primaryVehicle?.id;
    if (targetId == null) return const [];
    final vehicleTrips =
        _trips.where((t) => t.vehicleId == targetId && !t.isDeleted).toList();
    return TripStopClassifier.findSameDayChainCandidates(vehicleTrips);
  }

  /// Combines a same-day consecutive business chain into a single [Trip] record.
  Trip chainSameDayBusinessTrips(List<Trip> chain, {String? purposeOverride}) {
    final combined = TripStopClassifier.chainBusinessTrips(
      chain,
      combinedTripId: 'chained_${DateTime.now().microsecondsSinceEpoch}',
      purposeOverride: purposeOverride,
    );
    final ids = chain.map((t) => t.id).toSet();
    _trips.removeWhere((t) => ids.contains(t.id));
    _trips.insert(0, combined);
    _storageService?.saveTrips(_trips);
    notifyListeners();
    return combined;
  }

  /// Returns privacy-redacted trips (Stealth Personal Mode) for safe sharing/export.
  RedactedTripBatch exportRedactedTripsForVehicle(String vehicleId) {
    final vehicleTrips =
        _trips.where((t) => t.vehicleId == vehicleId && !t.isDeleted).toList();
    return PrivacyRedactor.redactTrips(vehicleTrips);
  }

  /// Resolves the watchdog platform profile from [defaultTargetPlatform] and
  /// OS/OEM platform metadata when available.
  @visibleForTesting
  DevicePlatformKind resolveWatchdogPlatform({
    TargetPlatform? targetPlatformOverride,
    String? osInfoOverride,
  }) {
    final target = targetPlatformOverride ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.iOS:
        return DevicePlatformKind.ios;
      case TargetPlatform.android:
        final osInfo = (osInfoOverride ??
                (kIsWeb
                    ? ''
                    : '${Platform.operatingSystemVersion} ${Platform.version}'))
            .toLowerCase();
        if (osInfo.contains('samsung') || osInfo.contains('oneui')) {
          return DevicePlatformKind.androidSamsung;
        }
        if (osInfo.contains('xiaomi') ||
            osInfo.contains('miui') ||
            osInfo.contains('hyperos') ||
            osInfo.contains('redmi') ||
            osInfo.contains('poco')) {
          return DevicePlatformKind.androidXiaomi;
        }
        if (osInfo.contains('oppo') ||
            osInfo.contains('coloros') ||
            osInfo.contains('realme') ||
            osInfo.contains('oneplus')) {
          return DevicePlatformKind.androidOppo;
        }
        return DevicePlatformKind.androidGeneric;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return DevicePlatformKind.other;
    }
  }

  List<OdometerAnchor> _buildOdometerAnchors(
    Vehicle vehicle,
    List<Trip> vehicleTrips,
  ) {
    final sortedTrips = List<Trip>.from(vehicleTrips)
      ..sort((a, b) => a.date.compareTo(b.date));
    final tripsWithOdo =
        sortedTrips.where((t) => t.endOdometer > 0.0).toList();
    final vehicleAnnuals =
        _annualOdometers.where((a) => a.vehicleId == vehicle.id).toList();
    final vehiclePeriods =
        _logbookPeriods.where((p) => p.vehicleId == vehicle.id).toList();

    DateTime? initialAnchorDate =
        vehicle.startOdometerVerifiedAt ?? vehicle.logbookStartDate;
    if (initialAnchorDate == null) {
      final candidateDates = <DateTime>[
        if (sortedTrips.isNotEmpty) sortedTrips.first.date,
        ...vehicleAnnuals.map((a) => a.openingDate),
        ...vehiclePeriods.map((p) => p.startDate),
      ];
      if (candidateDates.isNotEmpty) {
        candidateDates.sort();
        initialAnchorDate =
            candidateDates.first.subtract(const Duration(seconds: 1));
      } else {
        initialAnchorDate = DateTime.now();
      }
    } else if (tripsWithOdo.length == 1 &&
        tripsWithOdo.first.stoppedAt == null &&
        tripsWithOdo.first.date.isAtSameMomentAs(initialAnchorDate)) {
      initialAnchorDate =
          initialAnchorDate.subtract(const Duration(seconds: 1));
    }

    final anchors = <OdometerAnchor>[];
    if (vehicle.initialOdometer > 0) {
      anchors.add(
        OdometerAnchor(
          date: initialAnchorDate,
          physicalOdometerKm: vehicle.initialOdometer,
          gpsCumulativeKm: 0.0,
          source: 'initial_odometer',
        ),
      );
    } else {
      final firstOdoTrip =
          sortedTrips.where((t) => t.startOdometer > 0.0).firstOrNull;
      if (firstOdoTrip != null) {
        anchors.add(
          OdometerAnchor(
            date: firstOdoTrip.date.subtract(const Duration(seconds: 1)),
            physicalOdometerKm: firstOdoTrip.startOdometer,
            gpsCumulativeKm: 0.0,
            source: 'first_trip_odometer',
          ),
        );
      } else {
        for (final period in vehiclePeriods) {
          if (period.startOdometer > 0) {
            anchors.add(
              OdometerAnchor(
                date: period.startDate,
                physicalOdometerKm: period.startOdometer,
                gpsCumulativeKm: 0.0,
                source: 'logbook_start',
              ),
            );
          }
        }
        for (final annual in vehicleAnnuals) {
          if (annual.openingOdometer > 0) {
            anchors.add(
              OdometerAnchor(
                date: annual.openingDate,
                physicalOdometerKm: annual.openingOdometer,
                gpsCumulativeKm: 0.0,
                source: 'annual_opening',
              ),
            );
          }
        }
      }
    }

    for (final period in vehiclePeriods) {
      if (period.endOdometer != null &&
          period.endOdometer! > 0 &&
          !period.endDate.isBefore(initialAnchorDate)) {
        anchors.add(
          OdometerAnchor(
            date: period.endDate,
            physicalOdometerKm: period.endOdometer!,
            source: 'logbook_end',
          ),
        );
      }
    }

    for (final annual in vehicleAnnuals) {
      if (annual.closingOdometer != null &&
          annual.closingOdometer! > 0 &&
          annual.closingDate != null &&
          !annual.closingDate!.isBefore(initialAnchorDate)) {
        anchors.add(
          OdometerAnchor(
            date: annual.closingDate!,
            physicalOdometerKm: annual.closingOdometer!,
            source: 'annual_closing',
          ),
        );
      }
    }

    if (tripsWithOdo.isNotEmpty) {
      final latestOdoTrip = tripsWithOdo.reduce((a, b) {
        if (b.endOdometer != a.endOdometer) {
          return b.endOdometer > a.endOdometer ? b : a;
        }
        final aTime = a.stoppedAt ?? a.date;
        final bTime = b.stoppedAt ?? b.date;
        return bTime.isAfter(aTime) ? b : a;
      });
      anchors.add(
        OdometerAnchor(
          date: latestOdoTrip.stoppedAt ?? latestOdoTrip.date,
          physicalOdometerKm: latestOdoTrip.endOdometer,
          source: 'latest_trip_odometer',
        ),
      );
    }

    return anchors;
  }

  /// Builds a live snapshot for [AtoAuditShieldSheet] across Axis B & Axis C engines.
  ({
    ContemporaneousScoreReport slaReport,
    RepresentativeWindowReport? windowReport,
    OdometerCalibrationResult calibrationResult,
    FuelPlausibilityResult fuelPlausibility,
    List<GhostTripCandidate> ghostTrips,
    WatchdogReport watchdogReport,
  }) buildAuditShieldSnapshot({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final vehicle = _primaryVehicle ??
        Vehicle(
          id: 'unassigned',
          make: 'Vehicle',
          model: 'Primary',
          regoPlate: '',
        );
    final vehicleTrips = _primaryVehicle == null
        ? const <Trip>[]
        : _trips.where((t) => t.vehicleId == vehicle.id && !t.isDeleted).toList();
    final vehicleExpenses = _primaryVehicle == null
        ? const <VehicleExpense>[]
        : _expenses
            .where((e) => e.vehicleId == vehicle.id && !e.isDeleted)
            .toList();

    final slaReport =
        ContemporaneousSlaService.evaluateSla(vehicleTrips, now: effectiveNow);
    final windowReport = _activeLogbookPeriod == null
        ? null
        : ContemporaneousSlaService.evaluateRepresentativeWindow(
            period: _activeLogbookPeriod!,
            allTrips: vehicleTrips,
            now: effectiveNow,
          );

    final anchors = _buildOdometerAnchors(vehicle, vehicleTrips);
    final calibrationResult = OdometerCalibrationEngine.computeCalibration(
      vehicle: vehicle,
      anchors: anchors,
      trips: vehicleTrips,
    );
    final fuelPlausibility = OdometerCalibrationEngine.evaluateFuelPlausibility(
      vehicle: vehicle,
      expenses: vehicleExpenses,
      trips: vehicleTrips,
    );
    final ghostTrips = GhostTripDetector.detectGhostTrips(
      expenses: vehicleExpenses,
      trips: vehicleTrips,
      persona: _userProfile.tradePersona,
    );

    final watchdogReport = TrackingWatchdogService.evaluateHealth(
      now: effectiveNow,
      lastHeartbeatAt: lastTrackingHeartbeatAt,
      platform: resolveWatchdogPlatform(),
      hasBackgroundPermission:
          _locationPermissionStatus == AppLocationPermissionStatus.grantedBackground,
      isBatteryOptimizationExempt: true,
      recentTrips: vehicleTrips,
    );

    return (
      slaReport: slaReport,
      windowReport: windowReport,
      calibrationResult: calibrationResult,
      fuelPlausibility: fuelPlausibility,
      ghostTrips: ghostTrips,
      watchdogReport: watchdogReport,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudRestoreEpoch++;
    _authSubscription?.cancel();
    _autonomousPositionSub?.cancel();
    _liveDriveController.dispose();
    super.dispose();
  }
}
