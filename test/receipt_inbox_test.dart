import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/receipts/receipt_inbox_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/receipt_inbox_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ReceiptInboxService store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('receipt_inbox_test');
    store = ReceiptInboxService(
        await SharedPreferences.getInstance(), 'test', directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('retains original bytes with stable ID across retry and survives reload',
      () async {
    final source =
        await File('${directory.path}/source.png').writeAsBytes([1, 2, 3]);
    final draft = await store.retain(source.path, 'car');
    await store.save([draft]);
    await source.delete();
    final loaded = store.load().single;
    expect(await File(loaded.expense.receiptPath!).readAsBytes(), [1, 2, 3]);
    expect(loaded.processed, isFalse);
    final retry = await store.retain(loaded.expense.receiptPath!, 'car');
    expect(retry.expense.id, draft.expense.id);
    expect(retry.expense.sha256Hash, draft.expense.sha256Hash);
  });

  test('account scopes keep drafts separate and review issues persist',
      () async {
    final draft = ReceiptDraft(
        VehicleExpense(
            id: 'one',
            vehicleId: 'car',
            amount: 10,
            category: ExpenseCategory.fuel,
            date: DateTime(2026)),
        processed: true,
        issues: const ['Choose purchase date']);
    await store.save([draft]);
    final other = ReceiptInboxService(store.preferences, 'other', directory);
    expect(other.load(), isEmpty);
    expect(store.load().single.issues, ['Choose purchase date']);
    expect(store.load().single.expense.amount, 10);
  });

  test('missing and rejected dates remain explicitly marked for review', () {
    const service = ReceiptIntelligenceService();
    final missing = service.analyseText('FUEL SHOP\nDIESEL 20L\nTOTAL 50.00');
    expect(missing.dateNeedsReview, isTrue);
    expect(missing.evidence, contains('purchase_date_missing'));
    final future =
        service.analyseText('FUEL SHOP\nDATE 01/01/2099\nTOTAL 50.00');
    expect(future.dateNeedsReview, isTrue);
    expect(future.evidence.any((e) => e.startsWith('purchase_date_rejected:')),
        isTrue);
    final dated =
        service.analyseText('FUEL SHOP\nDATE 01/01/2026\nTOTAL 50.00');
    expect(dated.dateNeedsReview, isFalse);
    expect(
        service
            .analyseText('FUEL SHOP\nDATE 31/02/2026\nTOTAL 50.00')
            .dateNeedsReview,
        isTrue);
  });

  for (final failOnce in [false, true]) {
    testWidgets('batch confirmation and recovery (partial failure: $failOnce)',
        (tester) async {
      final image = File('${directory.path}/receipt.png');
      image.writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC'));
      final state = failOnce ? _FailSecondSaveState() : AppState();
      await state.addVehicle(Vehicle(
          id: 'car',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'TEST',
          initialOdometer: 0,
          taxMethod: TaxMethod.centsPerKm,
          isPrimary: true));
      final drafts = List.generate(
          3,
          (i) => ReceiptDraft(
              VehicleExpense(
                  id: 'draft_$i',
                  vehicleId: 'car',
                  amount: 20 + i.toDouble(),
                  supplier: 'Shop $i',
                  category: ExpenseCategory.fuel,
                  date: DateTime.now(),
                  receiptPath: image.path),
              processed: true,
              extractionReviewed: true,
              issues: i == 2 ? ['Choose purchase date'] : []));
      await tester.runAsync(() => store.save(drafts));
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: ReceiptInboxScreen(appState: state, inbox: store)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(state.expenses, isEmpty);
      await tester.tap(find.text('Select all ready receipts'));
      await tester.pump();
      expect(find.text('Confirm 2 selected · AUD 41.00'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm 2 selected · AUD 41.00'));
        for (var i = 0;
            i < 500 && (state.expenses.length < 2 || store.load().length > 1);
            i++) {
          if (failOnce &&
              state is _FailSecondSaveState &&
              state.attempts >= 2 &&
              state.expenses.length == 1) { break; }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      if (failOnce) {
        expect(state.expenses.length, 1);
        expect(store.load().length, 2);
        expect(find.textContaining('Some receipts could not be saved'),
            findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('Confirm 1 selected · AUD 21.00'));
          for (var i = 0;
              i < 500 && (state.expenses.length < 2 || store.load().length > 1);
              i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        await tester.pumpAndSettle();
      }
      expect(state.expenses.length, 2,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .whereType<String>()
              .where((t) => t.contains('could not be saved'))
              .join());
      expect(
          state.expenses.every((e) =>
              e.receiptAudit?.reviewStatus == ReceiptReviewStatus.confirmed),
          isTrue);
      expect(state.expenses.every((e) => e.isVaultOnly), isTrue);
      expect(store.load().single.expense.id, 'draft_2');
      // Reopening reconciles any previously recorded IDs instead of duplicating rows.
      await tester.runAsync(() async {
        final current = store.load();
        await store.save([...current, ...drafts.take(2)]);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: ReceiptInboxScreen(appState: state, inbox: store)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(store.load().length, 1);
      expect(state.expenses.length, 2,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .whereType<String>()
              .where((t) => t.contains('could not be saved'))
              .join());
    });
  }
}

class _FailSecondSaveState extends AppState {
  int attempts = 0;
  @override
  Future<void> saveWorkflowReceipt(VehicleExpense expense) async {
    if (++attempts == 2) throw StateError('Simulated storage failure');
    await super.saveWorkflowReceipt(expense);
  }
}
