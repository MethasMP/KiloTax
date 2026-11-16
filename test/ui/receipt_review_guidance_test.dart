import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilotax/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/core/utils/formatters.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';

class _ReviewState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

Future<AppState> _state() async {
  final state = _ReviewState();
  await state.addVehicle(Vehicle(
    id: 'review-car',
    make: 'Toyota',
    model: 'HiLux',
    regoPlate: 'REVIEW',
    taxMethod: TaxMethod.logbook,
  ));
  return state;
}

ReceiptOcrResult _ocr({bool unknownDate = false}) => ReceiptOcrResult(
      merchant: 'Workshop Supplies',
      amount: 42,
      date: DateTime(2026, 11, 14),
      dateNeedsReview: unknownDate,
      category: ExpenseCategory.fuel,
      confidence: 0.92,
      evidence: const ['merchant', 'total'],
      rawText: 'Workshop Supplies\nTOTAL 42.00',
      currency: 'AUD',
    );

Widget _screen(AppState state,
    {ReceiptOcrResult? ocr,
    String? image,
    VehicleExpense? existing,
    bool unknownDate = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ExpenseDetailScreen(
      appState: state,
      receiptDate: DateTime(2026, 11, 14),
      merchant: 'Workshop Supplies',
      amount: 42,
      categoryName: 'Fuel',
      receiptOcrResult: ocr,
      receiptImagePath: image,
      existingExpense: existing,
      purchaseDateUnknown: unknownDate,
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    await font.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Extracted receipt is explicitly an unsaved draft without field confidence claims',
      (tester) async {
    final state = await _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(_screen(state, ocr: _ocr()));
    await tester.pumpAndSettle();
    expect(find.text('Review your receipt'), findsOneWidget);
    expect(find.textContaining('Draft extracted from photo, not saved.'),
        findsOneWidget);
    expect(find.textContaining('not saved'), findsOneWidget);
    expect(find.textContaining('92%'), findsNothing);
    expect(find.textContaining('merchant, date, amount and category'),
        findsOneWidget);
    expect(state.expenses, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual expense has no receipt extraction guidance',
      (tester) async {
    final state = await _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(_screen(state));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-review-guidance')), findsNothing);
    expect(find.text('Expense detail'), findsOneWidget);
    expect(find.text('Attach receipt'), findsOneWidget);
  });

  testWidgets(
      'Existing receipt is labelled as editing rather than a newly extracted draft',
      (tester) async {
    final state = await _state();
    addTearDown(state.dispose);
    final expense = VehicleExpense(
      id: 'existing-receipt',
      vehicleId: 'review-car',
      date: DateTime(2026, 11, 14),
      amount: 42,
      category: ExpenseCategory.fuel,
      receiptPath: '/missing/existing-receipt.jpg',
    );
    await tester.pumpWidget(_screen(state, existing: expense));
    await tester.pumpAndSettle();
    expect(find.text('Edit receipt details'), findsOneWidget);
    expect(find.textContaining('before updating this record'), findsOneWidget);
    expect(find.textContaining('not saved'), findsNothing);
    expect(find.text('Update Expense Record'), findsOneWidget);
  });

  testWidgets(
      'Unknown purchase date stays unresolved until the user chooses it',
      (tester) async {
    final state = await _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(
        _screen(state, ocr: _ocr(unknownDate: true), unknownDate: true));
    await tester.pumpAndSettle();
    expect(find.text('Choose purchase date'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-date-needs-review')),
        findsOneWidget);
    expect(find.text(Formatters.date(DateTime(2026, 11, 14))), findsNothing);
    await tester.ensureVisible(find.text('Choose purchase date'));
    await tester.tap(find.text('Choose purchase date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Choose purchase date'), findsOneWidget);
    expect(state.expenses, isEmpty);
  });

  testWidgets(
      'Receipt photo opens an inspectable zoom view and essential fields precede extras',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _state();
    addTearDown(state.dispose);
    final photo = File('assets/icon_master.png').absolute.path;
    await tester.pumpWidget(_screen(state, ocr: _ocr(), image: photo));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('receipt-photo-card'))).height,
        lessThanOrEqualTo(120));
    expect(tester.getSize(find.byKey(const ValueKey('expense-merchant'))).width,
        greaterThanOrEqualTo(290));
    expect(
        tester.getTopLeft(find.text('Tax Receipt Evidence')).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('expense-merchant')))
            .dy));
    expect(tester.getTopLeft(find.byKey(const ValueKey('expense-amount'))).dy,
        lessThan(tester.getTopLeft(find.text('Additional details')).dy));
    expect(tester.getTopLeft(find.text('Category')).dy,
        lessThan(tester.getTopLeft(find.text('Additional details')).dy));
    expect(find.text('Supplier ABN (if printed)'), findsOneWidget);
    expect(find.text('Receipt currency'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-receipt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inspect-receipt-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Receipt photo'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close receipt photo'));
    await tester.pumpAndSettle();
    expect(find.text('Review your receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
