import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';
import 'package:kilotax/services/receipts/receipt_inbox_service.dart';
import 'package:kilotax/services/scanner/document_scanner_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/expenses/receipt_inbox_screen.dart';
import 'package:kilotax/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDocumentScannerService extends DocumentScannerService {
  List<String> nextScanBatchResult = [];
  List<String> nextGalleryResult = [];
  bool throwOnScan = false;

  @override
  Future<List<String>> scanBatchDocuments({
    int maxPages = 20,
    bool allowFallbackToCamera = true,
  }) async {
    if (throwOnScan) throw Exception('Camera scan failure');
    return nextScanBatchResult;
  }

  @override
  Future<List<String>> pickMultipleFromGallery() async {
    return nextGalleryResult;
  }
}

class _FakeReceiptOcrEngine implements ReceiptOcrEngine {
  final ReceiptOcrExtraction extractionResult;
  _FakeReceiptOcrEngine(this.extractionResult);

  @override
  Future<ReceiptOcrExtraction> recognizeFile(String path) async {
    return extractionResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sharedPrefs;
  late AppState appState;
  late _FakeDocumentScannerService fakeScanner;
  late Directory tempDir;
  late ReceiptInboxService fakeInbox;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    appState = AppState();
    fakeScanner = _FakeDocumentScannerService();

    final vehicle = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'UTE-123',
      isPrimary: true,
    );
    appState.addVehicle(vehicle);

    tempDir = Directory.systemTemp.createTempSync('scan_receipt_test');
    fakeInbox = ReceiptInboxService(
      sharedPrefs,
      'test_account',
      tempDir,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget({ReceiptOcrEngine? engine}) {
    return MaterialApp(
      home: ScanReceiptScreen(
        appState: appState,
        documentScanner: fakeScanner,
        ocrEngine: engine,
        receiptInboxService: fakeInbox,
      ),
    );
  }

  testWidgets(
      'Single Shot Mode: 1 image navigates directly to ExpenseDetailScreen with parsed OCR',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ocrText =
        'BUNNINGS WAREHOUSE\nABN: 12 345 678 901\nTOTAL: \$149.50\nGST: \$13.59\n12/03/2026';
    final fakeEngine = _FakeReceiptOcrEngine(
      ReceiptOcrExtraction(
        text: ocrText,
        blocks: [
          ReceiptOcrBlock(
              page: 1, text: 'BUNNINGS WAREHOUSE', bounds: [0, 0, 100, 20]),
          ReceiptOcrBlock(
              page: 1, text: 'TOTAL: \$149.50', bounds: [0, 25, 100, 45]),
        ],
        engine: 'test-engine',
        version: '1.0',
        extractedAt: DateTime.now(),
      ),
    );

    final testImageFile = File('${tempDir.path}/receipt_single.jpg');
    testImageFile.writeAsBytesSync([1, 2, 3]);

    fakeScanner.nextScanBatchResult = [testImageFile.path];

    await tester.pumpWidget(buildTestWidget(engine: fakeEngine));
    await tester.pumpAndSettle();

    expect(find.text('Receipt Scanner'), findsOneWidget);
    expect(find.text('Open camera scanner'), findsOneWidget);

    // Tap camera scanner
    await tester.tap(find.text('Open camera scanner'));
    await tester.pump(); // Start async processing

    // Shows processing status
    expect(find.text('Reading receipt details…'), findsOneWidget);

    // Pump frames to complete async single shot navigation
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verifies navigation directly to ExpenseDetailScreen (Single Shot Mode)
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    expect(find.byType(ReceiptInboxScreen), findsNothing);

    // Verify merchant and amount are populated
    expect(
        find.byWidgetPredicate((w) =>
            w is EditableText && w.controller.text == 'Bunnings Warehouse'),
        findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is EditableText && w.controller.text == '149.50'),
        findsOneWidget);
  });

  testWidgets('Shoebox Mode: >1 images navigate to ReceiptInboxScreen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final f1 = File('${tempDir.path}/p1.jpg')..writeAsBytesSync([1]);
    final f2 = File('${tempDir.path}/p2.jpg')..writeAsBytesSync([2]);

    fakeScanner.nextScanBatchResult = [f1.path, f2.path];

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open camera scanner'));
    await tester.pump();

    expect(find.text('Opening your receipt inbox…'), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verifies navigation to ReceiptInboxScreen (Shoebox / Batch mode)
    expect(find.byType(ReceiptInboxScreen), findsOneWidget);
    expect(find.byType(ExpenseDetailScreen), findsNothing);
  });

  testWidgets(
      'Shoebox Mode: Open saved receipt drafts button navigates to ReceiptInboxScreen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open saved receipt drafts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ReceiptInboxScreen), findsOneWidget);
  });

  testWidgets('Manual receipt entry button opens ExpenseDetailScreen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter details manually'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    expect(find.byType(ReceiptInboxScreen), findsNothing);
  });

  testWidgets('Scan error offers manual entry without silently navigating',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    fakeScanner.throwOnScan = true;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open camera scanner'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailScreen), findsNothing);
    expect(find.textContaining('Couldn’t open the camera.'), findsOneWidget);
    await tester.ensureVisible(find.text('Enter details manually'));
    await tester.tap(find.text('Enter details manually'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
  });
}
