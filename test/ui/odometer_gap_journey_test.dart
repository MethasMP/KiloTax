import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/logbook/logbook_progress_screen.dart';

AppState gapState() {
  final s = AppState()
    ..addVehicle(Vehicle(
        id: 'ute',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TEST',
        initialOdometer: 1000,
        taxMethod: TaxMethod.logbook));
  for (final item in [(1000.0, 1020.0), (1050.0, 1070.0)]) {
    s.recordTrip(Trip(
        id: '${item.$1}',
        vehicleId: 'ute',
        distanceKm: 20,
        date: DateTime.now(),
        purpose: 'Client Site',
        startOdometer: item.$1,
        endOdometer: item.$2,
        taxMethod: TaxMethod.logbook));
  }
  return s;
}

Future<void> open(WidgetTester tester, AppState s) async {
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: s, child: const MaterialApp(home: LogbookProgressScreen())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review missing travel').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'leaving the gap unresolved never manufactures or classifies travel',
      (tester) async {
    final s = gapState();
    await open(tester, s);
    await tester.tap(find.text('Leave unresolved for now'));
    await tester.pumpAndSettle();
    expect(s.trips.length, 2);
    expect(s.findFirstOdometerGap()!.distance, 30);
    expect(find.textContaining('of travel needs review'), findsOneWidget);
  });

  testWidgets(
      'review → add a partial confirmed trip → updated remaining gap on overview',
      (tester) async {
    final s = gapState();
    await open(tester, s);
    await tester.tap(find.text('Add missing trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.ensureVisible(find.text('Personal'));
    await tester.tap(find.text('Personal'));
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(find.text('Logbook overview'), findsOneWidget);
    expect(s.trips.length, 3);
    final added = s.trips.last;
    expect(added.startOdometer, 1020);
    expect(added.endOdometer, 1030);
    expect(added.evidenceSource, 'manual_gap_resolution');
    expect(added.classification, TripClassification.personal);
    expect(s.currentOdometer, 1070);
    expect(s.findFirstOdometerGap()!.distance, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale open form cannot duplicate travel recorded elsewhere',
      (tester) async {
    final s = gapState();
    await open(tester, s);
    await tester.tap(find.text('Add missing trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal'));
    await tester.tap(find.text('Personal'));
    s.recordTrip(Trip(
        id: 'external',
        vehicleId: 'ute',
        distanceKm: 30,
        date: DateTime.now(),
        purpose: 'Personal',
        startOdometer: 1020,
        endOdometer: 1050,
        classification: TripClassification.personal,
        taxMethod: TaxMethod.logbook));
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(s.trips.length, 3);
    expect(find.textContaining('must fit the current unrecorded span'),
        findsOneWidget);
  });

  testWidgets(
      'missing travel requires an actual date, even after selecting personal',
      (tester) async {
    final s = gapState();
    await open(tester, s);
    await tester.tap(find.text('Add missing trip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal'));
    await tester.tap(find.text('Personal'));
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(s.trips.length, 2);
    expect(find.textContaining('Choose the actual trip date.'), findsOneWidget);
  });

  testWidgets(
      'legacy inferred bridge is reviewed in place instead of duplicated',
      (tester) async {
    final s = gapState();
    s.recordTrip(Trip(
        id: 'legacy',
        vehicleId: 'ute',
        distanceKm: 30,
        date: DateTime.now(),
        purpose: 'Auto personal',
        startOdometer: 1020,
        endOdometer: 1050,
        classification: TripClassification.personal,
        evidenceSource: 'auto_reconciled_odometer_gap',
        taxMethod: TaxMethod.logbook,
        linkedExpenseIds: ['receipt']));
    await open(tester, s);
    await tester.tap(find.text('Review existing entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal'));
    await tester.tap(find.text('Personal'));
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(s.trips.length, 3);
    expect(s.pendingOdometerGaps, isEmpty);
    expect(s.trips.firstWhere((t) => t.id == 'legacy').evidenceSource,
        'user_confirmed_auto_gap');
    expect(s.trips.firstWhere((t) => t.id == 'legacy').linkedExpenseIds,
        ['receipt']);
  });
}
