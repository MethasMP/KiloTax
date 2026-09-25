import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('NASA-Grade Consensus Engine & Australian Fuel Receipts', () {
    const service = ReceiptIntelligenceService();
    const auditService = ReceiptAuditService();

    test('1. Resolves fuel discounts (Subtotal - 4c Discount == Final Settlement)', () {
      final text = '''
Coles Express Mascot
Tax Invoice
ABN: 44 004 089 936
Diesel 80.00 L @ \$2.000/L      \$160.00
Coles 4c Fuel Discount        -\$3.20
TOTAL AUD                     \$156.80
INCLUDES GST \$14.25
EFTPOS DEBIT                  \$156.80
12/09/2026 14:30
''';

      final result = service.analyseText(text);

      // Must select the net settlement amount ($156.80), NOT the raw subtotal ($160.00)
      expect(result.amount, equals(156.80));
      expect(result.category, equals(ExpenseCategory.fuel));
      expect(result.gstAmount, equals(14.25));
      expect(result.evidence, contains('gst_invariant_match'));
      expect(result.isHighConfidence, isTrue);
    });

    test('2. Recovers from smudged OCR characters with Levenshtein fuzzy matching', () {
      // "T0TAL AUD" and "EFTP0S" smudged
      final text = '''
BP Connect Kew
Tax Invoice
Diesel Pump 02
Qty 45.00 L
T0TAL AUD \$98.50
EFTP0S \$98.50
11/09/2026
''';

      final result = service.analyseText(text);

      expect(result.amount, equals(98.50));
      expect(result.merchant, anyOf(equals('Bp'), startsWith('Bp'), startsWith('BP')));
      expect(result.category, equals(ExpenseCategory.fuel));
    });

    test('3. Cross-validates settlement using Australian GST Invariant (Total ≈ GST * 11)', () {
      final text = '''
Sydney Tools Alexandria
Tax Invoice ABN 12 345 678 901
DeWalt Drill Set
TOTAL \$220.00
INCLUDES GST \$20.00
PAID VISA \$220.00
10/09/2026
''';

      final result = service.analyseText(text);

      expect(result.amount, equals(220.00));
      expect(result.gstAmount, equals(20.00));
      expect(result.evidence, contains('gst_invariant_match'));
    });

    test('4. Handles bundled in-store items (Pie + Fuel) prioritizing bottom-up settlement', () {
      final text = '''
7-Eleven Richmond
Tax Invoice
Unleaded 91 50.00 L    \$95.00
Four'N Twenty Pie       \$5.50
Barista Coffee          \$4.50
SUBTOTAL              \$105.00
TOTAL AUD             \$105.00
EFTPOS                \$105.00
09/09/2026
''';

      final result = service.analyseText(text);

      // Must capture the true credit card debit of $105.00, not just the fuel item
      expect(result.amount, equals(105.00));
      expect(result.merchant, startsWith('7-Eleven'));
    });

    test('5. ReceiptAuditService tags gst_split_verified into audit trail', () async {
      final ocrResult = ReceiptOcrResult(
        merchant: 'Ampol',
        amount: 110.00,
        gstAmount: 10.00,
        date: DateTime(2026, 9, 12),
        category: ExpenseCategory.fuel,
        confidence: 0.95,
        evidence: const ['total:110.00', 'gst:10.00', 'gst_invariant_match'],
        rawText: 'Ampol Total \$110.00 GST \$10.00',
      );

      final auditTrail = await auditService.create(
        merchant: 'Ampol',
        amount: 110.00,
        category: ExpenseCategory.fuel,
        imagePath: null,
        ocrResult: ocrResult,
      );

      expect(auditTrail.ocrGstAmount, equals(10.00));
      expect(auditTrail.ocrEvidence, contains('gst_split_verified'));
    });
  });
}
