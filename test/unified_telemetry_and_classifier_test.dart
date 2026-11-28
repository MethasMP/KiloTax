import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/trip_confidence_classifier.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/services/tracking/native_hardware_telemetry_bridge.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/cpk_batch_review_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final siteA = JobSite(
    id: 'site_a',
    name: 'Barangaroo Tower B',
    latitude: -33.8640,
    longitude: 151.2010,
    radiusMeters: 200.0,
  );
  final siteB = JobSite(
    id: 'site_b',
    name: 'Parramatta Civic Works',
    latitude: -33.8150,
    longitude: 151.0011,
    radiusMeters: 200.0,
  );
  const homeProfile = UserProfile(
    homeAddress: '12 Oak St, Ryde NSW',
    homeLatitude: -33.8120,
    homeLongitude: 151.1050,
    homeRadiusMeters: 200.0,
  );

  group('Phase 1: Low-Power Standby & Native Telemetry Ingestion', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('startAutonomousMonitoring uses low-power 150m standby instead of 24/7 high GPS', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'UT3001',
        initialOdometer: 45000,
        isPrimary: true,
      ));

      LocationSettings? capturedSettings;
      final controller = StreamController<Position>.broadcast();
      await appState.startAutonomousMonitoring(
        positionStreamFactory: (settings) {
          capturedSettings = settings;
          return controller.stream;
        },
      );

      expect(capturedSettings, isNotNull);
      expect(capturedSettings!.accuracy, equals(LocationAccuracy.low));
      expect(capturedSettings!.distanceFilter, greaterThanOrEqualTo(150));

      await appState.stopAutonomousMonitoring();
      await controller.close();
      appState.dispose();
    });

    test('ingestCompletedNativeTrips preserves vehicleBluetoothMatched and trigger source', () async {
      NativeHardwareTelemetryBridge.testOverrideIsMobileHost = true;
      const channel = MethodChannel('kiloclaim/hardware_telemetry');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getCompletedNativeTrips') {
          return [
            {
              'id': 'native_bt_1',
              'distanceKm': 18.4,
              'startedAt': DateTime(2026, 11, 28, 7, 30).millisecondsSinceEpoch,
              'completedAt': DateTime(2026, 11, 28, 7, 58).millisecondsSinceEpoch,
              'startLatitude': siteA.latitude,
              'startLongitude': siteA.longitude,
              'endLatitude': siteB.latitude,
              'endLongitude': siteB.longitude,
              'source': 'native_bluetooth_auto',
              'vehicleBluetoothMatched': true,
            },
            {
              'id': 'native_geofence_2',
              'distanceKm': 9.1,
              'startedAt': DateTime(2026, 11, 28, 12, 0).millisecondsSinceEpoch,
              'completedAt': DateTime(2026, 11, 28, 12, 18).millisecondsSinceEpoch,
              'startLatitude': siteB.latitude,
              'startLongitude': siteB.longitude,
              'endLatitude': siteA.latitude,
              'endLongitude': siteA.longitude,
              'source': 'native_motion_geofence',
              'vehicleBluetoothMatched': false,
            },
          ];
        }
        return true;
      });

      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'UT3001',
        initialOdometer: 45000,
        isPrimary: true,
      ));

      await appState.ingestCompletedNativeTrips();

      final btTrip = appState.trips.firstWhere((t) => t.id == 'native_bt_1');
      final geoTrip = appState.trips.firstWhere((t) => t.id == 'native_geofence_2');

      expect(btTrip.evidenceSource, equals('native_bluetooth_auto'));
      expect(btTrip.review['vehicleBluetoothMatched'], isTrue);
      expect(geoTrip.evidenceSource, equals('native_motion_geofence'));
      expect(geoTrip.review['vehicleBluetoothMatched'], isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      NativeHardwareTelemetryBridge.testOverrideIsMobileHost = null;
      appState.dispose();
    });
  });

  group('Phase 2: Evidence Graph Auto-Classification & 1-Tap Batch Review', () {
    test('JobSite A -> JobSite B unlocks highConfidenceWork', () {
      final trip = Trip(
        id: 't_site_to_site',
        vehicleId: 'v_ute',
        distanceKm: 22.5,
        date: DateTime(2026, 11, 28, 10, 0),
        purpose: '',
        originAddress: 'Barangaroo NSW',
        destinationAddress: 'Parramatta NSW',
        startLat: siteA.latitude,
        startLng: siteA.longitude,
        endLat: siteB.latitude,
        endLng: siteB.longitude,
      );

      final result = TripConfidenceClassifier.assess(
        trip,
        context: TripClassificationContext(
          userProfile: homeProfile,
          jobSites: [siteA, siteB],
          isVehicleBluetoothMatched: true,
        ),
      );

      expect(result.isHighConfidence, isTrue);
      expect(result.evidenceSignals, contains(ClassificationSignal.jobSiteToJobSite));
      expect(result.evidenceSignals, contains(ClassificationSignal.vehicleBluetoothMatched));
    });

    test('Receipt-backed non-home trip unlocks highConfidenceWork', () {
      final tripEnd = DateTime(2026, 11, 28, 11, 15);
      final trip = Trip(
        id: 't_bunnings',
        vehicleId: 'v_ute',
        distanceKm: 6.8,
        date: DateTime(2026, 11, 28, 11, 0),
        stoppedAt: tripEnd,
        purpose: '',
        originAddress: 'Barangaroo NSW',
        destinationAddress: 'Bunnings Warehouse Alexandria',
        startLat: siteA.latitude,
        startLng: siteA.longitude,
      );
      final receipt = VehicleExpense(
        id: 'exp_1',
        vehicleId: 'v_ute',
        category: ExpenseCategory.fuel,
        amount: 94.50,
        date: tripEnd.add(const Duration(minutes: 10)),
        supplier: 'Bunnings Warehouse',
      );

      final result = TripConfidenceClassifier.assess(
        trip,
        context: TripClassificationContext(
          userProfile: homeProfile,
          jobSites: [siteA],
          expenses: [receipt],
        ),
      );

      expect(result.isHighConfidence, isTrue);
      expect(result.evidenceSignals, contains(ClassificationSignal.receiptBacked));
      expect(result.suggestedPurpose, contains('Bunnings Warehouse'));
    });

    test('Home -> JobSite stays gated without registered bulky tools, unlocks with registered tools', () {
      final trip = Trip(
        id: 't_home_to_site',
        vehicleId: 'v_ute',
        distanceKm: 19.0,
        date: DateTime(2026, 11, 28, 6, 45),
        purpose: '',
        originAddress: '12 Oak St, Ryde NSW',
        destinationAddress: 'Barangaroo Tower B',
        startLat: homeProfile.homeLatitude,
        startLng: homeProfile.homeLongitude,
        endLat: siteA.latitude,
        endLng: siteA.longitude,
      );

      final vehicleNoTools = Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'HiLux',
      );
      final gated = TripConfidenceClassifier.assess(
        trip,
        context: TripClassificationContext(
          userProfile: homeProfile,
          vehicle: vehicleNoTools,
          jobSites: [siteA],
        ),
      );
      expect(gated.isHighConfidence, isFalse);
      expect(gated.evidenceSignals, contains(ClassificationSignal.homeCommuteGate));

      final vehicleWithTools = Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'HiLux',
        tradeToolsDescription: '2.4m ladder + 35kg Milwaukee packout',
        tradeToolsRegisteredAt: DateTime(2026, 7, 1),
      );
      final unlocked = TripConfidenceClassifier.assess(
        trip,
        context: TripClassificationContext(
          userProfile: homeProfile,
          vehicle: vehicleWithTools,
          jobSites: [siteA],
        ),
      );
      expect(unlocked.isHighConfidence, isTrue);
      expect(unlocked.suggestedBulkyTools, isTrue);
      expect(unlocked.evidenceSignals, contains(ClassificationSignal.bulkyToolsHomeException));
    });

    test('Personal POI is never promoted to highConfidenceWork', () {
      final trip = Trip(
        id: 't_school',
        vehicleId: 'v_ute',
        distanceKm: 4.2,
        date: DateTime(2026, 11, 28, 15, 15),
        purpose: '',
        originAddress: 'Barangaroo NSW',
        destinationAddress: 'Ryde Public School',
        startLat: siteA.latitude,
        startLng: siteA.longitude,
      );

      final result = TripConfidenceClassifier.assess(
        trip,
        context: TripClassificationContext(
          userProfile: homeProfile,
          jobSites: [siteA],
          isVehicleBluetoothMatched: true,
        ),
      );

      expect(result.isHighConfidence, isFalse);
      expect(result.suggestedPurpose, equals('Personal'));
      expect(result.evidenceSignals, contains(ClassificationSignal.personalPoiDetected));
    });

    testWidgets('CpkBatchReviewSheet lights up 1-Tap Sign-Off for evidence-backed work trips',
        (tester) async {
      final appState = AppState();
      await appState.addVehicle(Vehicle(
        id: 'v_ute',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'UT3001',
        initialOdometer: 10000,
        taxMethod: TaxMethod.centsPerKm,
      ));
      appState.addJobSite(siteA);
      appState.addJobSite(siteB);
      appState.recordTrip(
        Trip(
          id: 't_ready_1',
          vehicleId: 'v_ute',
          distanceKm: 25.0,
          date: DateTime(2026, 11, 28, 9, 0),
          purpose: '',
          originAddress: 'Barangaroo Tower B',
          destinationAddress: 'Parramatta Civic Works',
          startLat: siteA.latitude,
          startLng: siteA.longitude,
          endLat: siteB.latitude,
          endLng: siteB.longitude,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CpkBatchReviewSheet(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONFIRMED WORK DRIVES (READY)'), findsOneWidget);
      expect(find.text('Sign-Off (1)'), findsOneWidget);
    });
  });
}
