import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';

void main() {
  group('Expense Auto-Classify & 3-Pillar UX Tests', () {
    testWidgets(
        'ExpenseDetailScreen requires review when no OCR evidence is supplied',
        (WidgetTester tester) async {
      final appState = AppState();
      addTearDown(appState.dispose);
      final vehicle = Vehicle(
        id: 'v_ocr_1',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TRADIE-BP',
        initialOdometer: 10000.0,
      );
      await appState.addVehicle(vehicle);

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailScreen(
            appState: appState,
            merchant: 'BP Connect Mascot',
            amount: 142.50,
            categoryName: 'Fuel',
            receiptDate: DateTime(2026, 9, 11),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review before export'), findsOneWidget);
      expect(find.text('Receipt photo needed'), findsOneWidget);
      expect(find.textContaining('Draft extracted from photo'), findsNothing);
      expect(
          tester
              .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('confirm-expense-details')))
              .value,
          isFalse);
      expect(
          find.text(
              'Saving without confirmation keeps this expense in review.'),
          findsOneWidget);
      expect(find.text('BP Connect Mascot'), findsOneWidget);
      expect(find.text('142.50'), findsOneWidget);

      await tester.ensureVisible(find.text('Fuel & Oil').first);
      await tester.tap(find.text('Fuel & Oil').first);
      await tester.pumpAndSettle();

      expect(find.text('SELECT STATUTORY CATEGORY'), findsOneWidget);
      expect(find.text('Core 3 Pillars (97% of Tradie Vehicle Claims)'),
          findsOneWidget);
      expect(find.text('Other Secondary Business Costs'), findsOneWidget);

      await tester.tap(find.text('Servicing, Repairs & Tyres'));
      await tester.pumpAndSettle();

      expect(find.text('Servicing, Repairs & Tyres'), findsWidgets);
    });
  });
}
