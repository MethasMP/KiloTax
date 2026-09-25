import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';

void main() {
  group('Expense Auto-Classify & 3-Pillar UX Tests', () {
    testWidgets('ExpenseDetailScreen requires review when no OCR evidence is supplied',
        (WidgetTester tester) async {
      final appState = AppState();
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

      // 1. A manually seeded value is never presented as OCR evidence.
      expect(find.text('MANUAL ENTRY • REVIEW REQUIRED'), findsOneWidget);
      expect(find.textContaining('Attach a clear receipt'), findsOneWidget);
      expect(find.text('BP Connect Mascot'), findsOneWidget);
      expect(find.text('142.50'), findsOneWidget);

      // 2. Open Category Picker and verify 3 Core Pillars are rendered
      await tester.tap(find.text('Fuel & Oil').first);
      await tester.pumpAndSettle();

      expect(find.text('SELECT STATUTORY CATEGORY'), findsOneWidget);
      expect(find.text('Core 3 Pillars (97% of Tradie Vehicle Claims)'), findsOneWidget);
      expect(find.text('Other Secondary Business Costs'), findsOneWidget);

      // 3. User can manually tap another category if needed
      await tester.tap(find.text('Servicing, Repairs & Tyres'));
      await tester.pumpAndSettle();

      // Verify category updated to Repairs
      expect(find.text('Servicing, Repairs & Tyres'), findsWidgets);
    });
  });
}
