import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/australian_tax_validator.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/thermal_receipt_image_preprocessor.dart';

void main() {
  group('Real & Simulated Australian Receipt OCR Benchmark Suite', () {
    const service = ReceiptIntelligenceService();
    const preprocessor = ThermalReceiptImagePreprocessor();

    test('1. Thermal pre-processor enhances and downscales images without throwing', () async {
      final inputPath = 'tool/receipt_benchmark/dataset/au_bunnings_faded_02.png';
      final outputPath = 'tool/receipt_benchmark/dataset/enhanced_au_bunnings_faded_02.jpg';

      final result = await preprocessor.enhanceThermalReceipt(
        inputPath: inputPath,
        outputPath: outputPath,
      );

      expect(File(result).existsSync(), isTrue);
      expect(File(result).lengthSync(), greaterThan(0));
    });

    test('2. Benchmark manifest parsing and Invariant verification against Ground Truth', () {
      final manifestFile = File('tool/receipt_benchmark/manifest.json');
      expect(manifestFile.existsSync(), isTrue);

      final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final samples = manifest['samples'] as List<dynamic>;

      int totalEvaluated = 0;
      int abnValidatedCount = 0;
      int gstInvariantPassedCount = 0;

      for (final sample in samples) {
        final expectedAbn = sample['expected_abn'] as String;
        final expectedTotal = (sample['expected_total'] as num).toDouble();
        final expectedGst = (sample['expected_gst'] as num).toDouble();

        // 1. Verify Mod-89 check on Ground Truth ABNs
        final isAbnValid = AustralianTaxValidator.isValidAbn(expectedAbn);
        expect(isAbnValid, isTrue, reason: 'Ground truth ABN $expectedAbn must pass Mod-89');
        if (isAbnValid) abnValidatedCount++;

        // 2. Verify GST Invariant on Ground Truth numbers
        final isGstConsistent = AustralianTaxValidator.isGstConsistent(expectedTotal, expectedGst, tolerance: 0.15);
        expect(isGstConsistent, isTrue, reason: 'Ground truth GST $expectedGst must reconcile with Total $expectedTotal');
        if (isGstConsistent) gstInvariantPassedCount++;

        totalEvaluated++;
      }

      expect(totalEvaluated, equals(samples.length));
      expect(abnValidatedCount, equals(samples.length));
      expect(gstInvariantPassedCount, equals(samples.length));
    });

    test('3. Evaluates degraded text parsing with OCR character confusion repair', () {
      // Degraded text with 'O' instead of '0', 'B' instead of '8', 'l' instead of '1'
      const smudgedAmpolText = '''
AMPOL MASCOT
AMPOL AUSTRALIA PETROLEUM PTY LTD
ABN l7 OOO O32 l28
TOTAL AUD \$129.OO
INCLUDES GST \$11.73
18/11/2026
''';

      final result = service.analyseText(smudgedAmpolText);

      expect(result.amount, equals(129.00));
      expect(result.gstAmount, equals(11.73));
      // Repaired ABN: 17 000 032 128
      expect(result.abn, equals('17 000 032 128'));
      expect(result.evidence, contains('abn_ocr_repaired'));
      expect(result.evidence, contains('gst_invariant_match'));
      expect(result.category, equals(ExpenseCategory.fuel));
      expect(result.isHighConfidence, isTrue);
    });

    test('4. Correctly flags mixed personal convenience items (Ice Break / Chocolate) on fuel dockets', () {
      const mixedSevenElevenText = '''
7-ELEVEN ALEXANDRIA
7-ELEVEN STORES PTY LTD
ABN 48 005 299 427
19/11/2026
UNLEADED 91 \$77.00
ICE BREAK 500ML ICED COFFEE \$4.50
TOTAL AUD \$81.50
INCL GST \$7.41
''';

      final result = service.analyseText(mixedSevenElevenText);

      expect(result.hasMixedItems, isTrue);
      expect(result.evidence, contains('mixed_items'));
      // Under ATO rules, mixed items must NOT auto-pass as high-confidence without review
      expect(result.isHighConfidence, isFalse);
    });
  });
}
