import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/ui/screens/home/widgets/trips_ledger_tab.dart';
import '../support/main_menu_fixtures.dart' as fixtures;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('review deep link shows reasons and keeps completed trips hidden',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: TripsLedgerTab(appState: state, initialFilter: 'Needs review'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose business or personal'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Smith renovation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filter returns to all instead of suggesting a new trip',
      (tester) async {
    final state = await fixtures.seed(TaxMethod.logbook, empty: true);
    addTearDown(state.dispose);
    state.recordTrip(Trip(
      id: 'done',
      vehicleId: 'audit',
      date: DateTime.now(),
      distanceKm: 4,
      purpose: 'Pick up materials for Wilson renovation',
      classification: TripClassification.business,
      destinationAddress: 'Wilson renovation',
    ));
    await tester.pumpWidget(MaterialApp(
      home: TripsLedgerTab(appState: state, initialFilter: 'Needs review'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No trips in this filter'), findsOneWidget);
    expect(find.text('Add a trip'), findsNothing);
    await tester.tap(find.text('Show all trips'));
    await tester.pumpAndSettle();
    expect(find.text('Wilson renovation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'explicit vehicle and financial year scope the deep linked ledger',
      (tester) async {
    final state = await fixtures.seed(TaxMethod.logbook);
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
      id: 'second',
      make: 'Toyota',
      model: 'Corolla',
      regoPlate: 'SECOND',
      initialOdometer: 100,
      taxMethod: TaxMethod.logbook,
    ));
    state.selectVehicle('audit');
    state.recordTrip(Trip(
      id: 'archived',
      vehicleId: 'second',
      date: DateTime(2021, 8, 2),
      distanceKm: 5,
      purpose: 'Inspect Wilson renovation',
      classification: TripClassification.business,
      destinationAddress: 'Archived site',
    ));
    await tester.pumpWidget(MaterialApp(
      home: TripsLedgerTab(
          appState: state,
          initialVehicleId: 'second',
          financialYear: '2021-22'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('FY 2021-22'), findsOneWidget);
    expect(find.text('Archived site'), findsOneWidget);
    expect(find.text('Smith renovation'), findsNothing);
    expect(state.primaryVehicle?.id, 'audit');
    expect(tester.takeException(), isNull);
  });
}
