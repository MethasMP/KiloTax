import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/thermal_receipt_image_preprocessor.dart';

void main() {
  group('Context-Assisted Receipt Intelligence & Thermal Preprocessing', () {
    const service = ReceiptIntelligenceService();

    test('1. Fuses external Trip/Geofence context to lock merchant and valid ABN even on damaged receipt', () {
      // Degraded receipt text where merchant and ABN are partially illegible or cropped
      final degradedText = '''
TAX INVOICE
[SMUDGE] ... 085 616
TOTAL AUD \$88.00
INCL GST \$8.00
14/11/2026
''';

      // We pass the context hints derived from the vehicle's recent stop at Bunnings
      final result = service.analyseText(
        degradedText,
        contextMerchantHint: 'Bunnings Warehouse',
        contextAbnHint: '53 004 085 616',
        contextCategoryHint: ExpenseCategory.toolsMaterials,
      );

      expect(result.merchant, equals('Bunnings Warehouse'));
      expect(result.abn, equals('53 004 085 616'));
      expect(result.category, equals(ExpenseCategory.toolsMaterials));
      expect(result.amount, equals(88.00));
      expect(result.evidence, contains('merchant_context_fused'));
      expect(result.evidence, contains('abn_context_fused'));
      expect(result.evidence, contains('gst_invariant_match'));
      expect(result.isHighConfidence, isTrue);
    });

    test('2. ThermalReceiptImagePreprocessor handles missing or invalid files gracefully without throwing', () async {
      const preprocessor = ThermalReceiptImagePreprocessor();
      final nonExistentPath = '/tmp/non_existent_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputPath = '/tmp/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await preprocessor.enhanceThermalReceipt(
        inputPath: nonExistentPath,
        outputPath: outputPath,
      );

      // Falls back safely to input path
      expect(result, equals(nonExistentPath));
    });
  });
}
