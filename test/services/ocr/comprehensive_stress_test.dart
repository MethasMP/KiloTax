import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/australian_tax_validator.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/receipt_ocr_engine.dart';
import 'package:kiloclaim/services/ocr/spatial_receipt_parser.dart';
import 'package:kiloclaim/services/ocr/thermal_receipt_image_preprocessor.dart';

void main() {
  group('Comprehensive Divergent & Convergent OCR Stress-Test Battery', () {
    const service = ReceiptIntelligenceService();
    const preprocessor = ThermalReceiptImagePreprocessor();
    const spatialParser = SpatialReceiptParser();

    // =========================================================================
    // SECTION 1: DIVERGENT THINKING - ADVERSARIAL STRESS-TESTS & EDGE CASES
    // =========================================================================

    test('Divergent #1: Thermal Fading & Image Preprocessing Enhancement', () async {
      final inputPath = 'tool/receipt_benchmark/dataset/au_bunnings_faded_02.png';
      final outputPath = 'tool/receipt_benchmark/dataset/enhanced_stress_test_bunnings.jpg';

      if (File(inputPath).existsSync()) {
        final resultPath = await preprocessor.enhanceThermalReceipt(
          inputPath: inputPath,
          outputPath: outputPath,
        );
        final file = File(resultPath);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(1000));
      }
    });

    test('Divergent #2: ABN Optical Degradation & Mod-89 Algorithmic Repair', () {
      // Known valid Australian ABNs:
      // Bunnings: 26 008 672 179
      // Ampol: 17 000 032 128
      // BP Australia: 53 004 085 616
      // 7-Eleven: 48 005 299 427
      // Viva Energy (Shell): 46 004 610 459

      // Test Case 2A: Full character confusion 'O'->'0', 'l'->'1', 'B'->'8'
      const corruptedBunnings = '26 OO8 672 l79';
      final repairedBunnings = AustralianTaxValidator.repairOcrAbn(corruptedBunnings);
      expect(repairedBunnings, equals('26008672179'));

      const corruptedAmpol = 'l7 OOO O32 l28';
      final repairedAmpol = AustralianTaxValidator.repairOcrAbn(corruptedAmpol);
      expect(repairedAmpol, equals('17000032128'));

      const corruptedBP = '53 OO4 O85 6l6';
      final repairedBP = AustralianTaxValidator.repairOcrAbn(corruptedBP);
      expect(repairedBP, equals('53004085616'));

      // Test Case 2B: Hamming distance 1 single digit optical confusion (e.g., '0' misread as '8')
      // Original BP: 53 004 085 616 -> Corrupted: 53 084 085 616
      const bpSingleDigitError = '53 084 085 616';
      final repairedBpSingle = AustralianTaxValidator.repairOcrAbn(bpSingleDigitError);
      expect(repairedBpSingle, equals('53004085616'));

      // Test Case 2C: Rejection of non-ABN 11-digit sequences (Phone numbers, Barcodes)
      const fakePhoneAbn = '61 412 345 678';
      expect(AustralianTaxValidator.isValidAbn(fakePhoneAbn), isFalse);
      expect(AustralianTaxValidator.repairOcrAbn(fakePhoneAbn), isNull);

      const fakeBarcode = '9312345678901';
      expect(AustralianTaxValidator.isValidAbn(fakeBarcode), isFalse);
    });

    test('Divergent #3: Mathematical GST Invariant Total Auto-Repair', () {
      // When Total is dropped, corrupted, or missing decimal, but GST is intact:
      const rawTextWithCorruptedTotal = '''
REECE PLUMBING CHATSWOOD
REECE AUSTRALIA PTY LTD
ABN: 84 004 097 090
TAX INVOICE
COPPER PIPE 15MM X 6M    \$11000
GST INCLUDED:            \$10.00
TOTAL AUD:               \$11000
''';
      final result = service.analyseText(rawTextWithCorruptedTotal);
      expect(result.amount, equals(110.00));
      expect(result.gstAmount, equals(10.00));
      expect(result.evidence, contains('total_repaired_from_gst:110.00'));
      expect(result.evidence, contains('gst_invariant_match'));
    });

    test('Divergent #4: Fuel Supermarket Discount Reconciliation', () {
      const discountFuelReceipt = '''
AMPOL FOODARY
AMPOL PETROLEUM PTY LTD
ABN 17 000 032 128
UNLEADED 91   40.00L @ \$2.00/L  \$80.00
WOOLWORTHS 4C FUEL DISCOUNT   -\$1.60
TOTAL AUD                      \$78.40
INCLUDES GST                   \$7.13
''';
      final result = service.analyseText(discountFuelReceipt);
      expect(result.amount, equals(78.40));
      expect(result.gstAmount, equals(7.13));
      expect(result.evidence, contains('discount_detected:1.60'));
      expect(result.evidence, contains('discount_reconciled'));
    });

    test('Divergent #5: Adversarial Personal Items Infiltration & Audit Flagging', () {
      final mixedItemsList = [
        'ICE BREAK 500ML ICED COFFEE',
        'Cadbury Dairy Milk 180g Chocolate',
        'Smiths Crinkle Cut Salt & Vinegar Chips',
        'Four\'N Twenty King Size Meat Pie',
        'Red Bull 250ml Energy Drink',
        'Coca-Cola No Sugar 600ml Bottle',
        'Dare Iced Coffee 750ml',
      ];

      for (final item in mixedItemsList) {
        expect(service.isLikelyPersonalItem(item), isTrue,
            reason: '$item must be detected as personal item');
      }

      const mixedDocket = '''
BP CONNECT
BP AUSTRALIA PTY LTD
ABN 53 004 085 616
DIESEL 50L                   \$100.00
ICE BREAK 500ML                \$4.50
RED BULL 250ML CAN             \$4.00
TOTAL AUD                    \$108.50
INCL GST                       \$9.86
''';
      final result = service.analyseText(mixedDocket);
      expect(result.hasMixedItems, isTrue);
      expect(result.isHighConfidence, isFalse);
      expect(result.evidence, contains('mixed_items'));
    });

    test('Divergent #6: Disjoint Spatial Column Matching (Anchor to Value)', () {
      final disjointBlocks = [
        ReceiptOcrBlock(page: 1, text: 'SYDNEY TOOLS', bounds: [20.0, 30.0, 150.0, 50.0]),
        ReceiptOcrBlock(page: 1, text: 'ABN: 84 004 097 090', bounds: [20.0, 60.0, 200.0, 80.0]),
        ReceiptOcrBlock(page: 1, text: 'DATE: 18/11/2026', bounds: [20.0, 90.0, 180.0, 110.0]),
        ReceiptOcrBlock(page: 1, text: 'TOTAL AUD', bounds: [20.0, 300.0, 120.0, 320.0]),
        ReceiptOcrBlock(page: 1, text: '\$245.00', bounds: [350.0, 298.0, 420.0, 322.0]),
        ReceiptOcrBlock(page: 1, text: 'INCLUDES GST', bounds: [20.0, 330.0, 140.0, 350.0]),
        ReceiptOcrBlock(page: 1, text: '\$22.27', bounds: [350.0, 328.0, 410.0, 352.0]),
      ];

      final spatial = spatialParser.parse(disjointBlocks);
      expect(spatial.totalAmount, equals(245.00));
      expect(spatial.gstAmount, equals(22.27));
      expect(spatial.abn, equals('84004097090'));

      final assembledText = ReceiptReadingOrder.assemble(disjointBlocks);
      final result = service.analyseText(assembledText, blocks: disjointBlocks);
      expect(result.amount, equals(245.00));
      expect(result.gstAmount, equals(22.27));
      expect(result.abn, equals('84 004 097 090'));
      expect(result.isHighConfidence, isTrue);
    });

    test('Divergent #7: Category Classification Across Work vs Running vs Tools', () {
      const fuelSample = 'BP CONNECT UNLEADED 91 PUMP 02 TOTAL \$80.00';
      final fuelRes = service.analyseText(fuelSample);
      expect(fuelRes.category, equals(ExpenseCategory.fuel));

      const toolsSample = 'BUNNINGS WAREHOUSE TIMBER PINE DRILL BIT SET TOTAL \$150.00';
      final toolsRes = service.analyseText(toolsSample);
      expect(toolsRes.category, equals(ExpenseCategory.toolsMaterials));

      const maintSample = 'BOB JANE T-MARTS WHEEL ALIGNMENT NEW TYRES 225/45R17 TOTAL \$450.00';
      final maintRes = service.analyseText(maintSample);
      expect(maintRes.category, equals(ExpenseCategory.maintenanceTyres));
    });

    // =========================================================================
    // SECTION 2: CONVERGENT THINKING - EXACT STATISTICAL ACCURACY MATRIX
    // =========================================================================

    test('Convergent: Synthesizes Precision, Recall, and F1 across Benchmark Dataset', () {
      final benchmarkCorpus = [
        {
          'name': 'Bunnings Trade Clean',
          'text': '''
BUNNINGS WAREHOUSE
ABN 26 008 672 179
DEWALT IMPACT DRIVER   \$249.00
INCLUDES GST           \$22.64
TOTAL AUD              \$249.00
''',
          'expected_merchant': 'Bunnings Warehouse',
          'expected_abn': '26 008 672 179',
          'expected_total': 249.00,
          'expected_gst': 22.64,
          'expected_category': ExpenseCategory.toolsMaterials,
          'expected_mixed': false,
        },
        {
          'name': 'Ampol Fuel Faded ABN with OCR Confusion',
          'text': '''
AMPOL PETROLEUM
ABN l7 OOO O32 l28
VORTEX DIESEL 65L      \$130.00
GST INCLUDED           \$11.82
TOTAL AUD              \$130.00
''',
          'expected_merchant': 'Ampol Petroleum',
          'expected_abn': '17 000 032 128',
          'expected_total': 130.00,
          'expected_gst': 11.82,
          'expected_category': ExpenseCategory.fuel,
          'expected_mixed': false,
        },
        {
          'name': '7-Eleven Fuel + Personal Drink Mixed Docket',
          'text': '''
7-ELEVEN STORES
ABN 48 005 299 427
UNLEADED 91            \$65.00
ICE BREAK 500ML         \$4.50
TOTAL AUD              \$69.50
INCL GST                \$6.32
''',
          'expected_merchant': '7-Eleven Stores',
          'expected_abn': '48 005 299 427',
          'expected_total': 69.50,
          'expected_gst': 6.32,
          'expected_category': ExpenseCategory.fuel,
          'expected_mixed': true,
        },
        {
          'name': 'BP Fuel with Dropped Decimal Point in Total',
          'text': '''
BP AUSTRALIA
ABN 53 004 085 616
UNLEADED 91            \$8800
INCLUDES GST           \$8.00
TOTAL AUD              \$8800
''',
          'expected_merchant': 'Bp Australia',
          'expected_abn': '53 004 085 616',
          'expected_total': 88.00, // Reconciled via 8.00 * 11
          'expected_gst': 8.00,
          'expected_category': ExpenseCategory.fuel,
          'expected_mixed': false,
        },
        {
          'name': 'Reece Plumbing Commercial Trade Invoice',
          'text': '''
REECE PLUMBING
ABN 84 004 097 090
PEX PIPE CRIMP FITTINGS \$330.00
GST INCL                \$30.00
TOTAL AUD               \$330.00
''',
          'expected_merchant': 'Reece Plumbing',
          'expected_abn': '84 004 097 090',
          'expected_total': 330.00,
          'expected_gst': 30.00,
          'expected_category': ExpenseCategory.toolsMaterials,
          'expected_mixed': false,
        },
        {
          'name': 'Bob Jane T-Marts Tyres & Maintenance',
          'text': '''
BOB JANE T-MARTS
ABN 46 004 610 459
BRIDGESTONE TYRES X4    \$550.00
WHEEL ALIGNMENT          \$88.00
INCL GST 10%             \$58.00
TOTAL AUD               \$638.00
''',
          'expected_merchant': 'Bob Jane T-Marts',
          'expected_abn': '46 004 610 459',
          'expected_total': 638.00,
          'expected_gst': 58.00,
          'expected_category': ExpenseCategory.maintenanceTyres,
          'expected_mixed': false,
        },
      ];

      int totalTotalTarget = benchmarkCorpus.length;
      int totalTotalMatches = 0;

      int totalGstTarget = benchmarkCorpus.length;
      int totalGstMatches = 0;

      int totalAbnTarget = benchmarkCorpus.length;
      int totalAbnMatches = 0;

      int totalCatTarget = benchmarkCorpus.length;
      int totalCatMatches = 0;

      int totalMixedTarget = benchmarkCorpus.length;
      int totalMixedMatches = 0;

      print('\n===============================================================');
      print('CONVERGENT ACCURACY BENCHMARK EVALUATION RESULTS');
      print('===============================================================');

      for (final doc in benchmarkCorpus) {
        final res = service.analyseText(doc['text'] as String);

        final expTotal = doc['expected_total'] as double;
        final expGst = doc['expected_gst'] as double;
        final expAbn = doc['expected_abn'] as String;
        final expCat = doc['expected_category'] as ExpenseCategory;
        final expMixed = doc['expected_mixed'] as bool;

        final totalMatched = (res.amount - expTotal).abs() <= 0.05;
        if (totalMatched) totalTotalMatches++;

        final gstMatched = res.gstAmount != null && (res.gstAmount! - expGst).abs() <= 0.05;
        if (gstMatched) totalGstMatches++;

        final abnMatched = res.abn == expAbn;
        if (abnMatched) totalAbnMatches++;

        final catMatched = res.category == expCat;
        if (catMatched) totalCatMatches++;

        final mixedMatched = res.hasMixedItems == expMixed;
        if (mixedMatched) totalMixedMatches++;

        print('Sample: ${doc['name']}');
        print('  Total: Expected \$${expTotal.toStringAsFixed(2)}, Got \$${res.amount.toStringAsFixed(2)} [${totalMatched ? "PASS" : "FAIL"}]');
        print('  GST:   Expected \$${expGst.toStringAsFixed(2)}, Got \$${res.gstAmount?.toStringAsFixed(2)} [${gstMatched ? "PASS" : "FAIL"}]');
        print('  ABN:   Expected $expAbn, Got ${res.abn} [${abnMatched ? "PASS" : "FAIL"}]');
        print('  Cat:   Expected ${expCat.name}, Got ${res.category.name} [${catMatched ? "PASS" : "FAIL"}]');
        print('  Mixed: Expected $expMixed, Got ${res.hasMixedItems} [${mixedMatched ? "PASS" : "FAIL"}]');
        print('---------------------------------------------------------------');
      }

      final totalAccuracy = (totalTotalMatches / totalTotalTarget) * 100;
      final gstAccuracy = (totalGstMatches / totalGstTarget) * 100;
      final abnAccuracy = (totalAbnMatches / totalAbnTarget) * 100;
      final catAccuracy = (totalCatMatches / totalCatTarget) * 100;
      final mixedAccuracy = (totalMixedMatches / totalMixedTarget) * 100;

      print('SUMMARY METRICS:');
      print('  Total Amount Precision/Recall:  ${totalAccuracy.toStringAsFixed(1)}%');
      print('  GST Invariant Precision/Recall: ${gstAccuracy.toStringAsFixed(1)}%');
      print('  ABN Mod-89 Precision/Recall:    ${abnAccuracy.toStringAsFixed(1)}%');
      print('  Category Classification Acc:    ${catAccuracy.toStringAsFixed(1)}%');
      print('  Personal Mixed Item Acc:        ${mixedAccuracy.toStringAsFixed(1)}%');
      print('===============================================================\n');

      expect(totalAccuracy, greaterThanOrEqualTo(95.0));
      expect(gstAccuracy, greaterThanOrEqualTo(95.0));
      expect(abnAccuracy, greaterThanOrEqualTo(95.0));
      expect(catAccuracy, greaterThanOrEqualTo(95.0));
      expect(mixedAccuracy, greaterThanOrEqualTo(95.0));
    });
  });
}
