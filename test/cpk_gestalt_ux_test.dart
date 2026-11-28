import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/cpk/cpk_home_body.dart';
import 'package:kiloclaim/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';

void main() {
  late AppState state;
  setUp(() async {
    state = AppState();
    await state.addVehicle(Vehicle(
        id: 'car',
        make: 'Ford',
        model: 'Ranger',
        taxMethod: TaxMethod.centsPerKm));
  });
  tearDown(() => state.dispose());
  Widget wrap(Widget child) => ChangeNotifierProvider<AppState>.value(
      value: state, child: MaterialApp(home: child));

  testWidgets(
      'Home leads with review work and recent records rather than a claim gauge',
      (t) async {
    state.recordTrip(Trip(
        id: 'review-me',
        vehicleId: 'car',
        date: DateTime.now(),
        distanceKm: 18,
        purpose: '',
        originAddress: 'Workshop',
        destinationAddress: 'Client site',
        classification: TripClassification.unclassified));
    await t.pumpWidget(wrap(Scaffold(body: CpkHomeBody(appState: state))));
    await t.pumpAndSettle();
    expect(find.text('Review 1 trip'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Recent trips'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.byType(CpkQuotaArcMeter), findsNothing);
    expect(t.getTopLeft(find.text('Review 1 trip')).dy,
        lessThan(t.getTopLeft(find.text('Recent trips')).dy));
  });

  testWidgets('Cents-per-km Home has a reachable labelled trip action',
      (t) async {
    await t.pumpWidget(wrap(const MainScaffoldScreen()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
        find.text('Add your first trip').hitTestable(), 150,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Add your first trip').hitTestable());
    await t.pumpAndSettle();
    expect(find.text('Record with GPS'), findsOneWidget);
    expect(find.text('Add a past trip'), findsOneWidget);
    await t.tap(find.text('Add a past trip'));
    await t.pumpAndSettle();
    expect(find.byType(CpkTripEntryScreen), findsOneWidget);
  });

  testWidgets('Method comparison is disclosed on request', (t) async {
    state.recordTrip(Trip(
        id: 'trip',
        vehicleId: 'car',
        date: DateTime.now(),
        distanceKm: 40,
        purpose: 'Site visit',
        originAddress: 'Workshop',
        destinationAddress: 'Client site',
        classification: TripClassification.business));
    await t.pumpWidget(wrap(const TaxSummaryScreen()));
    await t.pumpAndSettle();
    expect(find.text('Cents / km estimate'), findsNothing);
    await t.scrollUntilVisible(
        find.text('Compare method estimates').hitTestable(), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Compare method estimates'));
    await t.pumpAndSettle();
    expect(find.text('Cents / km estimate'), findsOneWidget);
    expect(
        find.textContaining(
            'A different method may require additional evidence.'),
        findsOneWidget);
    expect(find.text('LOGBOOK ADVANTAGE DETECTED'), findsNothing);
  });

  testWidgets(
      'Saving a trip confirms the record and preserves the selected date',
      (t) async {
    await t.pumpWidget(wrap(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => CpkTripEntryScreen(appState: state))),
                child: const Text('Open trip'))))));
    await t.tap(find.text('Open trip'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(0), '40');
    await t.enterText(find.byType(TextField).at(1), 'Workshop');
    await t.enterText(find.byType(TextField).at(2), 'Client site');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.tap(find.byIcon(Icons.calendar_today_outlined));
    await t.pumpAndSettle();
    await t.tap(find.text('1').last);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save trip'));
    await t.pumpAndSettle();
    expect(state.trips, hasLength(1));
    expect(state.trips.single.date.day, 1);
    expect(state.trips.single.distanceKm, 40);
    expect(state.trips.single.destinationAddress, 'Client site');
    expect(find.textContaining('Work trip saved'), findsOneWidget);
  });

  testWidgets('Blank route fields never become fabricated location records',
      (t) async {
    await t.pumpWidget(wrap(CpkTripEntryScreen(appState: state)));
    await t.enterText(find.byType(TextField).first, '10');
    await t.tap(find.text('Save trip'));
    await t.pump();
    expect(state.trips, isEmpty);
    expect(
        find.text('Add the starting and destination locations before saving.'),
        findsOneWidget);
  });
  testWidgets(
      'Tax uses the domain estimate without adding direct expenses twice',
      (t) async {
    state.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
    state.recordTrip(Trip(
        id: 'work-trip',
        vehicleId: 'car',
        date: DateTime.now(),
        distanceKm: 10,
        purpose: 'Site visit',
        originAddress: 'Workshop',
        destinationAddress: 'Client site',
        classification: TripClassification.business));
    state.recordExpense(VehicleExpense(
        id: 'parking',
        vehicleId: 'car',
        date: DateTime.now(),
        amount: 20,
        category: ExpenseCategory.tollsParking));
    final estimate = state.taxSummary.logbookClaim;
    expect(state.taxSummary.totalDirectDeductions, 20);
    await t.pumpWidget(wrap(const TaxSummaryScreen()));
    await t.pumpAndSettle();
    expect(find.text(Formatters.currency(estimate)), findsOneWidget);
    expect(find.text(Formatters.currency(estimate + 20)), findsNothing);
  });
  testWidgets('Annual cap remains visible in Tax without a Home goal gauge',
      (t) async {
    state.recordTrip(Trip(
        id: 'capped-trip',
        vehicleId: 'car',
        date: DateTime.now(),
        distanceKm: 5001,
        purpose: 'Site visits',
        originAddress: 'Workshop',
        destinationAddress: 'Client sites',
        classification: TripClassification.business));
    await t.pumpWidget(wrap(const TaxSummaryScreen()));
    await t.pumpAndSettle();
    expect(find.text('Kilometre limit reached for this estimate.'),
        findsOneWidget);
    expect(find.text(Formatters.currency(state.taxSummary.centsPerKmClaim)),
        findsOneWidget);
  });
}
