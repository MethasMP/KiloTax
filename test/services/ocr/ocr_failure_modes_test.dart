import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/receipt_ocr_engine.dart';
import 'package:kiloclaim/services/ocr/spatial_receipt_parser.dart';

void main() {
  const service = ReceiptIntelligenceService();

  group('OCR Blind Spots & Failure Modes Gauntlet', () {
    test('1. EFTPOS Surcharge / Tip line is mistaken for Total or corrupts Settlement', () {
      // In Australian pubs/cafes/petrol, an EFTPOS surcharge (e.g. 1.5% or $0.75)
      // appears under TOTAL, followed by TOTAL AUD or EFTPOS TOTAL.
      // Often other OCRs grab the surcharge ($0.75) as the total, or fail to pick the actual settlement ($50.75).
      const rawText = '''
7-ELEVEN BERWICK
SUBTOTAL \$50.00
CARD SURCHARGE \$0.75
TOTAL \$50.75
CHANGE \$0.00
''';
      final res = service.analyseText(rawText);
      expect(res.amount, 50.75, reason: 'Must pick Total/Settlement instead of Surcharge \$0.75 or Subtotal \$50.00');
    });

    test('2. Cash docket "CHANGE / TENDERED" mistakenly picked as Total amount', () {
      // In cash payments:
      // TOTAL $42.50
      // CASH $50.00
      // CHANGE $7.50
      // Many OCRs pick $50.00 (Cash given) or $7.50 (Change) instead of $42.50.
      const rawText = '''
BP CONNECT
TOTAL \$42.50
CASH TENDERED \$50.00
CHANGE \$7.50
''';
      final res = service.analyseText(rawText);
      expect(res.amount, 42.50, reason: 'Must not grab Cash Tendered or Change amount');
    });

    test('3. Date with dots separator (e.g. 14.11.2026 or 14.11.26) common in EFTPOS slips', () {
      const rawText = '''
CALTEX WOOLWORTHS
DATE: 14.11.2026 15:30
TOTAL \$88.00
''';
      final res = service.analyseText(rawText);
      expect(res.parsedDate, isNotNull, reason: 'Dot-separated dates like 14.11.2026 must be recognized');
      expect(res.date.day, 14);
      expect(res.date.month, 11);
      expect(res.date.year, 2026);
    });

    test('4. Spatial column misalignment: "TOTAL AUD" with price in adjacent column', () {
      // Bounding box horizontal alignment
      final blocks = [
        ReceiptOcrBlock(page: 1, text: 'TOTAL AUD', bounds: [50, 200, 150, 220]),
        ReceiptOcrBlock(page: 1, text: '\$120.50', bounds: [300, 201, 380, 222]),
      ];
      final spatial = const SpatialReceiptParser().parse(blocks);
      expect(spatial.totalAmount, 120.50);

      final result = service.analyseText('TOTAL AUD  \$120.50', blocks: blocks);
      expect(result.amount, 120.50);
    });

    test('5. Non-deductible personal snacks on fuel docket triggers hasMixedItems', () {
      const rawText = '''
AMPOL PETROLEUM
UNLEADED 91   \$75.00
ICE BREAK 500ML \$4.50
TOTAL \$79.50
''';
      final res = service.analyseText(rawText);
      expect(res.hasMixedItems, isTrue, reason: 'Ice Break must be flagged for quarantine');
    });
  });
}
