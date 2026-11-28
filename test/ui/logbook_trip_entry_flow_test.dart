import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_trip_entry_screen.dart';

Future<void> openEntry(WidgetTester tester, AppState state,
    {Trip? trip}) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => LogbookTripEntryScreen(
                              appState: state, detectedTrip: trip))),
                  child: const Text('Open entry'))))));
  await tester.tap(find.text('Open entry'));
  await tester.pumpAndSettle();
}

AppState createState() => AppState()
  ..addVehicle(Vehicle(
      id: 'logbook',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'TEST',
      initialOdometer: 1000,
      taxMethod: TaxMethod.logbook));

Future<void> choosePersonal(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Personal'));
  await tester.tap(find.text('Personal'));
  await tester.pump();
}

void main() {
  testWidgets('manual past trip saves selected date and truthful method/source',
      (tester) async {
    final state = createState();
    await openEntry(tester, state);
    await tester.enterText(find.byType(TextField).first, '12.5');
    await tester.tap(find.byKey(const ValueKey('trip-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final date = DateTime.now().subtract(const Duration(days: 2));
    final input = find.descendant(
        of: find.byType(DatePickerDialog), matching: find.byType(TextField));
    await tester.enterText(input, '${date.month}/${date.day}/${date.year}');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await choosePersonal(tester);
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    final saved = state.trips.single;
    expect(saved.date.year, date.year);
    expect(saved.date.month, date.month);
    expect(saved.date.day, date.day);
    expect(saved.taxMethod, TaxMethod.logbook);
    expect(saved.evidenceSource, 'manual_retroactive');
    expect(saved.classification, TripClassification.personal);
    expect(saved.distanceKm, 12.5);
    expect(find.text('Open entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review keeps original vehicle, source, job and receipt links',
      (tester) async {
    final state = createState();
    final original = Trip(
        id: 'detected',
        vehicleId: 'logbook',
        distanceKm: 10,
        date: DateTime.now(),
        purpose: 'Personal',
        classification: TripClassification.personal,
        startOdometer: 1000,
        endOdometer: 1010,
        taxMethod: TaxMethod.logbook,
        evidenceSource: 'bluetooth_auto',
        jobReference: 'JOB-42',
        linkedExpenseIds: ['receipt-1'],
        clientDedupId: 'dedup-1');
    state.recordTrip(original);
    await openEntry(tester, state, trip: original);
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    final saved = state.trips.single;
    expect(saved.id, original.id);
    expect(saved.vehicleId, original.vehicleId);
    expect(saved.taxMethod, original.taxMethod);
    expect(saved.evidenceSource, original.evidenceSource);
    expect(saved.linkedExpenseIds, original.linkedExpenseIds);
    expect(saved.jobReference, original.jobReference);
    expect(saved.clientDedupId, original.clientDedupId);
    expect(saved.classification, TripClassification.personal);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'manual trip cannot be silently saved as business without a choice',
      (tester) async {
    final state = createState();
    await openEntry(tester, state);
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(state.trips, isEmpty);
    expect(find.text('Choose a trip purpose before saving.'), findsOneWidget);
  });
  testWidgets(
      'commute warning allows review and only changes classification with confirmation',
      (tester) async {
    final state = createState();
    await openEntry(tester, state);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), 'Home');
    await tester.enterText(fields.at(2), 'Client site');
    await tester.ensureVisible(find.text('Client Site'));
    await tester.tap(find.text('Client Site'));
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    expect(state.trips, isEmpty);
    expect(find.text('Review travel type'), findsOneWidget);
    await tester.tap(find.text('Review details'));
    await tester.pumpAndSettle();
    expect(state.trips, isEmpty);
    await tester.tap(find.text('Save trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as personal'));
    await tester.pumpAndSettle();
    expect(state.trips.single.classification, TripClassification.personal);
    expect(state.trips.single.purpose, 'Personal');
  });
}
