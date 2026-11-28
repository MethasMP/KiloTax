import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/logbook_period.dart';
import 'package:kiloclaim/data/models/annual_odometer.dart';
import 'package:kiloclaim/services/notifications/notification_service.dart';
import 'package:kiloclaim/services/tax/ato_tax_period_engine.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  group('Item 1: 12-Week Representative Travel Check (ITAA 1997 s 28-G)', () {
    final start = DateTime(2026, 1, 1);
    final end = start.add(const Duration(days: 84));

    final period = LogbookPeriod(
      id: 'period_test_1',
      vehicleId: 'veh_hilux',
      startDate: start,
      endDate: end,
      startOdometer: 100000.0,
      establishedFinancialYear: '2025–26',
      validUntilFinancialYear: '2030–31',
    );

    test('Nominal regular travel pattern has NO substantiation gap warning', () {
      // Weekly trips: Day 1, Day 8, Day 15, Day 22, ..., Day 84
      final tripDates = <DateTime>[];
      for (int day = 0; day <= 84; day += 7) {
        tripDates.add(start.add(Duration(days: day, hours: 9)));
      }

      final hasWarning = period.hasSubstantiationGapWarning(tripDates);
      final maxGap = period.maxConsecutiveInactiveDays(tripDates);
      final evaluation = period.evaluateSubstantiationPattern(tripDates);

      expect(hasWarning, false);
      expect(maxGap, lessThanOrEqualTo(14));
      expect(evaluation.risk, LogbookPatternRisk.representative);
      expect(evaluation.warningMessage, isNull);
    });

    test('Inactive unlogged gap > 14 consecutive days between trips flags risk', () {
      // Trips on Day 5 and Day 21 -> Gap of 16 days (> 14 days)
      final tripDates = [
        start.add(const Duration(days: 5)),
        start.add(const Duration(days: 21)),
        start.add(const Duration(days: 28)),
      ];

      final evaluation = period.evaluateSubstantiationPattern(
        tripDates,
        asOfDate: start.add(const Duration(days: 35)),
      );

      expect(evaluation.hasWarning, true);
      expect(evaluation.maxConsecutiveInactiveDays, 16);
      expect(evaluation.risk, LogbookPatternRisk.substantiationGapWarning);
      expect(evaluation.warningMessage, contains('16 consecutive days'));
      expect(evaluation.warningMessage, contains('ITAA 1997 s 28-G'));
    });

    test('Unlogged gap > 14 consecutive days at start of period flags risk', () {
      // Period starts Day 0. First trip is not logged until Day 17 -> Gap of 17 days
      final tripDates = [
        start.add(const Duration(days: 17)),
        start.add(const Duration(days: 24)),
      ];

      final evaluation = period.evaluateSubstantiationPattern(
        tripDates,
        asOfDate: start.add(const Duration(days: 30)),
      );

      expect(evaluation.hasWarning, true);
      expect(evaluation.maxConsecutiveInactiveDays, 17);
      expect(evaluation.risk, LogbookPatternRisk.substantiationGapWarning);
    });

    test('Unlogged gap > 14 consecutive days at tail of completed period flags risk', () {
      // Last trip at Day 60 of 84-day period -> 24 days unlogged until Day 84
      final tripDates = [
        start.add(const Duration(days: 0)),
        start.add(const Duration(days: 10)),
        start.add(const Duration(days: 20)),
        start.add(const Duration(days: 35)),
        start.add(const Duration(days: 48)),
        start.add(const Duration(days: 60)),
      ];

      final evaluation = period.evaluateSubstantiationPattern(
        tripDates,
        asOfDate: end,
      );

      expect(evaluation.hasWarning, true);
      expect(evaluation.maxConsecutiveInactiveDays, 24);
      expect(evaluation.risk, LogbookPatternRisk.substantiationGapWarning);
    });

    test('In-progress logbook does NOT prematurely trigger warning early on', () {
      // Day 4 of logbook with trip on Day 1
      final tripDates = [
        start.add(const Duration(days: 1)),
      ];

      final evaluation = period.evaluateSubstantiationPattern(
        tripDates,
        asOfDate: start.add(const Duration(days: 4)),
      );

      expect(evaluation.hasWarning, false);
      expect(evaluation.maxConsecutiveInactiveDays, 3);
      expect(evaluation.risk, LogbookPatternRisk.representative);
    });

    test('AppState exposes automated substantiation gap warning for primary vehicle', () {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_substantiation',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TRADIE-GAP',
        taxMethod: TaxMethod.logbook,
        logbookStartDate: start,
      );
      appState.addVehicle(vehicle);

      // Add trips with a 18-day gap
      final trip1 = Trip(
        id: 't_gap_1',
        vehicleId: 'v_substantiation',
        startOdometer: 50000.0,
        endOdometer: 50030.0,
        distanceKm: 30.0,
        date: start.add(const Duration(days: 2)),
        purpose: 'Site visit',
        classification: TripClassification.business,
      );
      final trip2 = Trip(
        id: 't_gap_2',
        vehicleId: 'v_substantiation',
        startOdometer: 50030.0,
        endOdometer: 50060.0,
        distanceKm: 30.0,
        date: start.add(const Duration(days: 20)), // 18-day gap
        purpose: 'Supplier pickup',
        classification: TripClassification.business,
      );

      appState.recordTrip(trip1);
      appState.recordTrip(trip2);

      expect(appState.hasActiveLogbookSubstantiationGapWarning, true);
      expect(appState.activeLogbookGapEvaluation?.risk,
          LogbookPatternRisk.substantiationGapWarning);
    });
  });

  group('Item 2: Automated First/Last Odometer Snapshot Latch', () {
    test('startLogbookPeriod automatically latches starting odometer to first trip if trips exist', () {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_latch_start',
        make: 'Toyota',
        model: 'HiAce',
        regoPlate: 'HIACE-1',
        initialOdometer: 80000.0, // Initial estimate
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.addVehicle(vehicle);

      final logbookStart = DateTime(2026, 3, 1);

      // Trip recorded starting at 80450.0 km
      final trip = Trip(
        id: 't_first_existing',
        vehicleId: 'v_latch_start',
        startOdometer: 80450.0,
        endOdometer: 80480.0,
        distanceKm: 30.0,
        date: logbookStart.add(const Duration(hours: 8)),
        purpose: 'Client callout',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      // Start logbook period without guessing starting odometer
      appState.startLogbookPeriod(startDate: logbookStart);

      expect(appState.primaryVehicle?.initialOdometer, 80450.0);
      expect(appState.activeLogbookPeriod?.startOdometer, 80450.0);
    });

    test('recordTrip automatically latches vehicle initialOdometer to first trip in logbook period', () {
      final appState = AppState();
      final logbookStart = DateTime(2026, 4, 1);
      final vehicle = Vehicle(
        id: 'v_first_trip_latch',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'DMAX-99',
        initialOdometer: 0.0, // Unset or blank
        taxMethod: TaxMethod.logbook,
        logbookStartDate: logbookStart,
      );
      appState.addVehicle(vehicle);
      appState.startLogbookPeriod(startDate: logbookStart);

      // Record first trip with startOdometer = 92100.0
      final trip = Trip(
        id: 't_first_record',
        vehicleId: 'v_first_trip_latch',
        startOdometer: 92100.0,
        endOdometer: 92145.0,
        distanceKm: 45.0,
        date: logbookStart.add(const Duration(days: 1)),
        purpose: 'Work commute with bulky tools',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      // Starting odometer automatically latched to first trip's startOdometer!
      expect(appState.primaryVehicle?.initialOdometer, 92100.0);
      expect(appState.activeLogbookPeriod?.startOdometer, 92100.0);
    });

    test('completeLogbookPeriod automatically latches closing odometer to final trip endOdometer', () {
      final appState = AppState();
      final logbookStart = DateTime(2026, 1, 1);
      final vehicle = Vehicle(
        id: 'v_complete_latch',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'HILUX-01',
        initialOdometer: 50000.0,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: logbookStart,
      );
      appState.addVehicle(vehicle);

      // Trip 1 (First trip): 50100.0 -> 50150.0
      final trip1 = Trip(
        id: 't_comp_1',
        vehicleId: 'v_complete_latch',
        startOdometer: 50100.0,
        endOdometer: 50150.0,
        distanceKm: 50.0,
        date: logbookStart.add(const Duration(days: 1)),
        purpose: 'Job Site 1',
        classification: TripClassification.business,
      );

      // Trip 2 (Final trip at end of 12 weeks, continuous chain): 50150.0 -> 54280.0
      final trip2 = Trip(
        id: 't_comp_2',
        vehicleId: 'v_complete_latch',
        startOdometer: 50150.0,
        endOdometer: 54280.0,
        distanceKm: 4130.0,
        date: logbookStart.add(const Duration(days: 83)),
        purpose: 'Bunnings run & return',
        classification: TripClassification.business,
      );

      appState.recordTrip(trip1);
      appState.recordTrip(trip2);

      // Complete 12-week logbook
      final completed = appState.completeLogbookPeriod(
        completionDate: logbookStart.add(const Duration(days: 84)),
      );

      expect(completed, isNotNull);
      // Start odometer latches to first trip's startOdometer
      expect(completed!.startOdometer, 50100.0);
      // Closing odometer automatically latches to final trip's endOdometer!
      expect(completed.endOdometer, 54280.0);
      expect(completed.status, LogbookStatus.completedPendingReview);
      expect(completed.certifiedBusinessPercentage, 100.0); // Both trips business

      // Also verifies AnnualVehicleOdometer was latched with closing odometer
      final periodEngine = const AtoTaxPeriodEngine();
      final fy = periodEngine.forDate(logbookStart.add(const Duration(days: 84)));
      final annual = appState.getAnnualOdometer('v_complete_latch', fy.shortLabel);
      expect(annual?.closingOdometer, 54280.0);
      expect(annual?.openingOdometer, 50100.0);
    });
  });

  group('Item 3: Automated EOFY (30 June) Notification & Snapshot Pipeline', () {
    late NotificationService notificationService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      notificationService = NotificationService.withPrefs(null);
    });

    test('EofyAlertMilestone identifies June 15, June 28, and June 30 accurately', () {
      expect(EofyAlertMilestone.forDate(DateTime(2026, 6, 15)), EofyAlertMilestone.june15);
      expect(EofyAlertMilestone.forDate(DateTime(2026, 6, 28)), EofyAlertMilestone.june28);
      expect(EofyAlertMilestone.forDate(DateTime(2026, 6, 30)), EofyAlertMilestone.june30);

      // Non-milestone dates return null
      expect(EofyAlertMilestone.forDate(DateTime(2026, 6, 1)), isNull);
      expect(EofyAlertMilestone.forDate(DateTime(2026, 6, 29)), isNull);
      expect(EofyAlertMilestone.forDate(DateTime(2026, 7, 1)), isNull);
    });

    test('notifyEofyOdometerReminder produces compliant alerts and enforces idempotency', () async {
      final vehicle = Vehicle(
        id: 'v_notif_test',
        make: 'Ford',
        model: 'Transit',
        regoPlate: 'TRANSIT-1',
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 8, 1),
      );

      final notif1 = await notificationService.notifyEofyOdometerReminder(
        vehicle: vehicle,
        financialYearLabel: '2025–26',
        milestone: EofyAlertMilestone.june15,
        timestamp: DateTime(2026, 6, 15, 9, 0),
      );

      expect(notif1, isNotNull);
      expect(notif1!.type, KiloClaimNotificationType.eofyAlert);
      expect(notif1.title, contains('15 Days Left'));
      expect(notif1.body, contains('Transit (TRANSIT-1)'));

      // Idempotency: calling again for same vehicle & milestone in same FY returns null (no duplicate)
      final duplicate = await notificationService.notifyEofyOdometerReminder(
        vehicle: vehicle,
        financialYearLabel: '2025–26',
        milestone: EofyAlertMilestone.june15,
        timestamp: DateTime(2026, 6, 15, 14, 0),
      );
      expect(duplicate, isNull);
      expect(notificationService.notifications.length, 1);
    });

    test('evaluateEofyAlertPipeline schedules alerts on June 15, 28, and 30 for eligible vehicles', () async {
      final activeLogbookVehicle = Vehicle(
        id: 'v_active_logbook',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'HILUX-EOFY',
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2024, 9, 1), // Year 2 of logbook (within 1-5 years)
      );

      final cpkVehicle = Vehicle(
        id: 'v_cpk',
        make: 'Mazda',
        model: 'BT-50',
        regoPlate: 'BT50-CPK',
        taxMethod: TaxMethod.centsPerKm, // Should NOT trigger
        logbookStartDate: DateTime(2024, 9, 1),
      );

      final expiredLogbookVehicle = Vehicle(
        id: 'v_expired',
        make: 'Holden',
        model: 'Rodeo',
        regoPlate: 'RODEO-OLD',
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2019, 1, 1), // Expired > 5 years -> needs new logbook
      );

      final vehicles = [activeLogbookVehicle, cpkVehicle, expiredLogbookVehicle];

      // Test June 15:
      final alertsJune15 = await notificationService.evaluateEofyAlertPipeline(
        vehicles: vehicles,
        isMissingClosingOdometer: (vId, fy) => true, // Closing odometer missing
        currentDate: DateTime(2026, 6, 15),
      );
      expect(alertsJune15.length, 1);
      expect(alertsJune15.first.data?['vehicleId'], 'v_active_logbook');
      expect(alertsJune15.first.title, contains('15 Days Left'));

      // Test June 28:
      final alertsJune28 = await notificationService.evaluateEofyAlertPipeline(
        vehicles: vehicles,
        isMissingClosingOdometer: (vId, fy) => true,
        currentDate: DateTime(2026, 6, 28),
      );
      expect(alertsJune28.length, 1);
      expect(alertsJune28.first.title, contains('2 Days'));

      // Test June 30:
      final alertsJune30 = await notificationService.evaluateEofyAlertPipeline(
        vehicles: vehicles,
        isMissingClosingOdometer: (vId, fy) => true,
        currentDate: DateTime(2026, 6, 30),
      );
      expect(alertsJune30.length, 1);
      expect(alertsJune30.first.title, contains('Final Day'));

      // If closing odometer is already recorded, pipeline generates 0 alerts
      await notificationService.clearAll();
      final alertsWhenRecorded = await notificationService.evaluateEofyAlertPipeline(
        vehicles: vehicles,
        isMissingClosingOdometer: (vId, fy) => false, // Already recorded!
        currentDate: DateTime(2026, 6, 30),
      );
      expect(alertsWhenRecorded, isEmpty);
    });

    test('AppState.checkEofyReminders integrates with NotificationService seamlessly', () async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_appstate_eofy',
        make: 'Mitsubishi',
        model: 'Triton',
        regoPlate: 'TRITON-1',
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 8, 1),
      );
      appState.addVehicle(vehicle);

      final generatedAlerts = await appState.checkEofyReminders(
        date: DateTime(2026, 6, 30),
        customNotificationService: notificationService,
      );

      expect(generatedAlerts.length, 1);
      expect(generatedAlerts.first.title, contains('Final Day'));

      // Now record closing odometer
      final fyEngine = const AtoTaxPeriodEngine();
      final fy = fyEngine.forDate(DateTime(2026, 6, 30));
      appState.recordAnnualOdometer(AnnualVehicleOdometer(
        id: 'annual_${vehicle.id}_${fy.shortLabel}',
        vehicleId: vehicle.id,
        financialYear: fy.shortLabel,
        openingDate: DateTime(2025, 7, 1),
        openingOdometer: 100000.0,
        closingDate: DateTime(2026, 6, 30),
        closingOdometer: 125000.0,
      ));

      // After closing odometer is recorded, no further alerts are generated
      await notificationService.clearAll();
      final alertsAfterRecord = await appState.checkEofyReminders(
        date: DateTime(2026, 6, 30),
        customNotificationService: notificationService,
      );
      expect(alertsAfterRecord, isEmpty);
    });
  });
}
