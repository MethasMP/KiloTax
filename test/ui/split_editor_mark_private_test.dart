import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'displays [Mark as Private] chip for convenience item and tapping it updates purpose to private',
      (tester) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
      id: 'car-1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'TRADIE1',
      initialOdometer: 1000,
      taxMethod: TaxMethod.logbook,
    ));

    await tester.pumpWidget(MaterialApp(
      home: ExpenseDetailScreen(
        appState: state,
        merchant: '7-Eleven Mascot',
        amount: 80,
        categoryName: 'Fuel',
        receiptDate: DateTime(2026, 11, 14),
      ),
    ));

    // Tap to split receipt
    final splitBtn = find.byKey(const ValueKey('split-receipt'));
    await tester.ensureVisible(splitBtn);
    await tester.tap(splitBtn);
    await tester.pumpAndSettle();

    // Default item 0 name is 'Receipt items', does not match personal items
    expect(find.byKey(const ValueKey('mark-private-chip-0')), findsNothing);

    // Enter convenience item description: 'Ice Break 500ml'
    await tester.enterText(
        find.byKey(const ValueKey('allocation-description-0-0')),
        'Ice Break 500ml');
    await tester.pumpAndSettle();

    // Verify [Mark as Private] chip is displayed
    final markPrivateChip = find.byKey(const ValueKey('mark-private-chip-0'));
    expect(markPrivateChip, findsOneWidget);
    expect(find.text('Mark as Private'), findsOneWidget);

    // Tap [Mark as Private]
    await tester.ensureVisible(markPrivateChip);
    await tester.tap(markPrivateChip);
    await tester.pumpAndSettle();

    // Once marked as private, the chip should disappear and purpose dropdown should show 'Personal — excluded'
    expect(find.byKey(const ValueKey('mark-private-chip-0')), findsNothing);
    expect(find.text('Personal — excluded'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
      'does not display [Mark as Private] chip if item is already private',
      (tester) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
      id: 'car-2',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'TRADIE2',
      initialOdometer: 2000,
      taxMethod: TaxMethod.logbook,
    ));

    await tester.pumpWidget(MaterialApp(
      home: ExpenseDetailScreen(
        appState: state,
        merchant: 'Ampol',
        amount: 50,
        categoryName: 'Fuel',
        receiptDate: DateTime(2026, 11, 14),
      ),
    ));

    // Tap 'Deduct Personal Items' preset which sets item 1 to 'Personal items (Drink/Food/Etc)' and private
    final deductBtn = find.byKey(const ValueKey('preset-split-snack'));
    await tester.ensureVisible(deductBtn);
    await tester.tap(deductBtn);
    await tester.pumpAndSettle();

    // Item 1 contains 'Drink', but purpose is already AllocationPurpose.private, so chip must not show
    expect(find.byKey(const ValueKey('mark-private-chip-1')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
