import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/logbook_period.dart';
import 'package:kiloclaim/data/models/trade_persona.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/audit/contemporaneous_sla_service.dart';
import 'package:kiloclaim/services/engine/privacy_redactor.dart';
import 'package:kiloclaim/services/evidence/ghost_trip_detector.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/services/tracking/odometer_calibration_engine.dart';
import 'package:kiloclaim/services/tracking/road_snap_routing_service.dart';
import 'package:kiloclaim/services/tracking/tracking_watchdog_service.dart';
import 'package:kiloclaim/services/tracking/trip_route_razor.dart';
import 'package:kiloclaim/services/tracking/trip_stop_classifier.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/audit/ato_audit_shield_sheet.dart';
import 'package:kiloclaim/ui/screens/trips/back_capture_trip_sheet.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/trip_route_razor_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRoadSnapRoutingService extends RoadSnapRoutingService {
  final RoadRouteResult stubResult;

  _FakeRoadSnapRoutingService(this.stubResult);

  @override
  Future<RoadRouteResult> calculateRoadDistanceKm({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    bool includeGeometry = true,
  }) async {
    return stubResult;
  }
}

void main() {
  final testVehicle = Vehicle(
    id: 'veh_1',
    make: 'Toyota',
    model: 'Hilux',
    vehicleType: VehicleType.ute,
    taxMethod: TaxMethod.logbook,
  );

  final testProfile = UserProfile(
    homeAddress: '10 Home St, Parramatta NSW',
    homeLatitude: -33.8150,
    homeLongitude: 151.0011,
    homeRadiusMeters: 200.0,
    tradePersona: TradePersona.sparky,
  );

  final testJobSite = JobSite(
    id: 'site_1',
    name: 'Smith Reno',
    clientName: 'Smith',
    address: '50 George St, Sydney NSW',
    latitude: -33.8688,
    longitude: 151.2093,
    radiusMeters: 200.0,
  );

  group('Axis A: TripStopClassifier', () {
    test('short Bunnings/Reece stop (< 15m) is pitStopPending and does not split', () {
      final result = TripStopClassifier.classifyStop(
        StopContextInput(
          dwellDuration: const Duration(minutes: 10),
          placeNameOrAddress: 'Bunnings Warehouse Penrith',
          tradePersona: TradePersona.sparky,
        ),
      );
      expect(result.classification, StopClassification.pitStopPending);
      expect(result.shouldSplitTrip, isFalse);
      expect(result.isPitStop, isTrue);
      expect(result.matchedTradePoi?.merchantName, 'Bunnings Warehouse');
    });

    test('stop >= 3m at Home Base splits leg', () {
      final result = TripStopClassifier.classifyStop(
        StopContextInput(
          dwellDuration: const Duration(minutes: 4),
          latitude: -33.8151,
          longitude: 151.0012,
          userProfile: testProfile,
        ),
      );
      expect(result.classification, StopClassification.homeStopSplit);
      expect(result.shouldSplitTrip, isTrue);
    });

    test('stop >= 3m at active JobSite splits leg', () {
      final result = TripStopClassifier.classifyStop(
        StopContextInput(
          dwellDuration: const Duration(minutes: 5),
          latitude: -33.8689,
          longitude: 151.2092,
          jobSites: [testJobSite],
        ),
      );
      expect(result.classification, StopClassification.jobStopSplit);
      expect(result.shouldSplitTrip, isTrue);
      expect(result.matchedJobSite?.id, 'site_1');
    });

    test('stop >= 3m at personal POI (supermarket) splits leg', () {
      final result = TripStopClassifier.classifyStop(
        StopContextInput(
          dwellDuration: const Duration(minutes: 6),
          placeNameOrAddress: 'Woolworths Parramatta',
        ),
      );
      expect(result.classification, StopClassification.personalStopSplit);
      expect(result.shouldSplitTrip, isTrue);
    });

    test('findSameDayChainCandidates & chainBusinessTrips under s 28-125(3)', () {
      final day = DateTime(2026, 11, 20, 8, 0);
      final t1 = Trip(
        id: 't1',
        vehicleId: 'veh_1',
        distanceKm: 12.5,
        date: day,
        stoppedAt: day.add(const Duration(minutes: 20)),
        purpose: 'Reece Plumbing',
        startOdometer: 10000.0,
        endOdometer: 10012.5,
        originAddress: 'Home',
        destinationAddress: 'Reece',
        linkedExpenseIds: const ['exp_1'],
      );
      final t2 = Trip(
        id: 't2',
        vehicleId: 'veh_1',
        distanceKm: 18.0,
        date: day.add(const Duration(minutes: 32)),
        stoppedAt: day.add(const Duration(minutes: 60)),
        purpose: 'Smith Reno',
        startOdometer: 10012.5,
        endOdometer: 10030.5,
        originAddress: 'Reece',
        destinationAddress: 'Smith Reno',
      );
      // Personal trip later in the day should not merge
      final t3 = Trip(
        id: 't3',
        vehicleId: 'veh_1',
        distanceKm: 5.0,
        date: day.add(const Duration(hours: 3)),
        purpose: 'Personal',
        classification: TripClassification.personal,
        startOdometer: 10030.5,
        endOdometer: 10035.5,
      );

      final candidates = TripStopClassifier.findSameDayChainCandidates([t1, t2, t3]);
      expect(candidates, hasLength(1));
      expect(candidates.first.trips.map((t) => t.id), ['t1', 't2']);
      expect(candidates.first.totalDistanceKm, 30.5);

      final chained = TripStopClassifier.chainBusinessTrips(
        candidates.first.trips,
        combinedTripId: 'chained_1',
      );
      expect(chained.distanceKm, 30.5);
      expect(chained.startOdometer, 10000.0);
      expect(chained.endOdometer, 10030.5);
      expect(chained.evidenceSource, 'chained_s28_125_3');
      expect(chained.linkedExpenseIds, ['exp_1']);
      expect(chained.review['statutoryBasis'], 'ITAA 1997 s 28-125(3)');
    });
  });

  group('Axis A: TripRouteRazor', () {
    test('trimTailAtWaypoint conserves odometer and preserves raw audit snapshot', () {
      final start = DateTime(2026, 11, 20, 16, 0);
      final original = Trip(
        id: 'trip_orig',
        vehicleId: 'veh_1',
        distanceKm: 40.0,
        date: start,
        stoppedAt: start.add(const Duration(minutes: 50)),
        purpose: 'Client Site',
        startOdometer: 20000.0,
        endOdometer: 20040.0,
        originAddress: 'Depot',
        destinationAddress: 'Home (forgot to stop)',
        endLat: -33.8150,
        endLng: 151.0011,
      );

      final wp = RouteWaypoint(
        lat: -33.8688,
        lng: 151.2093,
        timestamp: start.add(const Duration(minutes: 30)),
        cumulativeKm: 25.0,
        label: 'Smith Reno Site',
      );

      final result = TripRouteRazor.trimTailAtWaypoint(
        original: original,
        waypoint: wp,
        secondaryTripId: 'trip_tail',
      );

      expect(result.odometerConserved, isTrue);
      expect(result.primaryTrip.distanceKm, 25.0);
      expect(result.primaryTrip.startOdometer, 20000.0);
      expect(result.primaryTrip.endOdometer, 20025.0);
      expect(result.primaryTrip.classification, TripClassification.business);

      expect(result.secondaryTrip.distanceKm, 15.0);
      expect(result.secondaryTrip.startOdometer, 20025.0);
      expect(result.secondaryTrip.endOdometer, 20040.0);
      expect(result.secondaryTrip.classification, TripClassification.personal);

      expect(result.rawAuditSnapshot['originalDistanceKm'], 40.0);
      expect(result.rawAuditSnapshot['operation'], 'trim_tail');
      expect(result.primaryTrip.review['routeRazorAudit'], isNotNull);
    });

    test('splitMixedTrip throws on invalid split distance', () {
      final original = Trip(
        id: 't_short',
        vehicleId: 'veh_1',
        distanceKm: 10.0,
        date: DateTime(2026, 11, 20),
        purpose: 'Mixed',
      );
      expect(
        () => TripRouteRazor.splitMixedTrip(
          original: original,
          businessKm: 10.0,
          secondaryTripId: 't2',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Axis B: OdometerCalibrationEngine', () {
    test('detects >2% drift (CR 2021/16 para 35) and computes calibration factor', () {
      final anchors = [
        OdometerAnchor(
          date: DateTime(2026, 10, 1),
          physicalOdometerKm: 50000.0,
          gpsCumulativeKm: 0.0,
          source: 'logbook_start',
        ),
        OdometerAnchor(
          date: DateTime(2026, 11, 1),
          physicalOdometerKm: 51050.0,
          gpsCumulativeKm: 1000.0,
          source: 'service_invoice_ocr',
        ),
      ];

      final res = OdometerCalibrationEngine.computeCalibration(
        vehicle: testVehicle,
        anchors: anchors,
        trips: const [],
      );

      expect(res.calibrationFactor, closeTo(1.05, 0.001));
      expect(res.driftPercent, closeTo(4.76, 0.1));
      expect(res.requiresRecalibrationAlert, isTrue);
      expect(res.applyToGpsKm(100.0), closeTo(105.0, 0.1));
    });

    test('evaluateFuelPlausibility flags implausibly low fuel for ute', () {
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'veh_1',
          distanceKm: 2000.0,
          date: DateTime(2026, 11, 1),
          purpose: 'Jobs',
        ),
      ];
      final expenses = [
        VehicleExpense(
          id: 'e1',
          vehicleId: 'veh_1',
          amount: 120.0,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 11, 10),
          notes: '60 litres unleaded',
        ),
      ];

      final fuelRes = OdometerCalibrationEngine.evaluateFuelPlausibility(
        vehicle: testVehicle,
        trips: trips,
        expenses: expenses,
      );

      expect(fuelRes.hasSufficientData, isTrue);
      expect(fuelRes.totalFuelLitres, 60.0);
      expect(fuelRes.estimatedLitresPer100Km, 3.0);
      expect(fuelRes.isPlausible, isFalse);
    });
  });

  group('Axis C: TrackingWatchdogService', () {
    test('detects battery saver risk and returns Samsung OEM steps', () {
      final report = TrackingWatchdogService.evaluateHealth(
        now: DateTime(2026, 11, 25, 10, 0),
        hasBackgroundPermission: true,
        isBatteryOptimizationExempt: false,
        platform: DevicePlatformKind.androidSamsung,
      );
      expect(report.status, WatchdogHealthStatus.batterySaverRisk);
      expect(report.recoveryReady, isFalse);
      expect(report.oemGuidanceTitle, contains('Samsung'));
      expect(report.oemGuidanceSteps.join(' '), contains('Never sleeping apps'));
    });

    test('detects stale gap >= 48h', () {
      final now = DateTime(2026, 11, 25, 10, 0);
      final report = TrackingWatchdogService.evaluateHealth(
        now: now,
        lastHeartbeatAt: now.subtract(const Duration(hours: 60)),
        hasBackgroundPermission: true,
        isBatteryOptimizationExempt: true,
      );
      expect(report.status, WatchdogHealthStatus.staleGapDetected);
      expect(report.isStaleGap, isTrue);
    });
  });

  group('Axis C: ContemporaneousSlaService', () {
    test('evaluates 7-day CR 2026/71 SLA and scores breached vs compliant', () {
      final now = DateTime(2026, 11, 25, 12, 0);
      final trips = [
        Trip(
          id: 'ok',
          vehicleId: 'veh_1',
          distanceKm: 10,
          date: now.subtract(const Duration(days: 3)),
          purpose: 'Client Site',
          review: {
            'capturedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
            'purposeConfirmedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          },
        ),
        Trip(
          id: 'overdue',
          vehicleId: 'veh_1',
          distanceKm: 15,
          date: now.subtract(const Duration(days: 10)),
          purpose: '',
          classification: TripClassification.unclassified,
        ),
      ];

      final report = ContemporaneousSlaService.evaluateSla(trips, now: now);
      expect(report.totalEvaluatedTrips, 2);
      expect(report.confirmedWithin7DaysCount, 1);
      expect(report.breachedCount, 1);
      expect(report.integrityScorePercent, 50.0);
    });

    test('detects >15% business pattern shift vs 12-week logbook', () {
      final now = DateTime(2026, 11, 25);
      final period = LogbookPeriod(
        id: 'lb_1',
        vehicleId: 'veh_1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 3, 27),
        startOdometer: 10000,
        status: LogbookStatus.certifiedValid,
        certifiedBusinessPercentage: 85.0,
        establishedFinancialYear: '2025-26',
        validUntilFinancialYear: '2029-30',
      );

      final recentTrips = [
        Trip(
          id: 'r1',
          vehicleId: 'veh_1',
          distanceKm: 50,
          date: now.subtract(const Duration(days: 5)),
          purpose: 'Client Site',
          classification: TripClassification.business,
        ),
        Trip(
          id: 'r2',
          vehicleId: 'veh_1',
          distanceKm: 50,
          date: now.subtract(const Duration(days: 3)),
          purpose: 'Personal',
          classification: TripClassification.personal,
        ),
      ];

      final window = ContemporaneousSlaService.evaluateRepresentativeWindow(
        period: period,
        allTrips: recentTrips,
        now: now,
      );
      expect(window.patternShiftPercent, 35.0);
      expect(window.hasPatternShiftAlert, isTrue);
    });
  });

  group('Axis C: GhostTripDetector', () {
    test('flags receipt without trip within ±45 min and ignores matched receipt', () {
      final receiptTime = DateTime(2026, 11, 20, 14, 12);
      final unmatchedExpense = VehicleExpense(
        id: 'exp_ghost',
        vehicleId: 'veh_1',
        amount: 84.50,
        category: ExpenseCategory.toolsMaterials,
        date: receiptTime,
        supplier: 'Reece Penrith',
      );
      final matchedExpense = VehicleExpense(
        id: 'exp_matched',
        vehicleId: 'veh_1',
        amount: 95.00,
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 11, 20, 9, 0),
        supplier: 'BP Servo',
      );
      final morningTrip = Trip(
        id: 't_morning',
        vehicleId: 'veh_1',
        distanceKm: 12.0,
        date: DateTime(2026, 11, 20, 8, 45),
        purpose: 'Fuel & Site',
      );

      final ghosts = GhostTripDetector.detectGhostTrips(
        expenses: [unmatchedExpense, matchedExpense],
        trips: [morningTrip],
      );

      expect(ghosts, hasLength(1));
      expect(ghosts.first.merchantName, 'Reece Penrith');
      expect(ghosts.first.promptText, contains('Reece Penrith'));
    });
  });

  group('Axis C: PrivacyRedactor', () {
    test('strips coordinates and addresses from Personal and Mixed legs while preserving odometer', () {
      final personal = Trip(
        id: 'p1',
        vehicleId: 'veh_1',
        distanceKm: 14.2,
        date: DateTime(2026, 11, 20),
        purpose: 'Doctor Visit',
        startOdometer: 10100.0,
        endOdometer: 10114.2,
        classification: TripClassification.personal,
        originAddress: '10 Home St',
        destinationAddress: '99 Clinic Rd',
        startLat: -33.8,
        startLng: 151.0,
        endLat: -33.9,
        endLng: 151.1,
        routePolyline: 'encoded_poly',
      );

      final business = Trip(
        id: 'b1',
        vehicleId: 'veh_1',
        distanceKm: 20.0,
        date: DateTime(2026, 11, 20),
        purpose: 'Client Site',
        startOdometer: 10114.2,
        endOdometer: 10134.2,
        classification: TripClassification.business,
        originAddress: 'Depot',
        destinationAddress: 'Smith Reno',
        startLat: -33.8,
        startLng: 151.0,
      );

      final batch = PrivacyRedactor.redactTrips([personal, business]);
      expect(batch.summary.redactedTripCount, 1);
      expect(batch.summary.preservedTripCount, 1);
      expect(batch.summary.totalPersonalKmPreserved, 14.2);

      final redactedPersonal = batch.trips.first;
      expect(redactedPersonal.startLat, isNull);
      expect(redactedPersonal.endLat, isNull);
      expect(redactedPersonal.routePolyline, isNull);
      expect(redactedPersonal.originAddress, PrivacyRedactor.redactedAddressLabel);
      expect(redactedPersonal.startOdometer, 10100.0);
      expect(redactedPersonal.endOdometer, 10114.2);
      expect(redactedPersonal.distanceKm, 14.2);
      expect(redactedPersonal.review['privacyRedacted'], isTrue);

      expect(batch.trips.last.originAddress, 'Depot');
    });
  });

  group('UI Sheets Widget Tests', () {
    testWidgets('TripRouteRazorSheet renders and emits RouteRazorResult on apply',
        (tester) async {
      RouteRazorResult? captured;
      final trip = Trip(
        id: 't_ui',
        vehicleId: 'veh_1',
        distanceKm: 30.0,
        date: DateTime(2026, 11, 20, 15, 0),
        purpose: 'Client Site',
        startOdometer: 1000.0,
        endOdometer: 1030.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripRouteRazorSheet(
              trip: trip,
              onApply: (res) => captured = res,
              secondaryIdBuilder: () => 't_ui_tail',
            ),
          ),
        ),
      );

      expect(find.text('Route Razor'), findsOneWidget);
      expect(find.text('Trim Tail & Save Legs'), findsOneWidget);

      await tester.tap(find.text('Trim Tail & Save Legs'));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.odometerConserved, isTrue);
      expect(captured!.secondaryTrip.id, 't_ui_tail');
    });

    testWidgets('BackCaptureTripSheet calculates route and saves reconstructed trip',
        (tester) async {
      Trip? savedTrip;
      final fakeRouting = _FakeRoadSnapRoutingService(
        const RoadRouteResult(
          roadDistanceKm: 22.4,
          straightLineDistanceKm: 18.1,
          isRoadSnapped: true,
          durationSeconds: 1500,
          geometryPolyline: 'fake_poly',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackCaptureTripSheet(
              vehicleId: 'veh_1',
              userProfile: testProfile,
              jobSites: [testJobSite],
              routingService: fakeRouting,
              onSave: (t) => savedTrip = t,
            ),
          ),
        ),
      );

      // Select destination JobSite chip
      await tester.tap(find.text('Smith Reno').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Calculate Route'));
      await tester.tap(find.text('Calculate Route'));
      await tester.pumpAndSettle();

      expect(find.text('22.4 km'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Trip'));
      await tester.tap(find.text('Save Trip'));
      await tester.pump();

      expect(savedTrip, isNotNull);
      expect(savedTrip!.distanceKm, 22.4);
      expect(savedTrip!.evidenceSource, 'manual_route_reconstructed');
    });

    testWidgets('AtoAuditShieldSheet displays all 5 audit sections and triggers ghost recovery',
        (tester) async {
      GhostTripCandidate? recovered;
      final ghost = GhostTripCandidate(
        id: 'g1',
        expense: VehicleExpense(
          id: 'e1',
          vehicleId: 'veh_1',
          amount: 55.0,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 11, 20, 12, 30),
          supplier: 'Shell Servo',
        ),
        merchantName: 'Shell Servo',
        receiptTimestamp: DateTime(2026, 11, 20, 12, 30),
        amount: 55.0,
        suggestedPurpose: 'Fuel / Refuelling Run',
        windowMinutes: 45,
        confidenceLabel: 'High — Trade/Fuel Receipt',
        promptText: 'You scanned a \$55.00 receipt at Shell Servo at 12:30 — was there an unlogged drive there?',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AtoAuditShieldSheet(
              slaReport: const ContemporaneousScoreReport(
                totalEvaluatedTrips: 10,
                confirmedWithin7DaysCount: 9,
                pendingWithin7DaysCount: 1,
                breachedCount: 0,
                integrityScorePercent: 90.0,
                tripStatuses: [],
              ),
              calibrationResult: const OdometerCalibrationResult(
                vehicleId: 'veh_1',
                calibrationFactor: 1.034,
                driftPercent: 3.3,
                requiresRecalibrationAlert: true,
                anchorCount: 2,
                totalPhysicalDeltaKm: 1034,
                totalGpsDeltaKm: 1000,
                advisoryMessage: 'Drift 3.3%',
              ),
              fuelPlausibility: const FuelPlausibilityResult(
                totalFuelLitres: 120,
                claimedKm: 1000,
                estimatedLitresPer100Km: 12.0,
                expectedMinLPer100Km: 7.5,
                expectedMaxLPer100Km: 16.5,
                isPlausible: true,
                hasSufficientData: true,
                statusLabel: 'Plausible (12.0 L/100km est.)',
                advisoryMessage: 'Within expected band.',
              ),
              ghostTrips: [ghost],
              watchdogReport: TrackingWatchdogService.evaluateHealth(
                now: DateTime(2026, 11, 25),
                platform: DevicePlatformKind.ios,
              ),
              onRecoverGhostTrip: (g) => recovered = g,
            ),
          ),
        ),
      );

      expect(find.text('ATO Audit Shield'), findsOneWidget);
      expect(find.text('90% Score'), findsOneWidget);
      expect(find.text('1.034x'), findsOneWidget);
      expect(find.text('1 Found'), findsOneWidget);

      await tester.ensureVisible(find.text('Recover Drive'));
      await tester.tap(find.text('Recover Drive'));
      await tester.pump();

      expect(recovered?.id, 'g1');
    });
  });

  group('AppState.buildAuditShieldSnapshot Wiring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'provides >=2 OdometerAnchors from initialOdometer + trip-derived reading so drift alerts fire',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);

      await appState.addVehicle(Vehicle(
        id: 'veh_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRD123',
        initialOdometer: 50000.0,
        taxMethod: TaxMethod.logbook,
        isPrimary: true,
      ));

      appState.recordTrip(Trip(
        id: 't1',
        vehicleId: 'veh_1',
        distanceKm: 500.0,
        date: DateTime(2026, 11, 1, 8, 0),
        stoppedAt: DateTime(2026, 11, 1, 14, 0),
        purpose: 'Client Site A',
        startOdometer: 50000.0,
        endOdometer: 50500.0,
      ));
      appState.recordTrip(Trip(
        id: 't2',
        vehicleId: 'veh_1',
        distanceKm: 500.0,
        date: DateTime(2026, 11, 10, 8, 0),
        stoppedAt: DateTime(2026, 11, 10, 14, 0),
        purpose: 'Client Site B',
        startOdometer: 50550.0,
        endOdometer: 51050.0,
      ));

      final snapshot = appState.buildAuditShieldSnapshot(
        now: DateTime(2026, 11, 12, 9, 0),
      );

      expect(snapshot.calibrationResult.anchorCount, greaterThanOrEqualTo(2));
      expect(snapshot.calibrationResult.totalPhysicalDeltaKm, closeTo(1050.0, 0.1));
      expect(snapshot.calibrationResult.totalGpsDeltaKm, closeTo(1000.0, 0.1));
      expect(snapshot.calibrationResult.calibrationFactor, closeTo(1.05, 0.001));
      expect(snapshot.calibrationResult.requiresRecalibrationAlert, isTrue);

      appState.dispose();
    });

    test(
        'passes real lastHeartbeatAt from liveDriveController / autonomous fixes and resolves platform via defaultTargetPlatform',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final appState = AppState(storageService: storage);
      await appState.init(storageService: storage);
      await appState.addVehicle(Vehicle(
        id: 'veh_1',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 10000.0,
        isPrimary: true,
      ));

      final streamController = StreamController<Position>.broadcast();
      final fixTime = DateTime(2026, 11, 20, 10, 0);
      await appState.startOrResumeLiveTracking(
        positionStreamFactory: (_) => streamController.stream,
      );
      streamController.add(Position(
        longitude: 144.9631,
        latitude: -37.8136,
        timestamp: fixTime,
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 10.0,
        speedAccuracy: 0.5,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final freshSnapshot = appState.buildAuditShieldSnapshot(
          now: fixTime.add(const Duration(hours: 2)),
        );
        expect(freshSnapshot.watchdogReport.hoursSinceLastActivity, closeTo(2.0, 0.1));
        expect(freshSnapshot.watchdogReport.isStaleGap, isFalse);
        expect(freshSnapshot.watchdogReport.oemGuidanceTitle,
            contains('iOS'));

        final staleSnapshot = appState.buildAuditShieldSnapshot(
          now: fixTime.add(const Duration(hours: 60)),
        );
        expect(staleSnapshot.watchdogReport.hoursSinceLastActivity, closeTo(60.0, 0.1));
        expect(staleSnapshot.watchdogReport.isStaleGap, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(
        appState.resolveWatchdogPlatform(
          targetPlatformOverride: TargetPlatform.android,
          osInfoOverride: 'Linux 5.10.136-android12-samsung-g998b',
        ),
        DevicePlatformKind.androidSamsung,
      );
      expect(
        appState.resolveWatchdogPlatform(
          targetPlatformOverride: TargetPlatform.android,
          osInfoOverride: 'Linux 5.15-xiaomi-miui',
        ),
        DevicePlatformKind.androidXiaomi,
      );
      expect(
        appState.resolveWatchdogPlatform(
          targetPlatformOverride: TargetPlatform.android,
          osInfoOverride: 'Linux 5.15-oppo-coloros',
        ),
        DevicePlatformKind.androidOppo,
      );
      expect(
        appState.resolveWatchdogPlatform(
          targetPlatformOverride: TargetPlatform.iOS,
        ),
        DevicePlatformKind.ios,
      );

      await streamController.close();
      appState.dispose();
    });
  });
}
