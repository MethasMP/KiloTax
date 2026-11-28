import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/audit/forensic_audit_analyzer.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/services/tracking/native_hardware_telemetry_bridge.dart';
import 'package:kiloclaim/services/tracking/road_snap_routing_service.dart';
import 'package:kiloclaim/services/tracking/sensor_fusion_tracking_engine.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/trip_detail_screen.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/trip_route_preview_widget.dart';

Position _pos({
  required double lat,
  required double lng,
  required DateTime ts,
  double speed = 12.0,
  double accuracy = 5.0,
}) {
  return Position(
    longitude: lng,
    latitude: lat,
    timestamp: ts,
    accuracy: accuracy,
    altitude: 20.0,
    altitudeAccuracy: 5.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 0.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Persistent Live Tracking Lifecycle', () {
    test(
        'LiveDriveController persists stream across screen exit & finishLiveDriveForReview populates coordinates',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'ABC123',
        initialOdometer: 50000,
        isPrimary: true,
      ));

      final streamController = StreamController<Position>.broadcast();
      final t0 = DateTime(2026, 11, 25, 8, 0, 0);
      final startPos = _pos(lat: -37.8136, lng: 144.9631, ts: t0, speed: 0.0);

      appState.startLiveDrive(
        startPosition: startPos,
        originAddress: '100 Flinders St, Melbourne VIC',
      );
      await appState.startOrResumeLiveTracking(
        initialPosition: startPos,
        positionStreamFactory: (_) => streamController.stream,
      );

      // Simulate moving 10 seconds at ~36 km/h (~100m)
      streamController.add(_pos(
        lat: -37.8127,
        lng: 144.9631,
        ts: t0.add(const Duration(seconds: 10)),
        speed: 10.0,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Re-calling startOrResumeLiveTracking (simulating user re-opening screen)
      // must NOT reset distance or breadcrumbs.
      final distBeforeReopen = appState.liveDriveController.distanceKm;
      expect(distBeforeReopen, greaterThan(0.05));
      await appState.startOrResumeLiveTracking(
        positionStreamFactory: (_) => streamController.stream,
      );
      expect(appState.liveDriveController.distanceKm, equals(distBeforeReopen));
      expect(appState.activeDriveBreadcrumbs.length, greaterThanOrEqualTo(2));

      final trip = appState.finishLiveDriveForReview();
      expect(trip, isNotNull);
      expect(trip!.startLat, closeTo(-37.8136, 0.0001));
      expect(trip.startLng, closeTo(144.9631, 0.0001));
      expect(trip.endLat, isNotNull);
      expect(trip.endLng, isNotNull);
      expect(trip.stoppedAt, isNotNull);
      expect(appState.isDriving, isFalse);

      await streamController.close();
      appState.dispose();
    });
  });

  group('2. AutonomousTripDetector & Stitching', () {
    test('AppState wires jobSitesProvider into AutonomousTripDetector',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);

      await appState.addJobSite(JobSite(
        id: 'site_1',
        name: 'Chadstone Site',
        latitude: -37.8860,
        longitude: 145.0830,
        radiusMeters: 250,
        createdAt: DateTime(2026, 11, 1),
      ));

      final sites = appState.autonomousTripDetector.jobSitesProvider?.call();
      expect(sites, isNotNull);
      expect(sites!.length, equals(1));
      expect(sites.first.id, equals('site_1'));
      appState.dispose();
    });

    test(
        'handleFinalizedAutonomousTrip checks stoppedAt time AND <= 500m spatial proximity',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TRD999',
        initialOdometer: 10000,
        isPrimary: true,
      ));

      final start1 = DateTime(2026, 11, 25, 9, 0, 0);
      final stop1 = DateTime(2026, 11, 25, 9, 25, 0);
      final trip1 = Trip(
        id: 't1',
        vehicleId: 'v1',
        distanceKm: 12.0,
        date: start1,
        stoppedAt: stop1,
        startLat: -37.8136,
        startLng: 144.9631,
        endLat: -37.8500,
        endLng: 145.0000,
        purpose: 'Site A',
        startOdometer: 10000,
        endOdometer: 10012,
      );
      appState.recordTrip(trip1);

      // Trip 2 starts 3 minutes after stop1, and 100m away -> SHOULD stitch
      final trip2Close = Trip(
        id: 't2_close',
        vehicleId: 'v1',
        distanceKm: 5.0,
        date: stop1.add(const Duration(minutes: 3)),
        stoppedAt: stop1.add(const Duration(minutes: 10)),
        startLat: -37.8505,
        startLng: 145.0005,
        endLat: -37.8700,
        endLng: 145.0200,
        purpose: 'Site B',
        startOdometer: 10012,
        endOdometer: 10017,
      );
      appState.handleFinalizedAutonomousTrip(trip2Close);
      expect(appState.trips.length, equals(1));
      expect(appState.trips.first.distanceKm, closeTo(17.0, 0.01));

      // Trip 3 starts 2 minutes after stitched stop, but 5 km away -> MUST NOT stitch
      final trip3Far = Trip(
        id: 't3_far',
        vehicleId: 'v1',
        distanceKm: 4.0,
        date: stop1.add(const Duration(minutes: 12)),
        stoppedAt: stop1.add(const Duration(minutes: 18)),
        startLat: -37.9200,
        startLng: 145.0800,
        endLat: -37.9400,
        endLng: 145.1000,
        purpose: 'Site C',
        startOdometer: 10017,
        endOdometer: 10021,
      );
      appState.handleFinalizedAutonomousTrip(trip3Far);
      expect(appState.trips.length, equals(2));

      appState.dispose();
    });
  });

  group('3. SensorFusionTrackingEngine Kalman & Acceleration Gate', () {
    test('rejects impossible acceleration > 7.0 m/s^2 and smooths normal motion',
        () {
      final engine = SensorFusionTrackingEngine();
      final t0 = DateTime(2026, 11, 25, 10, 0, 0);

      // Initial fix
      engine.processFix(_pos(lat: -37.8136, lng: 144.9631, ts: t0, speed: 0.0));

      // Jump ~40 meters in 1 second (40 m/s = 144 km/h, accel = 40 m/s^2 >> 7.0)
      final jumpUpdate = engine.processFix(_pos(
        lat: -37.81324,
        lng: 144.9631,
        ts: t0.add(const Duration(seconds: 1)),
        speed: 10.0,
      ));
      expect(jumpUpdate.isAnomalousJumpDiscarded, isTrue);
      expect(jumpUpdate.distanceDeltaKm, equals(0.0));

      // Normal acceleration: ~5 m/s (18 km/h) in 1s -> 5 m/s^2 <= 7.0
      final normalUpdate = engine.processFix(_pos(
        lat: -37.813555,
        lng: 144.9631,
        ts: t0.add(const Duration(seconds: 1)),
        speed: 5.0,
      ));
      expect(normalUpdate.isAnomalousJumpDiscarded, isFalse);
      expect(normalUpdate.distanceDeltaKm, greaterThan(0.0));
    });
  });

  group('4. Full-Trace Map Matching & Route Preview', () {
    test('matchTrace calls OSRM /match/v1/driving/ and falls back to geodesic path',
        () async {
      final t0 = DateTime(2026, 11, 25, 11, 0, 0);
      final path = [
        _pos(lat: -37.8248, lng: 144.9984, ts: t0),
        _pos(
            lat: -37.8450,
            lng: 145.0400,
            ts: t0.add(const Duration(minutes: 3))),
        _pos(
            lat: -37.8767,
            lng: 145.0934,
            ts: t0.add(const Duration(minutes: 6))),
      ];

      String? requestedPath;
      final matchClient = MockClient((req) async {
        requestedPath = req.url.path;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'matchings': [
              {
                'distance': 13450.0,
                'duration': 920.0,
                'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
              }
            ],
          }),
          200,
        );
      });

      final service = RoadSnapRoutingService(client: matchClient);
      final matched = await service.matchTrace(path);
      expect(requestedPath, contains('/match/v1/driving/'));
      expect(matched.isRoadSnapped, isTrue);
      expect(matched.roadDistanceKm, closeTo(13.45, 0.01));
      expect(matched.geometryPolyline, equals('_p~iF~ps|U_ulLnnqC_mqNvxq`@'));

      // Offline fallback sums path segments
      final offlineService = RoadSnapRoutingService(
        client: MockClient((_) async => http.Response('offline', 503)),
      );
      final offline = await offlineService.matchTrace(path);
      expect(offline.isRoadSnapped, isFalse);
      expect(offline.roadDistanceKm, greaterThan(9.5));
    });

    test('decodePolyline decodes standard polyline & TripRoutePreviewWidget uses neutral copy',
        () {
      final pts =
          RoadSnapRoutingService.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, equals(3));
      expect(pts.first.lat, closeTo(38.5, 0.01));
      expect(pts.first.lng, closeTo(-120.2, 0.01));
    });

    testWidgets('TripRoutePreviewWidget hides 100% Deductible claim',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripRoutePreviewWidget(
              origin: 'Site A',
              destination: 'Bunnings Hawthorn',
              distanceKm: 8.4,
              routePolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
              detectedPoi: {'merchantName': 'Bunnings Warehouse'},
            ),
          ),
        ),
      );
      expect(find.textContaining('100% Deductible'), findsNothing);
      expect(
        find.text('Recognised Trade Supplier · Review purpose before claiming'),
        findsOneWidget,
      );
    });
  });

  group('5. Native Telemetry Bridge & Ingestion', () {
    test('ingestCompletedNativeTrips preserves coordinates and acknowledges IDs',
        () async {
      NativeHardwareTelemetryBridge.testOverrideIsMobileHost = true;
      final methodCalls = <MethodCall>[];
      const channel = MethodChannel('kiloclaim/hardware_telemetry');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        methodCalls.add(call);
        if (call.method == 'getCompletedNativeTrips') {
          return [
            {
              'id': 'native_123',
              'distanceKm': 14.2,
              'startedAt': DateTime(2026, 11, 25, 7, 0).millisecondsSinceEpoch,
              'completedAt':
                  DateTime(2026, 11, 25, 7, 25).millisecondsSinceEpoch,
              'startLatitude': -37.8136,
              'startLongitude': 144.9631,
              'endLatitude': -37.8767,
              'endLongitude': 145.0934,
            }
          ];
        }
        return true;
      });

      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'ISU123',
        initialOdometer: 20000,
        isPrimary: true,
      ));

      await appState.ingestCompletedNativeTrips();

      final nativeTrip = appState.trips.firstWhere((t) => t.id == 'native_123');
      expect(nativeTrip.startLat, closeTo(-37.8136, 0.0001));
      expect(nativeTrip.startLng, closeTo(144.9631, 0.0001));
      expect(nativeTrip.endLat, closeTo(-37.8767, 0.0001));
      expect(nativeTrip.endLng, closeTo(145.0934, 0.0001));
      expect(nativeTrip.stoppedAt, isNotNull);

      appState.updatePrimaryVehicleBluetoothDevice(
        'Hilux Audio',
        bluetoothUuid: 'AA:BB:CC:DD:EE:FF',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        methodCalls.any((c) => c.method == 'setTargetBluetoothTarget'),
        isTrue,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      NativeHardwareTelemetryBridge.testOverrideIsMobileHost = null;
      appState.dispose();
    });
  });

  group('6. Persistence, Reconciliation & Home Commute Detection', () {
    test('LogbookPeriod persists across AppState restarts', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState1 = AppState(storageService: storage);
      await appState1.init(storageService: storage);
      await appState1.addVehicle(Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'LOG123',
        initialOdometer: 45000,
        isPrimary: true,
      ));

      appState1.startLogbookPeriod(
        startDate: DateTime(2026, 7, 1),
        startingOdometer: 45000,
      );
      expect(appState1.logbookPeriods.length, equals(1));
      final periodId = appState1.logbookPeriods.first.id;
      appState1.dispose();

      // Reinitialize from same storage
      final appState2 = AppState(storageService: storage);
      await appState2.init(storageService: storage);
      expect(appState2.logbookPeriods.length, equals(1));
      expect(appState2.logbookPeriods.first.id, equals(periodId));
      expect(appState2.activeLogbookPeriod?.id, equals(periodId));
      appState2.dispose();
    });

    test('updatePrimaryVehicleTaxMethod preserves odometer photos and vehicle metadata',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);

      await appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'PH0123',
        initialOdometer: 30000,
        year: 2024,
        payloadKg: 980,
        isPrimary: true,
        taxMethod: TaxMethod.centsPerKm,
        startOdometerPhotoPath: '/tmp/start_odo.jpg',
        endOdometerPhotoPath: '/tmp/end_odo.jpg',
        tradeToolsDescription: '200kg electrical kit',
      ));

      appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
      final updated = appState.primaryVehicle!;
      expect(updated.taxMethod, equals(TaxMethod.logbook));
      expect(updated.startOdometerPhotoPath, equals('/tmp/start_odo.jpg'));
      expect(updated.endOdometerPhotoPath, equals('/tmp/end_odo.jpg'));
      expect(updated.tradeToolsDescription, equals('200kg electrical kit'));
      expect(updated.year, equals(2024));
      expect(updated.payloadKg, equals(980));
      appState.dispose();
    });

    test('ForensicAuditAnalyzer aligns with OdometerGapReconciler & 0.91 rate',
        () {
      expect(ForensicAuditAnalyzer.gapThresholdKm,
          equals(OdometerGapReconciler.defaultGapThresholdKm));
      expect(ForensicAuditAnalyzer.defaultCentsPerKmRate,
          equals(AppConstants.centsPerKmRate2026));

      final analyzer = ForensicAuditAnalyzer();
      final report = analyzer.analyze(
        trips: [
          Trip(
            id: 't1',
            vehicleId: 'v1',
            distanceKm: 10,
            date: DateTime(2026, 7, 1),
            purpose: 'Site A',
            startOdometer: 1000,
            endOdometer: 1010,
          ),
          Trip(
            id: 't_deleted',
            vehicleId: 'v1',
            distanceKm: 500,
            date: DateTime(2026, 7, 2),
            purpose: 'Deleted',
            startOdometer: 1500,
            endOdometer: 2000,
            deletedAt: DateTime(2026, 7, 2, 12),
          ),
          Trip(
            id: 't2',
            vehicleId: 'v1',
            distanceKm: 10,
            date: DateTime(2026, 7, 3),
            purpose: 'Site B',
            startOdometer: 1011.5,
            endOdometer: 1021.5,
          ),
        ],
        expenses: const <VehicleExpense>[],
      );

      // Deleted trip ignored; 1.5 km gap detected (> 0.1 km threshold)
      expect(report.odometerGaps.length, equals(1));
      expect(report.odometerGaps.first.gapKm, closeTo(1.5, 0.01));
    });

    testWidgets(
        'TripDetailScreen detects home commute from UserProfile coordinates without "home" text',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.updateUserProfile(const UserProfile(
        homeLatitude: -37.8136,
        homeLongitude: 144.9631,
        homeRadiusMeters: 250,
      ));

      final trip = Trip(
        id: 'home_coord_trip',
        vehicleId: 'v1',
        distanceKm: 12.5,
        date: DateTime(2026, 11, 25, 7, 30),
        originAddress: '42 Smith St, Fitzroy VIC',
        destinationAddress: '100 Bourke St, Melbourne VIC',
        startLat: -37.8136,
        startLng: 144.9631,
        endLat: -37.8140,
        endLng: 144.9700,
        purpose: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(trip: trip, appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Home commute trips show the ATO TR 2021/1 bulky tools notice
      expect(find.textContaining('TR 2021/1'), findsOneWidget);
      appState.dispose();
    });
  });
}
