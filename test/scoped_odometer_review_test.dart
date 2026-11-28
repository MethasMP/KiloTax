import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/ui/screens/evidence/scoped_odometer_review_screen.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_trip_entry_screen.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  testWidgets('scoped odometer form and gap keep active vehicle unchanged',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'active', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    await state.addVehicle(Vehicle(
        id: 'pack',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 0,
        taxMethod: TaxMethod.logbook));
    state.selectVehicle('active');
    state.recordTrip(Trip(
        id: 'later',
        vehicleId: 'pack',
        date: DateTime.now(),
        purpose: 'Visit Smith renovation',
        startOdometer: 500,
        endOdometer: 510,
        distanceKm: 10));
    await tester.pumpWidget(MaterialApp(
        home: ScopedOdometerReviewScreen(
            appState: state,
            vehicleId: 'pack',
            financialYear: state.activeTaxRule.financialYear)));
    await tester.enterText(find.byType(TextField), '490');
    await tester.tap(find.text('Save starting odometer'));
    await tester.pumpAndSettle();
    expect(state.primaryVehicle?.id, 'active');
    expect(state.primaryVehicle?.initialOdometer, 100);
    expect(
        state.vehicles.singleWhere((v) => v.id == 'pack').initialOdometer, 490);
    await tester.tap(find.text('490 → 500 km'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add missing trip'));
    await tester.tap(find.text('Add missing trip'));
    await tester.pumpAndSettle();
    expect(find.byType(LogbookTripEntryScreen), findsOneWidget);
    expect(
        tester
            .widget<LogbookTripEntryScreen>(find.byType(LogbookTripEntryScreen))
            .vehicleId,
        'pack');
    expect(state.primaryVehicle?.id, 'active');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('scoped opening odometer updates only its vehicle', () async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'active', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    await state.addVehicle(
        Vehicle(id: 'pack', make: 'Ford', model: 'Ranger', initialOdometer: 0));
    state.selectVehicle('active');
    state.recordTrip(Trip(
        id: 'pack-trip',
        vehicleId: 'pack',
        date: DateTime(2026, 8, 1),
        purpose: 'Deliver timber to Smith St',
        startOdometer: 500,
        endOdometer: 510,
        distanceKm: 10));
    expect(state.updateStartingOdometer(490, vehicleId: 'pack'), true);
    expect(state.primaryVehicle?.id, 'active');
    expect(state.primaryVehicle?.initialOdometer, 100);
    expect(
        state.vehicles.singleWhere((v) => v.id == 'pack').initialOdometer, 490);
    expect(state.updateStartingOdometer(501, vehicleId: 'pack'), false);
    expect(state.updateStartingOdometer(200, vehicleId: 'missing'), false);
    expect(state.updateStartingOdometer(double.nan, vehicleId: 'pack'), false);
  });
}
