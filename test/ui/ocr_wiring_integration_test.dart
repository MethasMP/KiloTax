import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/receipt_ocr_engine.dart';
import 'package:kiloclaim/services/ocr/thermal_receipt_image_preprocessor.dart';
import 'package:kiloclaim/services/receipts/receipt_workflow_policy.dart';
import 'package:kiloclaim/services/scanner/document_scanner_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SingleImageScanner extends DocumentScannerService {
  final List<String> paths;
  _SingleImageScanner(this.paths);

  @override
  Future<List<String>> scanBatchDocuments({
    int maxPages = 20,
    bool allowFallbackToCamera = true,
  }) async =>
      paths;
}

class _CapturingPreprocessor extends ThermalReceiptImagePreprocessor {
  String? lastOutputPath;
  @override
  Future<PreprocessedReceiptResult> preprocessReceipt({
    required String inputPath,
    required String outputPath,
  }) async {
    lastOutputPath = outputPath;
    await File(outputPath).writeAsBytes([9, 8, 7]);
    return PreprocessedReceiptResult(
      enhancedPath: outputPath,
      clarity: const ReceiptClarityAssessment(
        edgeVariance: 220.0,
        status: ReceiptClarityStatus.sharp,
        isBlurry: false,
      ),
    );
  }
}

class _StubOcrEngine implements ReceiptOcrEngine {
  final String text;
  final bool shouldThrow;
  String? recognizedPath;

  _StubOcrEngine({this.text = '', this.shouldThrow = false});

  @override
  Future<ReceiptOcrExtraction> recognizeFile(String path) async {
    recognizedPath = path;
    if (shouldThrow) {
      throw Exception('Simulated OCR failure');
    }
    return ReceiptOcrExtraction(
      text: text,
      blocks: const [],
      engine: 'stub',
      version: '1.0',
      extractedAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'ScanReceiptScreen deletes temporary _enhanced.jpg after OCR success and failure',
      (tester) async {
    final tempDir =
        Directory.systemTemp.createTempSync('scan_enhanced_cleanup_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final imageFile = File('${tempDir.path}/receipt.jpg')
      ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC'));

    for (final shouldThrow in [false, true]) {
      final state = AppState();
      addTearDown(state.dispose);
      final preprocessor = _CapturingPreprocessor();
      final engine = _StubOcrEngine(
        text: 'AMPOL\nTOTAL AUD \$55.00\nGST \$5.00\n14/11/2026',
        shouldThrow: shouldThrow,
      );
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(shouldThrow),
          home: ScanReceiptScreen(
            appState: state,
            documentScanner: _SingleImageScanner([imageFile.path]),
            preprocessor: preprocessor,
            ocrEngine: engine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open camera scanner'));
      await tester.runAsync(() async {
        for (var i = 0;
            i < 50 && find.byType(ExpenseDetailScreen).evaluate().isEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pump(const Duration(milliseconds: 200));

      final enhancedPath = '${imageFile.path}_enhanced.jpg';
      expect(preprocessor.lastOutputPath, enhancedPath);
      expect(engine.recognizedPath, enhancedPath);
      expect(File(enhancedPath).existsSync(), isFalse);
      expect(File(imageFile.path).existsSync(), isTrue);
      expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    }
  });

  test(
      'ReceiptWorkflowPolicy.analyseWithContext fuses trip POI and prior expense ABN when OCR omits them without clobbering clear receipts',
      () {
    const policy = ReceiptWorkflowPolicy();
    final now = DateTime(2026, 11, 25, 14, 0);

    final trips = [
      Trip(
        id: 't1',
        vehicleId: 'v1',
        date: now.subtract(const Duration(minutes: 25)),
        distanceKm: 8.2,
        purpose: 'Supplies Run',
        destinationAddress: 'Bunnings Warehouse Alexandria',
        detectedPoi: const {'merchantName': 'Bunnings Warehouse'},
      ),
    ];
    final expenses = [
      VehicleExpense(
        id: 'e1',
        vehicleId: 'v1',
        amount: 40.0,
        supplier: 'Bunnings Warehouse',
        supplierAbn: '53 004 085 616',
        category: ExpenseCategory.toolsMaterials,
        date: now.subtract(const Duration(days: 3)),
      ),
    ];

    // 1. Degraded receipt missing merchant & ABN fuses Bunnings trip POI + historical ABN
    final degraded = policy.analyseWithContext(
      'TAX INVOICE\n123456\nTOTAL AUD \$120.00\nINCL GST \$10.91\n25/11/2026',
      fallbackDate: now,
      trips: trips,
      existingExpenses: expenses,
    );
    expect(degraded.merchant, 'Bunnings Warehouse');
    expect(degraded.abn, '53 004 085 616');
    expect(degraded.category, ExpenseCategory.toolsMaterials);
    expect(degraded.evidence, contains('merchant_context_fused'));
    expect(degraded.evidence, contains('abn_context_fused'));

    // 2. Clear BP Fuel receipt on the same day is NOT overwritten by earlier Bunnings trip
    final clearFuel = policy.analyseWithContext(
      'BP BERWICK\nUNLEADED 91\nTOTAL AUD \$65.00\nINCL GST \$5.91\n25/11/2026',
      fallbackDate: now,
      trips: trips,
      existingExpenses: expenses,
    );
    expect(clearFuel.merchant, 'Bp Berwick');
    expect(clearFuel.category, ExpenseCategory.fuel);
    expect(clearFuel.evidence, isNot(contains('merchant_context_fused')));
  });

  testWidgets(
      'ExpenseDetailScreen surfaces atoReport completeness and duplicate warning from AppState.expenses',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'UTE-01',
      taxMethod: TaxMethod.logbook,
      isPrimary: true,
    ));

    final today = DateTime.now();
    state.recordExpense(VehicleExpense(
      id: 'existing-1',
      vehicleId: 'v1',
      amount: 120.00,
      supplier: 'Bunnings Warehouse',
      category: ExpenseCategory.toolsMaterials,
      date: today,
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseDetailScreen(
          appState: state,
          merchant: 'Bunnings Warehouse',
          amount: 120.00,
          categoryName: ExpenseCategory.toolsMaterials.displayName,
          receiptDate: today,
          receiptOcrResult: ReceiptOcrResult(
            merchant: 'Bunnings Warehouse',
            amount: 120.00,
            date: today,
            category: ExpenseCategory.toolsMaterials,
            confidence: 0.9,
            currency: 'AUD',
            evidence: const [],
            rawText: 'BUNNINGS WAREHOUSE\nDRILL BIT SET \$120.00',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Possible duplicate receipt'), findsOneWidget);
    expect(find.byKey(const ValueKey('ato-substantiation-score')),
        findsOneWidget);
    expect(find.text('4/5 Substantiated'), findsOneWidget);
    expect(find.byKey(const ValueKey('ato-missing-items')), findsOneWidget);
    expect(
        find.textContaining('ABN (required over \$82.50)'), findsOneWidget);
  });
}
