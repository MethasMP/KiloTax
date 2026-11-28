import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/evidence_expenses_screen.dart';

void main() {
  testWidgets('Expense filters commit on Apply and discard when closed',
      (t) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
        id: 'car',
        make: 'Ford',
        model: 'Ranger',
        taxMethod: TaxMethod.logbook));
    await t.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: EvidenceExpensesScreen())));
    await t.tap(find.byTooltip('Filter & Sort'));
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile).first);
    await t.pump();
    await t.tap(find.byTooltip('Close filters'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filter & Sort'));
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isFalse);
    await t.tap(find.byType(SwitchListTile).first);
    await t.pump();
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filter & Sort'));
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isTrue);
  });
}
