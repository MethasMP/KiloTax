import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/scanner/document_scanner_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';

class CancelledReceiptScanner extends DocumentScannerService {
  @override
  Future<String?> pickFromGallery() async => null;
}

class ReplacementReceiptScanner extends DocumentScannerService {
  final String path;
  ReplacementReceiptScanner(this.path);

  @override
  Future<String?> pickFromGallery() async => path;
}

void main() {
  AppState state() {
    final appState = AppState();
    appState.addVehicle(Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TEST',
        initialOdometer: 100));
    return appState;
  }

  testWidgets('editing a trip purpose clears only its scoped review item',
      (tester) async {
    final appState = state();
    final fy = appState.activeTaxRule.financialYear;
    final year = int.parse(fy.substring(0, 4));
    appState.recordTrip(Trip(
        id: 'trip',
        vehicleId: 'v1',
        date: DateTime(year, 8, 2),
        purpose: 'Business',
        distanceKm: 10));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: appState, vehicleId: 'v1', financialYear: fy)));
    await tester.pumpAndSettle();
    expect(find.text('1 item needs attention'), findsOneWidget);
    await tester.tap(find.text('Add a business purpose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'Deliver timber to 42 High Street for Smith renovation');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(appState.trips.single.purpose,
        'Deliver timber to 42 High Street for Smith renovation');
    expect(
        find.text(
            'No outstanding record checks. Your records are ready to share for review.'),
        findsOneWidget);
    expect(find.text('Share records'), findsOneWidget);
  });

  testWidgets('saving an empty business purpose leaves the review item pending',
      (tester) async {
    final appState = state();
    final fy = appState.activeTaxRule.financialYear;
    final year = int.parse(fy.substring(0, 4));
    appState.recordTrip(Trip(
      id: 'blank-purpose',
      vehicleId: 'v1',
      date: DateTime(year, 8, 2),
      purpose: 'Business',
      distanceKm: 10,
    ));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
      appState: appState,
      vehicleId: 'v1',
      financialYear: fy,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a business purpose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(appState.trips.single.purpose, 'Business');
    expect(find.text('Add the actual business reason and distance.'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 item needs attention'), findsOneWidget);
  });

  testWidgets(
      'cancelling receipt attachment keeps the editor and record unchanged',
      (tester) async {
    final appState = state();
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: appState,
            receiptDate: DateTime.now(),
            documentScanner: CancelledReceiptScanner())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Attach receipt'));
    await tester.tap(find.text('Attach receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose receipt photo'));
    await tester.pumpAndSettle();
    expect(find.text('Attach receipt'), findsOneWidget);
    expect(find.text('Receipt photo needed'), findsOneWidget);
    expect(appState.expenses, isEmpty);
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
  });

  testWidgets(
      'existing expense confirmation, no-op save and replacement preserve its identity',
      (tester) async {
    final files = await tester.runAsync(() async {
      final directory =
          await Directory.systemTemp.createTemp('expense-widget-');
      final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=');
      final original =
          await File('${directory.path}/original.png').writeAsBytes(bytes);
      final replacement =
          await File('${directory.path}/replacement.png').writeAsBytes(bytes);
      return (
        directory: directory,
        original: original,
        replacement: replacement
      );
    });
    addTearDown(() async {
      await tester.runAsync(() => files!.directory.delete(recursive: true));
    });
    final appState = state();
    final fy = appState.activeTaxRule.financialYear;
    final year = int.parse(fy.substring(0, 4));
    appState.recordExpense(VehicleExpense(
      id: 'expense-original',
      vehicleId: 'v1',
      amount: 12,
      gstAmount: 1.09,
      category: ExpenseCategory.tollsParking,
      date: DateTime(year, 8, 2),
      notes: 'Local parking',
      linkedTripId: 'trip-original',
      clientDedupId: 'dedup-original',
      receiptPath: files!.original.path,
      receiptAudit: ReceiptAuditTrail(
          reviewStatus: ReceiptReviewStatus.needsReview,
          capturedAt: DateTime(year, 8, 2),
          rawOcrText: 'Original parking OCR',
          ocrAmount: 9,
          correctionReasons: const ['amount corrected']),
    ));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ExpenseDetailScreen(
                                  appState: appState,
                                  merchant: 'Local parking',
                                  amount: appState.expenses.single.amount,
                                  categoryName:
                                      ExpenseCategory.tollsParking.displayName,
                                  receiptDate: appState.expenses.single.date,
                                  existingExpense: appState.expenses.single,
                                  documentScanner: ReplacementReceiptScanner(
                                      files.replacement.path),
                                ))),
                    child: const Text('Open expense'))))));

    final checkbox = find.byKey(const ValueKey('confirm-expense-details'));
    Future<void> saveUntil(bool Function() saved) async {
      await tester.ensureVisible(find.text('Update Expense Record'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Update Expense Record'));
      });
      for (var attempts = 0; attempts < 100 && !saved(); attempts++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(saved(), true,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .join(' | '));
      expect(find.text('Open expense'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Open expense'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(checkbox).value, true);
    final amount = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '12.00');
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '15.00');
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(checkbox).value, false);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await saveUntil(() =>
        appState.expenses.single.receiptAudit?.reviewStatus ==
        ReceiptReviewStatus.confirmed);
    expect(appState.expenses.single.amount, 15);
    expect(appState.expenses.single.receiptAudit!.rawOcrText,
        'Original parking OCR');
    final firstReview = appState.expenses.single.receiptAudit!.reviewedAt;

    await tester.tap(find.text('Open expense'));
    await tester.pumpAndSettle();
    await saveUntil(() => find.byType(ExpenseDetailScreen).evaluate().isEmpty);
    expect(appState.expenses.single.receiptAudit!.reviewStatus,
        ReceiptReviewStatus.confirmed);
    expect(appState.expenses.single.receiptAudit!.reviewedAt, firstReview);

    await tester.tap(find.text('Open expense'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Replace receipt'));
    await tester.tap(find.text('Replace receipt'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose receipt photo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final replacementImage = find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is FileImage &&
        (widget.image as FileImage).file.path == files.replacement.path);
    for (var attempts = 0;
        attempts < 100 && replacementImage.evaluate().isEmpty;
        attempts++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(replacementImage, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(checkbox).value, false);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await saveUntil(
        () => appState.expenses.single.receiptPath == files.replacement.path);
    expect(appState.expenses.length, 1);
    expect(appState.expenses.single.id, 'expense-original');
    expect(appState.expenses.single.linkedTripId, 'trip-original');
    expect(appState.expenses.single.clientDedupId, 'dedup-original');
    expect(appState.expenses.single.receiptAudit!.reviewStatus,
        ReceiptReviewStatus.confirmed);
  });
}
