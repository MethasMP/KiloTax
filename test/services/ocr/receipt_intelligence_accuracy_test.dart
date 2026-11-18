import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';

void main() {
  group('ReceiptIntelligenceService Accuracy & Consensus Engine', () {
    late ReceiptIntelligenceService service;

    setUp(() {
      service = const ReceiptIntelligenceService();
    });

    test('Bunnings receipt: High confidence (>=0.95), valid ABN mod-89, consistent GST', () {
      // Bunnings Warehouse: ABN 26 008 672 179
      // Total $152.90, GST $13.90 (13.90 * 11 = 152.90)
      const rawText = '''
BUNNINGS WAREHOUSE
BUNNINGS GROUP LIMITED
ABN 26 008 672 179
CHATSWOOD NSW
DATE: 18/11/2026
TAX INVOICE
TIMBER PINE 90X45 2.4M   \$85.00
DEWALT DRILL BIT SET     \$54.00
SUBTOTAL                \$139.00
INCLUDES GST 10%         \$13.90
TOTAL AUD               \$152.90
EFT POS - VISA
''';

      final result = service.analyseText(rawText);

      expect(result.amount, equals(152.90));
      expect(result.gstAmount, equals(13.90));
      expect(result.abn, equals('26 008 672 179'));
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.isHighConfidence, isTrue);
      expect(result.evidence, contains('abn_mod89_valid'));
      expect(result.evidence, contains('gst_invariant_match'));
    });

    test('BP fuel receipt: High confidence (>=0.95), valid ABN mod-89, consistent GST', () {
      // BP Australia: ABN 53 004 085 616
      // Total $88.55, GST $8.05 (8.05 * 11 = 88.55)
      const rawText = '''
BP CONNECT
BP AUSTRALIA PTY LTD
ABN: 53 004 085 616
123 HIGH ST, MELBOURNE
TAX INVOICE: BP-98124
18/11/2026 08:30
PUMP 04
UNLEADED 91   45.41L @ 1.95   \$88.55
TOTAL AUD:                    \$88.55
INCL GST 10%                   \$8.05
VISA ************1234
AUTH: 827162
''';

      final result = service.analyseText(rawText);

      expect(result.category, equals(ExpenseCategory.fuel));
      expect(result.amount, equals(88.55));
      expect(result.gstAmount, equals(8.05));
      expect(result.abn, equals('53 004 085 616'));
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.isHighConfidence, isTrue);
    });

    test('Shell / Viva Energy: Auto-repairs corrupted Total when GST is crisp', () {
      // Viva Energy (Shell): ABN 46 004 610 459
      // GST is clearly \$10.00, but Total OCR dropped decimal: '11000' or blurry OCR '11O.OO'
      const rawText = '''
SHELL SERVICE STATION
VIVA ENERGY AUSTRALIA
ABN: 46 004 610 459
TAX INVOICE
DATE: 12/11/2026
V-POWER DIESEL   \$11000
GST INCLUDED:     \$10.00
TOTAL:           \$11000
''';

      final result = service.analyseText(rawText);

      // Math invariant deduceTotalFromGst(10.0) -> 110.00
      expect(result.amount, equals(110.00));
      expect(result.gstAmount, equals(10.00));
      expect(result.abn, equals('46 004 610 459'));
      expect(result.evidence, contains('total_repaired_from_gst:110.00'));
      expect(result.confidence, greaterThanOrEqualTo(0.95));
    });

    test('Rejection of invalid candidate ABNs (phone numbers, order barcodes, failing mod-89)', () {
      // Text with an arbitrary 11 digit number labeled as ABN that fails mod-89
      const rawText = '''
7-ELEVEN AUSTRALIA
TAX INVOICE
ABN: 61 412 345 678
PHONE: 03 9876 5432
ORDER NO: 99182374615
DATE: 15/11/2026
TOTAL AUD \$22.00
INCLUDES GST \$2.00
''';

      final result = service.analyseText(rawText);

      // The candidate ABN 61 412 345 678 must be rejected by mod-89
      expect(result.abn, isNull);
      expect(result.evidence, contains('abn_mod89_rejected:61412345678'));
    });

    test('Spatial block integration: picks up horizontal bounding box values if provided', () {
      // Simulating blocks where text lines are physically disjoint
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: '7-ELEVEN STORES PTY LTD',
          bounds: [50.0, 50.0, 300.0, 75.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'ABN: 48 005 299 427', // Valid 7-Eleven ABN
          bounds: [50.0, 80.0, 250.0, 105.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'DATE: 10/11/2026',
          bounds: [50.0, 110.0, 200.0, 135.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL AUD',
          bounds: [50.0, 300.0, 150.0, 325.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$66.00',
          bounds: [350.0, 301.0, 420.0, 324.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'INCLUDES GST',
          bounds: [50.0, 330.0, 180.0, 355.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$6.00',
          bounds: [350.0, 331.0, 400.0, 354.0],
        ),
      ];

      final rawText = blocks.map((b) => b.text).join('\n');
      final result = service.analyseText(rawText, blocks: blocks);

      expect(result.amount, equals(66.00));
      expect(result.gstAmount, equals(6.00));
      expect(result.abn, equals('48 005 299 427'));
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.evidence, contains('spatial_consensus_match'));
    });
  });
}
