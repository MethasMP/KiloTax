import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('100% Brand-Agnostic Extraction Architecture Tests', () {
    const service = ReceiptIntelligenceService();
    const auditService = ReceiptAuditService();

    test('1. Extracts independent Outback Roadhouse fuel bill without known brands', () {
      final text = '''
Nullarbor Roadhouse Petrol Pty Ltd
Tax Invoice
ABN: 72 109 448 331
Diesel Pump 01
Litres 110.50 L @ \$2.15/L
TOTAL AUD \$237.58
INCLUDES GST \$21.60
EFTPOS \$237.58
12/09/2026
''';

      final result = service.analyseText(text);

      expect(result.merchant, equals('Nullarbor Roadhouse Petrol'));
      expect(result.category, equals(ExpenseCategory.fuel));
      expect(result.amount, equals(237.58));
      expect(result.abn, equals('72 109 448 331'));
      expect(result.evidence, contains('abn:72 109 448 331'));
      expect(result.isHighConfidence, isTrue);
    });

    test('2. Extracts local independent mechanic invoice with repairs & tyres', () {
      final text = '''
Kev & Sons Mechanical Repairs
Tax Invoice
Aust Bus No: 53 004 085 616
4x All-Terrain Tyres Replacement
Wheel Alignment & Balance
Front Brake Pads Labour
TOTAL \$1,450.00
INCLUDES GST \$131.82
PAID VISA \$1,450.00
10/09/2026
''';

      final result = service.analyseText(text);

      expect(result.merchant, equals('Kev & Sons Mechanical Repairs'));
      expect(result.category, equals(ExpenseCategory.maintenanceTyres));
      expect(result.amount, equals(1450.00));
      expect(result.abn, equals('53 004 085 616'));
      expect(result.isHighConfidence, isTrue);
    });

    test('3. Statutory ABN extracted and mapped into ReceiptAuditTrail', () async {
      final ocrResult = service.analyseText('''
Outback Tyre Service
Tax Invoice ABN: 26 008 672 179
Tyre repair \$88.00
TOTAL \$88.00
11/09/2026
''');

      final audit = await auditService.create(
        merchant: ocrResult.merchant,
        amount: ocrResult.amount,
        category: ocrResult.category,
        imagePath: null,
        ocrResult: ocrResult,
      );

      expect(audit.ocrAbn, equals('26 008 672 179'));
      expect(audit.ocrMerchant, equals('Outback Tyre Service'));
      expect(audit.ocrCategory, equals('maintenanceTyres'));
    });
  });
}
