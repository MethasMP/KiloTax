import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';

void main() {
  testWidgets(
      'Home requests all pending and Trips without retaining unrelated subtab',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'a',
        make: 'Toyota',
        model: 'HiLux',
        taxMethod: TaxMethod.logbook,
        initialOdometer: 100));
    state.recordTrip(Trip(
        id: 't',
        vehicleId: 'a',
        date: DateTime.now(),
        purpose: 'Business',
        distanceKm: 10));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state, child: const MaterialApp(home: MainScaffoldScreen())));
    await tester.pumpAndSettle();
    final nav = find.byType(ScaffoldBottomNavBar);
    Future<void> tab(String name) async {
      await tester.tap(find.descendant(of: nav, matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    await tab('Review');
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    await tab('Home');
    await tester.tap(find.text('Review records'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All pending'))
            .selected,
        true);
    await tab('Records');
    await tester.tap(find.widgetWithText(Tab, 'Expenses'));
    await tester.pumpAndSettle();
    await tab('Home');
    await tab('Records');
    expect(
        DefaultTabController.of(
                tester.element(find.widgetWithText(Tab, 'Expenses')))
            .index,
        1);
    await tab('Home');
    await tester.scrollUntilVisible(find.text('View records'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View records'));
    await tester.pumpAndSettle();
    expect(
        DefaultTabController.of(
                tester.element(find.widgetWithText(Tab, 'Trips')))
            .index,
        0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final method in [TaxMethod.centsPerKm, TaxMethod.logbook]) {
    testWidgets(
        'historical ${method.name} capture asks for actual date in selected year',
        (tester) async {
      final state = AppState();
      addTearDown(state.dispose);
      await state.addVehicle(Vehicle(
          id: 'a', make: 'Toyota', model: 'HiLux', initialOdometer: 100));
      await state.addVehicle(Vehicle(
          id: 'b',
          make: 'Ford',
          model: 'Ranger',
          taxMethod: method,
          initialOdometer: 100));
      state.selectVehicle('a');
      await tester.pumpWidget(MaterialApp(
          home: EvidenceReviewScreen(
              appState: state, vehicleId: 'b', financialYear: '2025-26')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No records in this financial year'));
      await tester.pumpAndSettle();
      expect(find.text('Choose actual trip date'), findsOneWidget);
      await tester.tap(find.text('Choose actual trip date'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          DateTime(2025, 7, 1));
      expect(state.primaryVehicle?.id, 'a');
      expect(state.trips, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
