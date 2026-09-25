import 'package:flutter/material.dart';
import '../data/models/vehicle.dart';
import '../data/models/trip.dart';
import '../data/models/vehicle_expense.dart';
import '../data/models/tax_summary.dart';
import '../data/models/audit_evidence.dart';
import '../services/engine/evidence_engine.dart';
import '../services/engine/tax_calculator_service.dart';
import '../services/evidence/evidence_vault_service.dart';
import '../services/sync/sync_engine_service.dart';
import '../services/storage/local_storage_service.dart';
import '../services/auth/supabase_auth_service.dart';

import '../services/engine/tax_rule_service.dart';
import '../core/constants/app_constants.dart';

enum SyncStatus { idle, syncing, success, error }

/// Frontier Drive Telemetry & Vitality Status
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
  final EvidenceVaultService _evidenceVaultService;

  LocalStorageService? _storageService;
  bool _isInitialized = false;

  // TELEMETRY & LIVE DRIVE STATE
  DriveTelemetryStatus _telemetryStatus = DriveTelemetryStatus.armed;
  double _activeDriveDistanceKm = 0.0;
  DateTime? _activeDriveStartedAt;
  bool _isBluetoothLinked = true;

  // SUPABASE AUTH STATE
  final SupabaseAuthService _authService;
  AuthUser? _currentUser;

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
        _syncEngine = syncEngine ?? SyncEngineService(),
        _taxRuleService =
            taxRuleService ?? TaxRuleService(storageService: storageService),
        _evidenceVaultService = evidenceVaultService ?? EvidenceVaultService();

  bool get isInitialized => _isInitialized;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
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
  List<AuditEvidence> get evidenceList => List.unmodifiable(_evidenceList);

  // TELEMETRY GETTERS & ACTIONS
  DriveTelemetryStatus get telemetryStatus => _telemetryStatus;
  bool get isDriving => _telemetryStatus == DriveTelemetryStatus.driving;
  double get activeDriveDistanceKm => _activeDriveDistanceKm;
  DateTime? get activeDriveStartedAt => _activeDriveStartedAt;
  bool get isBluetoothLinked => _isBluetoothLinked;

  double get activeDriveTaxSavedAud {
    final rate = activeTaxRule.centsPerKmRate;
    return _activeDriveDistanceKm * rate;
  }

  void startLiveDrive() {
    _telemetryStatus = DriveTelemetryStatus.driving;
    _activeDriveDistanceKm = 0.0;
    _activeDriveStartedAt = DateTime.now();
    notifyListeners();
  }

  void updateLiveDriveDistance(double distanceKm) {
    if (_telemetryStatus == DriveTelemetryStatus.driving) {
      if ((distanceKm - _activeDriveDistanceKm).abs() >= 0.05 || _activeDriveDistanceKm == 0.0) {
        _activeDriveDistanceKm = distanceKm;
        notifyListeners();
      }
    }
  }

  void endLiveDrive() {
    _telemetryStatus = DriveTelemetryStatus.armed;
    _activeDriveDistanceKm = 0.0;
    _activeDriveStartedAt = null;
    notifyListeners();
  }

  void toggleBluetoothLink(bool linked) {
    _isBluetoothLinked = linked;
    notifyListeners();
  }

  void updatePrimaryVehicleBluetoothDevice(String? deviceName) {
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
    _isBluetoothLinked = deviceName != null && deviceName.isNotEmpty;
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

    if (_storageService != null) {
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

      _evidenceList.clear();
      _evidenceList.addAll(_storageService!.loadEvidence());
    }

    // Restore or listen to Supabase Auth state
    _currentUser = _authService.getCurrentUser();
    _authService.onAuthStateChange?.listen((data) {
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
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });

    // 4. Initialize ATO Tax Compliance Rule (Local Cache first)
    await _taxRuleService.init();

    // 5. Fetch latest official ATO compliance updates silently in background
    _taxRuleService.syncLatestOfficialRates().then((updated) {
      if (updated) {
        notifyListeners();
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);
    if (vehicle.isPrimary || _primaryVehicle == null) {
      _primaryVehicle = vehicle;
      _storageService?.savePrimaryVehicleId(vehicle.id);
    }
    _storageService?.saveVehicles(_vehicles);
    notifyListeners();
  }

  void selectVehicle(String vehicleId) {
    final found = _vehicles.firstWhere((v) => v.id == vehicleId,
        orElse: () => _primaryVehicle!);
    _primaryVehicle = found;
    _storageService?.savePrimaryVehicleId(found.id);
    notifyListeners();
  }

  /// Starting Baseline Odometer of Primary Vehicle
  double get startingOdometer => _primaryVehicle?.initialOdometer ?? 0.0;

  /// Current Live Odometer of Primary Vehicle (Starting Odo + Total Distance Driven)
  double get currentOdometer =>
      getVehicleCurrentOdometer(_primaryVehicle?.id ?? '');

  /// Get Current Odometer for a specific vehicle by ID
  double getVehicleCurrentOdometer(String vehicleId) {
    final vehicle = _vehicles.firstWhere((v) => v.id == vehicleId,
        orElse: () =>
            _primaryVehicle ??
            Vehicle(
              id: 'fallback',
              make: '',
              model: '',
              regoPlate: '',
              initialOdometer: 0.0,
            ));
    final base = vehicle.initialOdometer;
    final vehicleTrips =
        _trips.where((t) => t.vehicleId == vehicle.id).toList();
    if (vehicleTrips.isEmpty) return base;
    return vehicleTrips.last.endOdometer;
  }

  /// Odometer Integrity: Maximum allowed Starting Odometer
  /// If trips already exist for this vehicle, starting odometer CANNOT exceed the first trip's startOdometer
  double? get maxAllowedStartingOdometer {
    if (_primaryVehicle == null) return null;
    final vehicleTrips =
        _trips.where((t) => t.vehicleId == _primaryVehicle!.id).toList();
    if (vehicleTrips.isEmpty) return null;
    return vehicleTrips.first.startOdometer;
  }

  /// Validate new starting odometer according to ATO monotonic progression rules
  (bool isValid, String? errorMessage) validateStartingOdometer(double newOdo) {
    if (newOdo < 0) {
      return (false, 'Starting odometer cannot be negative.');
    }
    final maxAllowed = maxAllowedStartingOdometer;
    if (maxAllowed != null && newOdo > maxAllowed) {
      return (
        false,
        'Cannot exceed first trip start odometer (${maxAllowed.toStringAsFixed(0)} km). Otherwise previous trips become invalid under ATO rules.'
      );
    }
    return (true, null);
  }

  /// Update Starting Odometer safely with invariant checks
  bool updateStartingOdometer(double newOdo) {
    final (isValid, _) = validateStartingOdometer(newOdo);
    if (!isValid || _primaryVehicle == null) return false;

    final old = _primaryVehicle!;
    _primaryVehicle = old.copyWith(
      initialOdometer: newOdo,
    );
    final idx = _vehicles.indexWhere((v) => v.id == old.id);
    if (idx != -1) {
      _vehicles[idx] = _primaryVehicle!;
    }
    _storageService?.saveVehicles(_vehicles);
    _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);
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

  /// Odometer Chain Gapless Verification:
  /// Evaluates whether all recorded trips for primary vehicle connect monotonically without gaps (> 0.1 km)
  bool get isOdometerChainGapless {
    if (_primaryVehicle == null) return true;
    final vehicleTrips =
        _trips.where((t) => t.vehicleId == _primaryVehicle!.id).toList();
    if (vehicleTrips.length <= 1) return true;
    for (int i = 1; i < vehicleTrips.length; i++) {
      final prevEnd = vehicleTrips[i - 1].endOdometer;
      final curStart = vehicleTrips[i].startOdometer;
      if ((curStart - prevEnd).abs() > 0.1) {
        return false;
      }
    }
    return true;
  }

  /// Detects unrecorded odometer gap between current dashboard odometer and target start odometer
  double detectOdometerGap(double nextStartOdometer) {
    final current = currentOdometer;
    final diff = nextStartOdometer - current;
    return diff > 0.01 ? diff : 0.0;
  }

  /// Bridges an unrecorded odometer gap as either Personal or Work travel to maintain gapless compliance
  void fillOdometerGap({
    required double gapEndOdometer,
    required bool isBusiness,
    String? purpose,
    String? origin,
    String? destination,
  }) {
    final startOdo = currentOdometer;
    if (gapEndOdometer <= startOdo) return;
    final distance = gapEndOdometer - startOdo;
    final trip = Trip(
      id: 'gap_bridge_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: _primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: distance,
      date: DateTime.now(),
      purpose: purpose ??
          (isBusiness ? 'Work drive (Bridging)' : 'Personal travel'),
      startOdometer: startOdo,
      endOdometer: gapEndOdometer,
      classification: isBusiness
          ? TripClassification.business
          : TripClassification.personal,
      originAddress:
          origin ?? (isBusiness ? 'Work Site' : '[Private Journey]'),
      destinationAddress:
          destination ?? (isBusiness ? 'Client Site' : '[Private Journey]'),
    );
    recordTrip(trip);
  }

  /// ATO Home-to-Work Compliance Validator (TR 2021/1):
  /// Warns when travel starts at Home and ends at Work Site without transporting bulky trade tools
  (bool isCompliant, String? warning) validateHomeToWorkCompliance({
    required String origin,
    required String destination,
    required String purpose,
    required bool isBulkyToolsCarried,
  }) {
    final origLower = origin.trim().toLowerCase();
    final destLower = destination.trim().toLowerCase();
    final isHomeOrigin =
        origLower.contains('home') || origLower.contains('residence');
    final isWorkDest = destLower.contains('work') ||
        destLower.contains('job') ||
        destLower.contains('site') ||
        destLower.contains('client') ||
        destLower.contains('depot');

    if (isHomeOrigin && isWorkDest && !isBulkyToolsCarried) {
      return (
        false,
        'Home trips require heavy or bulky equipment.'
      );
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
    final isDuplicateInVault = _evidenceList.any((e) => e.imageSha256 == imageHash);
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
      evidenceType: isStart ? EvidenceType.odometerStart : EvidenceType.odometerEnd,
      storagePath: photoPath,
      imageSha256: imageHash,
      capturedAt: captureDate,
      captureSource: 'camera_live',
      watermarkMetadata: watermarkMetadata ?? {
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

  /// Record a new trip with offline-first persistence & invariant guards
  void recordTrip(Trip trip) {
    // Guard against corrupted 0-distance or inverted odometer writes
    if (trip.distanceKm <= 0.0 || trip.endOdometer < trip.startOdometer) {
      debugPrint(
          '[KiloTax Integrity Guard] Ignored invalid zero/negative drive record.');
      return;
    }

    // Check if trip already exists by ID (Idempotent write)
    final existingIdx = _trips.indexWhere((t) => t.id == trip.id);
    if (existingIdx != -1) {
      _trips[existingIdx] = trip;
    } else {
      _trips.add(trip);
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

  /// Spec #4 & #5: Activate 12-Week Logbook Period for Primary Vehicle
  void startLogbookPeriod(
      {required DateTime startDate, required double startingOdometer}) {
    if (_primaryVehicle == null) return;
    final old = _primaryVehicle!;
    _primaryVehicle = old.copyWith(
      initialOdometer: startingOdometer,
      taxMethod: TaxMethod.logbook,
      logbookStartDate: startDate,
    );
    final idx = _vehicles.indexWhere((v) => v.id == old.id);
    if (idx != -1) {
      _vehicles[idx] = _primaryVehicle!;
    }
    _storageService?.saveVehicles(_vehicles);
    _storageService?.savePrimaryVehicleId(_primaryVehicle!.id);

    // Unvault fuel/running expenses that were safely held during CPK mode
    unvaultCpkFuelExpenses();

    notifyListeners();
    _autoSyncInBackground();
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
    final expIndex = _expenses.indexWhere((e) => e.id == expenseId);
    if (expIndex != -1) {
      final oldExp = _expenses[expIndex];
      _expenses[expIndex] = VehicleExpense(
        id: oldExp.id,
        vehicleId: oldExp.vehicleId,
        amount: oldExp.amount,
        category: oldExp.category,
        date: oldExp.date,
        receiptPath: oldExp.receiptPath,
        businessPercentage: oldExp.businessPercentage,
        notes: oldExp.notes,
        linkedTripId: tripId,
        clientDedupId: oldExp.clientDedupId,
        deletedAt: oldExp.deletedAt,
        receiptAudit: oldExp.receiptAudit,
      );
      _storageService?.saveExpenses(_expenses);
    }

    final tripIndex = _trips.indexWhere((t) => t.id == tripId);
    if (tripIndex != -1) {
      final oldTrip = _trips[tripIndex];
      if (!oldTrip.linkedExpenseIds.contains(expenseId)) {
        _trips[tripIndex] = Trip(
          id: oldTrip.id,
          vehicleId: oldTrip.vehicleId,
          distanceKm: oldTrip.distanceKm,
          date: oldTrip.date,
          purpose: oldTrip.purpose,
          startOdometer: oldTrip.startOdometer,
          endOdometer: oldTrip.endOdometer,
          classification: oldTrip.classification,
          originAddress: oldTrip.originAddress,
          destinationAddress: oldTrip.destinationAddress,
          linkedExpenseIds: [...oldTrip.linkedExpenseIds, expenseId],
        );
        _storageService?.saveTrips(_trips);
      }
    }
    notifyListeners();
    _autoSyncInBackground();
  }

  void recordExpense(VehicleExpense expense) {
    _expenses.add(expense);
    _storageService?.saveExpenses(_expenses);
    notifyListeners();
    _autoSyncInBackground();
  }

  void updateExpense(VehicleExpense expense) {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      _expenses[idx] = expense;
      _storageService?.saveExpenses(_expenses);
      notifyListeners();
      _autoSyncInBackground();
    }
  }

  void _autoSyncInBackground() {
    if (_primaryVehicle != null && _syncStatus != SyncStatus.syncing) {
      triggerSyncToCloud();
    }
  }

  EvidenceEngine createEvidenceEngine() {
    final vehicle = _primaryVehicle ??
        Vehicle(
          id: 'default',
          make: '',
          model: '',
          regoPlate: '',
          initialOdometer: 0.0,
        );

    final engine = EvidenceEngine(vehicle: vehicle);
    for (final t in _trips) {
      engine.recordTrip(t);
    }
    for (final e in _expenses) {
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

  /// COMPLIANCE STATE: Trips with missing purpose or unclassified status
  List<Trip> get missingComplianceTrips => _trips
      .where((t) =>
          t.purpose.trim().isEmpty ||
          t.purpose.contains('?') ||
          t.classification == TripClassification.unclassified)
      .toList();

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
        final assignedPurpose = (defaultPurpose != null && defaultPurpose.isNotEmpty)
            ? defaultPurpose
            : (t.purpose.isNotEmpty && !t.purpose.contains('?') ? t.purpose : 'Client Site Visit');

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
    _primaryVehicle = Vehicle(
      id: old.id,
      make: old.make,
      model: old.model,
      regoPlate: old.regoPlate,
      initialOdometer: old.initialOdometer,
      engineCapacity: old.engineCapacity,
      vehicleType: old.vehicleType,
      bluetoothDeviceName: old.bluetoothDeviceName,
      isPrimary: old.isPrimary,
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

  /// Tax Summary isolated strictly to Primary Vehicle
  TaxSummary get taxSummary {
    final vehicleId = _primaryVehicle?.id;
    final scopedTrips = vehicleId != null
        ? _trips.where((t) => t.vehicleId == vehicleId).toList()
        : _trips;
    final scopedExpenses = vehicleId != null
        ? _expenses.where((e) => e.vehicleId == vehicleId).toList()
        : _expenses;

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
    final vehicleId = vehicle?.id;
    final scopedTrips = vehicleId != null
        ? _trips.where((t) => t.vehicleId == vehicleId).toList()
        : _trips;
    final missingTrips = scopedTrips
        .where((t) =>
            t.purpose.trim().isEmpty ||
            t.purpose.contains('?') ||
            t.classification == TripClassification.unclassified)
        .toList();
    final totalTrips = scopedTrips.length;
    final classifiedTrips = totalTrips - missingTrips.length;
    final scopedExpenses = vehicleId != null
        ? _expenses.where((e) => e.vehicleId == vehicleId).toList()
        : _expenses;
    final totalExpenses = scopedExpenses.length;
    final receiptsBackedUp = totalExpenses == 0 ||
        scopedExpenses.every((e) =>
            e.receiptPath != null &&
            e.receiptAudit?.reviewStatus == ReceiptReviewStatus.verified);

    // =========================================================================
    // NASA-GRADE DETERMINISTIC AUDIT READINESS FORMULA (4 Pillars = 100% Exact)
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
  List<VehicleExpense> get unclassifiedExpenses => _expenses
      .where((e) =>
          e.receiptPath == null ||
          e.receiptAudit == null ||
          e.receiptAudit!.needsReview)
      .toList();

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

  /// Trigger Zero-Knowledge Cloud Sync to Supabase
  Future<SyncResult> triggerSyncToCloud() async {
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
      final res = await _syncEngine.syncToCloud(
        vehicle: _primaryVehicle!,
        trips: _trips,
        expenses: _expenses,
        userToken: _currentUser?.accessToken,
        userId: _currentUser?.id,
      );

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
    _syncStatus = SyncStatus.syncing;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      final result = await _syncEngine.restoreFromCloud(
        userToken: _currentUser?.accessToken,
        userId: _currentUser?.id,
      );
      if (result.success) {
        if (result.vehicles.isNotEmpty) {
          _vehicles.clear();
          _vehicles.addAll(result.vehicles);
          _primaryVehicle = _vehicles.firstWhere((v) => v.isPrimary,
              orElse: () => _vehicles.first);
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
        _syncStatus = SyncStatus.success;
        _lastSyncedAt = DateTime.now();
      } else {
        _syncStatus = SyncStatus.error;
        _syncErrorMessage = result.errorMessage;
      }
      notifyListeners();
      return result;
    } catch (e) {
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

  /// Sign In with Apple via Supabase Auth
  Future<AuthResult> signInWithApple() async {
    final result = await _authService.signInWithApple();
    if (result.success && result.user != null) {
      _currentUser = result.user;
      notifyListeners();
    }
    return result;
  }

  /// Sign In with Google via Supabase Auth
  Future<AuthResult> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    if (result.success && result.user != null) {
      _currentUser = result.user;
      notifyListeners();
    }
    return result;
  }

  /// Sign Out from Supabase Auth and perform comprehensive teardown:
  /// 1. Disconnects Google and Supabase sessions
  /// 2. Clears active user in memory
  /// 3. Resets vehicle, trips, and expenses to zero state
  /// 4. Purges local cache to protect privacy
  /// 5. Automatically directs the app back to Welcome/Onboarding
  /// NASA-Grade Resilient Sign Out (Guaranteed Complete Teardown)
  /// Adheres to OWASP ASVS v4.0.3 (Session Management) & Apple HIG Security:
  /// 1. Server-Side Token Revocation (Supabase Cloud + Google OAuth Disconnect)
  /// 2. Optional Hardware/Local Storage Purge (default: false preserves offline tax evidence on trusted device)
  /// 3. In-Memory Zeroization of active user session
  /// 4. Synchronous UI Notification for Non-Blocking Navigation Reset
  Future<void> signOut({bool wipeLocalData = false}) async {
    try {
      // Pre-flight: If user chose full wipe, attempt a cloud push first to ensure zero data loss
      if (wipeLocalData && _primaryVehicle != null && hasUnsyncedChanges) {
        try {
          await triggerSyncToCloud();
        } catch (e) {
          debugPrint(
              '[KiloTax Security] Pre-flight cloud sync warning during wipe: $e');
        }
      }

      // 1. Remote Session Revocation
      await _authService.signOut();
    } catch (e) {
      debugPrint(
          '[KiloTax Security] Non-fatal error during remote token revocation: $e');
    } finally {
      // 2. Hardware / Local Storage Purge (if requested by user)
      if (wipeLocalData) {
        try {
          if (_storageService != null) {
            await _storageService!.clearAll();
          }
        } catch (e) {
          debugPrint('[KiloTax Security] Error clearing local storage: $e');
        }

        // Zero out in-memory local data
        _primaryVehicle = null;
        _vehicles.clear();
        _trips.clear();
        _expenses.clear();
        _evidenceList.clear();
        _syncStatus = SyncStatus.idle;
        _syncErrorMessage = null;
        _lastSyncResult = null;
      }

      // 3. In-Memory Auth Zeroization (Always de-authenticate)
      _currentUser = null;

      // 4. Instant Reactive Navigation Trigger
      notifyListeners();
    }
  }
}
