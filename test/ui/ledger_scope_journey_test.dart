import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/tax/ato_tax_period_engine.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_trip_entry_screen.dart';

void main() {
  Future<AppState> stateWithVehicles(TaxMethod method) async {
    final state = AppState();
    await state.addVehicle(
        Vehicle(id: 'a', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    await state.addVehicle(Vehicle(
        id: 'b',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 200,
        taxMethod: method));
    state.selectVehicle('a');
    return state;
  }

  for (final method in TaxMethod.values) {
    testWidgets('historical ${method.name} capture keeps ledger vehicle local',
        (tester) async {
      final state = await stateWithVehicles(method);
      final year = AtoTaxPeriodEngine().forDate(DateTime.now()).startYear - 1;
      await tester.pumpWidget(MaterialApp(
          home: TripsLedgerTab(
              appState: state,
              initialVehicleId: 'b',
              financialYear: '$year-${(year + 1).toString().substring(2)}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add trip'));
      await tester.pumpAndSettle();
      expect(state.primaryVehicle?.id, 'a');
      if (method == TaxMethod.logbook) {
        final editor = tester.widget<LogbookTripEntryScreen>(
            find.byType(LogbookTripEntryScreen));
        expect(editor.vehicleId, 'b');
        expect(editor.initialDate, AtoFinancialYear(year).startDate);
        expect(editor.requireDateConfirmation, isTrue);
      } else {
        final editor =
            tester.widget<CpkTripEntryScreen>(find.byType(CpkTripEntryScreen));
        expect(editor.vehicleId, 'b');
        expect(editor.initialDate, AtoFinancialYear(year).startDate);
        expect(editor.requireDateConfirmation, isTrue);
      }
    });
  }

  testWidgets('ledger evidence tools retain historical year and vehicle',
      (tester) async {
    final state = await stateWithVehicles(TaxMethod.centsPerKm);
    await tester.pumpWidget(MaterialApp(
        home: TripsLedgerTab(
            appState: state, initialVehicleId: 'b', financialYear: '2023-24')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trip tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review evidence'));
    await tester.pumpAndSettle();
    final review =
        tester.widget<EvidenceReviewScreen>(find.byType(EvidenceReviewScreen));
    expect(review.vehicleId, 'b');
    expect(review.financialYear, '2023-24');
    expect(state.primaryVehicle?.id, 'a');
  });
}
