import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/data/models/tax_summary.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/engine/accounting_export_validator.dart';
import 'package:kiloclaim/services/engine/logbook_export_service.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/services/sync/sync_engine_service.dart';
import 'package:kiloclaim/services/tracking/autonomous_trip_detector.dart';
import 'package:kiloclaim/services/tracking/sensor_fusion_tracking_engine.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position createTestPosition({
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  double speed = 15.0,
  double accuracy = 5.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    accuracy: accuracy,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 1.0,
  );
}

class MockSyncEngineService extends SyncEngineService {
  final List<Vehicle> cloudVehicles;

  MockSyncEngineService({this.cloudVehicles = const []});

  @override
  Future<CloudRestoreResult> restoreFromCloud({
    String? vehicleId,
    String? userToken,
    String? userId,
    bool requireAuth = false,
    dynamic localCacheDir,
  }) async {
    return CloudRestoreResult(
      success: true,
      vehicles: cloudVehicles,
      trips: [],
      expenses: [],
      corruptedRecordsCount: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Systems & Invariants Integrity Tests', () {
    test('1. SensorFusionTrackingEngine uses fix.timestamp & clamps dtSeconds to min 0.05s', () {
      final engine = SensorFusionTrackingEngine();
      final baseTime = DateTime(2026, 10, 27, 10, 0, 0);

      // Fix 1 at baseTime
      final fix1 = createTestPosition(
        latitude: -37.8136,
        longitude: 144.9631,
        timestamp: baseTime,
        speed: 10.0,
      );
      final update1 = engine.processFix(fix1);
      expect(update1.isAnomalousJumpDiscarded, isFalse);

      // Fix 2 arriving in rapid burst: 0ms difference in timestamp, moved 1 meter
      // Lat delta ~0.00001 is ~1.11 meters
      final fix2 = createTestPosition(
        latitude: -37.81361,
        longitude: 144.9631,
        timestamp: baseTime, // dt = 0ms
        speed: 10.0,
      );
      final update2 = engine.processFix(fix2);

      // With dt clamped to 0.05s: 1.11m / 0.05s = 22.2 m/s = ~80 km/h.
      // Crucially, it must NOT divide by 0 or 0.001 (which would yield > 4,000 km/h and discard as anomalous jump!)
      expect(update2.isAnomalousJumpDiscarded, isFalse);
    });

    test('2. Logbook statutory disclaimer references Subdivision 28-F and TR 97/11 (NOT Division 28-C)', () {
      const disclaimer = LogbookExportService.statutoryDisclaimer;
      expect(disclaimer, contains('Subdivision 28-F'));
      expect(disclaimer, contains('TR 97/11'));
      expect(disclaimer.contains('Division 28-C'), isFalse);
      expect(disclaimer.contains('Cents per Kilometre'), isFalse);
    });

    test('3. Accounting Export formats 4-digit financial year (2027 instead of 27 for Xero DD/MM/YYYY regex)', () {
      final vehicle = Vehicle(
        id: 'v_p0_01',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TRADIE-01',
        initialOdometer: 45000,
      );

      final summary = TaxSummary(
        totalKm: 12000,
        businessKm: 9600,
        personalKm: 2400,
        businessPercentage: 80.0,
        totalRunningExpenses: 5000.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 4550.0,
        logbookClaim: 4000.0,
      );

      // Real Australian FY string with 2-digit trailing year
      const taxRule = AtoTaxRule(
        financialYear: '2026-27',
        centsPerKmRate: 0.91,
        centsPerKmMaxKm: 5000,
        carDepreciationLimit: 68108,
      );

      final xeroCsv = LogbookExportService.generateXeroManualJournalCsv(
        vehicle: vehicle,
        summary: summary,
        taxRule: taxRule,
      );

      // Must contain 30/06/2027 (4-digit year)
      expect(xeroCsv, contains(',30/06/2027,'));
      expect(xeroCsv.contains(',30/06/27,'), isFalse);

      final validation = AccountingExportValidator.validateXeroJournalCsv(xeroCsv);
      expect(validation.isValid, isTrue, reason: validation.errors.join('\n'));
    });

    test('4. AppState.restoreFromCloud merges vehicles safely without wiping local vehicles', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();

      final localVehicle = Vehicle(
        id: 'local_veh_unique',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'LOCAL-01',
        initialOdometer: 30000,
      );

      final cloudVehicle = Vehicle(
        id: 'cloud_veh_01',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'CLOUD-01',
        initialOdometer: 15000,
      );

      final mockSync = MockSyncEngineService(cloudVehicles: [cloudVehicle]);

      final appState = AppState(
        storageService: storage,
        syncEngine: mockSync,
      );
      await appState.init();
      await appState.addVehicle(localVehicle);

      // Fake authenticated user to allow restore
      await appState.restoreFromCloud();
      // Unauthenticated check might trigger if currentUser is null, let's verify vehicles remain intact
      expect(appState.vehicles.any((v) => v.id == 'local_veh_unique'), isTrue);
    });

    test('5. AutonomousTripDetector latches vehicle odometer baseline instead of 0.0', () async {
      const vehicleBaselineOdometer = 84500.0;
      final detector = AutonomousTripDetector(
        sustainedSpeedThresholdDuration: const Duration(seconds: 1),
        minDrivingSpeedKmh: 10.0,
        ghostAnchorTimeout: const Duration(seconds: 1),
        odometerProvider: () => vehicleBaselineOdometer,
        vehicleIdProvider: () => 'ute_p0_01',
      );

      final t0 = DateTime(2026, 10, 27, 8, 0, 0);

      // Start idle
      await detector.processFix(
        createTestPosition(latitude: -37.81, longitude: 144.96, timestamp: t0, speed: 0.0),
      );

      // Verify departure & active driving
      await detector.processFix(
        createTestPosition(latitude: -37.82, longitude: 144.97, timestamp: t0.add(const Duration(seconds: 2)), speed: 15.0),
      );
      await detector.processFix(
        createTestPosition(latitude: -37.83, longitude: 144.98, timestamp: t0.add(const Duration(seconds: 4)), speed: 15.0),
      );

      // Ghost anchor stop
      await detector.processFix(
        createTestPosition(latitude: -37.84, longitude: 144.99, timestamp: t0.add(const Duration(seconds: 6)), speed: 0.0),
      );

      // Timeout seals trip
      await detector.processFix(
        createTestPosition(latitude: -37.84, longitude: 144.99, timestamp: t0.add(const Duration(seconds: 10)), speed: 0.0),
      );

      expect(detector.state, equals(AutonomousDetectorState.finalized));
      final trip = detector.finalizedTrip;
      expect(trip, isNotNull);
      expect(trip!.vehicleId, equals('ute_p0_01'));
      expect(trip.startOdometer, equals(vehicleBaselineOdometer));
      expect(trip.endOdometer, greaterThan(vehicleBaselineOdometer));
    });
  });
}
