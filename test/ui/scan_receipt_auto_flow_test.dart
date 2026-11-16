import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';
import 'package:kilotax/services/scanner/document_scanner_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/expenses/widgets/receipt_processing_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scanner extends DocumentScannerService {
  int calls = 0;
  final result = Completer<List<String>>();
  @override
  Future<List<String>> scanBatchDocuments(
      {int maxPages = 20, bool allowFallbackToCamera = true}) {
    calls++;
    return result.future;
  }
}

class _Ocr implements ReceiptOcrEngine {
  final result = Completer<ReceiptOcrExtraction>();
  @override
  Future<ReceiptOcrExtraction> recognizeFile(String path) => result.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('auto capture starts once and cancellation returns to source',
      (tester) async {
    final scanner = _Scanner();
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ScanReceiptScreen(
                                  appState: state,
                                  documentScanner: scanner,
                                  autoStartScanner: true))),
                      child: const Text('Source')),
                ))));
    await tester.tap(find.text('Source'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(scanner.calls, 1);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Open camera scanner'));
    expect(button.onPressed, isNull);
    scanner.result.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(ScanReceiptScreen), findsNothing);
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets(
      'OCR displays processing until completion and failure preserves image/date review',
      (tester) async {
    final scanner = _Scanner();
    final ocr = _Ocr();
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ScanReceiptScreen(
            appState: state,
            documentScanner: scanner,
            ocrEngine: ocr,
            autoStartScanner: true)));
    scanner.result.complete(['/receipt.jpg']);
    await tester.pump();
    await tester.pump();
    final processing = tester
        .widget<ReceiptProcessingView>(find.byType(ReceiptProcessingView));
    expect(processing.imagePath, '/receipt.jpg');
    expect(find.byType(ExpenseDetailScreen), findsNothing);
    ocr.result.completeError(Exception('OCR unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final detail =
        tester.widget<ExpenseDetailScreen>(find.byType(ExpenseDetailScreen));
    expect(detail.receiptImagePath, '/receipt.jpg');
    expect(detail.purchaseDateUnknown, isTrue);
    expect(find.byType(ScanReceiptScreen), findsNothing);
  });

  testWidgets('camera error stays on scanner with explicit recovery choices',
      (tester) async {
    final scanner = _Scanner();
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ScanReceiptScreen(
            appState: state,
            documentScanner: scanner,
            autoStartScanner: true)));
    scanner.result.completeError(Exception('Camera unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t open the camera.'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.byType(ExpenseDetailScreen), findsNothing);
    expect(scanner.calls, 1);
  });
}
