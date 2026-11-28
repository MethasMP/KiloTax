import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';

void main() {
  final date = DateTime(2026, 7, 1);
  Future<AppState> setup() async {
    final state = AppState();
    await state.addVehicle(Vehicle(
        id: 'scope-vehicle',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'SCOPE',
        taxMethod: TaxMethod.logbook));
    return state;
  }

  Trip trip(String id,
          {DateTime? when,
          TripClassification classification = TripClassification.business}) =>
      Trip(
          id: id,
          vehicleId: 'scope-vehicle',
          date: when ?? date,
          distanceKm: 12,
          purpose: id,
          destinationAddress: 'Bunnings',
          classification: classification);
  VehicleExpense expense(
          {ExpenseCategory category = ExpenseCategory.toolsMaterials}) =>
      VehicleExpense(
          id: 'scope-expense',
          vehicleId: 'scope-vehicle',
          amount: 50,
          category: category,
          date: date);

  testWidgets('Review preserves exact proposed trip when equal scores exist',
      (tester) async {
    final state = await setup();
    state.recordTrip(trip('first equal match'));
    state.recordTrip(trip('review selected match'));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => ExpenseDetailScreen.show(context,
                    appState: state,
                    expense: expense(),
                    suggestedTripId: 'review selected match',
                    suggestionReason: 'Review supplied reason'),
                child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review supplied reason'), findsOneWidget);
    expect(find.text('Linked trip'), findsNothing);
    final accept = find.byKey(const ValueKey('accept-suggested-trip'));
    await Scrollable.ensureVisible(tester.element(accept), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    final linkedRow = find.text('Linked Trip');
    await Scrollable.ensureVisible(tester.element(linkedRow), alignment: .5);
    await tester.tap(linkedRow);
    await tester.pumpAndSettle();
    final selectedTile = find.ancestor(
        of: find.text('review selected match'),
        matching: find.byType(ListTile));
    expect(selectedTile, findsOneWidget);
    expect(
        find.descendant(
            of: selectedTile,
            matching: find.byIcon(Icons.chevron_right_rounded)),
        findsNothing);
  });

  testWidgets('Cross-year and personal proposed trips cannot be accepted',
      (tester) async {
    final state = await setup();
    state.recordTrip(trip('previous FY', when: DateTime(2026, 6, 30, 23, 59)));
    state.recordTrip(
        trip('private', classification: TripClassification.personal));
    for (final id in ['previous FY', 'private']) {
      await tester.pumpWidget(MaterialApp(
          home: ExpenseDetailScreen(
              key: ValueKey(id),
              appState: state,
              receiptDate: date,
              existingExpense: expense(),
              suggestedTripId: id)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
      final linkedRow = find.text('Linked Trip');
      await Scrollable.ensureVisible(tester.element(linkedRow), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(linkedRow);
      await tester.pumpAndSettle();
      expect(find.text('private'), findsNothing);
      expect(find.text('previous FY'), findsNothing);
      expect(find.textContaining('No eligible trips'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('No eligible trips')))
          .pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Switching materials to pooled fuel invalidates the suggestion',
      (tester) async {
    final state = await setup();
    state.recordTrip(trip('business'));
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: state,
            receiptDate: date,
            existingExpense: expense(),
            suggestedTripId: 'business')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accept-suggested-trip')), findsOneWidget);
    final category = find.text('Category');
    await Scrollable.ensureVisible(tester.element(category), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ExpenseCategory.fuel.displayName).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
  });

  testWidgets('Pooled category ignores an explicit proposed trip',
      (tester) async {
    final state = await setup();
    state.recordTrip(trip('business'));
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: state,
            receiptDate: date,
            existingExpense: expense(category: ExpenseCategory.fuel),
            suggestedTripId: 'business')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
  });
}
