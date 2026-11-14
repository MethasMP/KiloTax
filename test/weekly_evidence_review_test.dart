import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/ui/screens/notifications/notifications_sheet.dart';
import 'package:kilotax/ui/screens/notifications/notifications_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/engine/evidence_review_service.dart';
import 'package:kilotax/services/notifications/notification_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/evidence/evidence_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vehicle = Vehicle(
      id: 'weekly',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'TEST',
      initialOdometer: 100);
  Trip trip(String id, DateTime date) => Trip(
      id: id,
      vehicleId: vehicle.id,
      date: date,
      purpose: '',
      distanceKm: 10,
      classification: TripClassification.unclassified);
  EvidenceReviewReport report(List<Trip> trips) =>
      const EvidenceReviewService().evaluate(
          vehicle: vehicle,
          financialYear: '2026-27',
          trips: trips,
          expenses: []);

  test('week starts Monday and excludes next Monday and older pending items',
      () {
    final r = report([
      trip('sunday', DateTime(2026, 11, 1, 23, 59)),
      trip('monday', DateTime(2026, 11, 2)),
      trip('last', DateTime(2026, 11, 8, 23, 59)),
      trip('next', DateTime(2026, 11, 9)),
    ]);
    expect(
        r
            .itemsForWeek(DateTime(2026, 11, 7))
            .whereType<TripReviewItem>()
            .map((i) => i.tripId)
            .toSet(),
        {'monday', 'last'});
    expect(r.items.length, 4);
  });

  test(
      'weekly reminder persists deduplication, does not remind for resolved or current-week-only records',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = NotificationService.withPrefs(prefs);
    final r = report([trip('old', DateTime(2026, 11, 7))]);
    final notice = await service.notifyWeeklyEvidenceReview(
        report: r, now: DateTime(2026, 11, 9));
    expect(notice!.deepLinkRoute, '/evidence-review');
    expect(notice.data!['vehicleId'], 'weekly');
    expect(notice.body, contains('1 record'));
    final reloaded = NotificationService.withPrefs(prefs);
    expect(
        await reloaded.notifyWeeklyEvidenceReview(
            report: r, now: DateTime(2026, 11, 10)),
        isNull);
    expect(reloaded.notifications.length, 1);
    expect(
        await reloaded.notifyWeeklyEvidenceReview(
            report: report([trip('new', DateTime(2026, 11, 16))]),
            now: DateTime(2026, 11, 16)),
        isNull);
    expect(
        await reloaded.notifyWeeklyEvidenceReview(
            report: report([]), now: DateTime(2026, 11, 16)),
        isNull);
    expect(
        await reloaded.notifyWeeklyEvidenceReview(
            report: r, now: DateTime(2026, 11, 16)),
        isNotNull);
    expect(reloaded.notifications.length, 2);
  });

  testWidgets('weekly filter keeps older pending records accessible',
      (tester) async {
    final state = AppState();
    await state.addVehicle(vehicle);
    final now = DateTime.now();
    state.recordTrip(trip('today', now));
    state.recordTrip(trip('older', now.subtract(const Duration(days: 10))));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: state,
            vehicleId: vehicle.id,
            financialYear: state.activeTaxRule.financialYear)));
    await tester.pumpAndSettle();
    expect(find.text('2 items need attention'), findsOneWidget);
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.text('1 item needs attention'), findsOneWidget);
    await tester.tap(find.text('All pending'));
    await tester.pumpAndSettle();
    expect(find.text('2 items need attention'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  for (final dropdown in [false, true]) {
    testWidgets(
        'weekly notification opens its vehicle review and marks itself read (dropdown: $dropdown)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifications = NotificationService.withPrefs(prefs);
      final state = AppState();
      await state.addVehicle(vehicle);
      final old = trip(
          'reminder-trip', DateTime.now().subtract(const Duration(days: 10)));
      state.recordTrip(old);
      final notice = await notifications.notifyWeeklyEvidenceReview(
          report: const EvidenceReviewService().evaluate(
              vehicle: vehicle,
              financialYear: state.activeTaxRule.financialYear,
              trips: [old],
              expenses: []),
          now: DateTime.now());
      expect(notice, isNotNull);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => dropdown
                              ? NotificationsDropdown.show(context,
                                  notificationService: notifications)
                              : NotificationsSheet.show(context,
                                  notificationService: notifications),
                          child: const Text('Open notices')))))));
      await tester.tap(find.text('Open notices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly evidence review'));
      await tester.pumpAndSettle();
      expect(find.text('Review evidence'), findsOneWidget);
      expect(find.text('1 item needs attention'), findsOneWidget);
      expect(notifications.notifications.single.isRead, true);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
