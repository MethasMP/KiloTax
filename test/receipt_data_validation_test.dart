import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('Receipt Data Validation & Security Guardrails', () {
    late ReceiptIntelligenceService service;

    setUp(() {
      service = ReceiptIntelligenceService();
    });

    test('Sanitizes thermal printer OCR noise (¥ converted to %, PREMOBA to PREM98)', () {
      const noisyText = '''
Ampol Retail Pty Ltd
ABN 64 000 175 342
09 PREMOBA 23.69L @ \$2.339/L \$ 55.41 A
10.00 ¥ GST A \$ 4.95
TOTAL AUD \$ 63.96
19/10/2023
''';
      final result = service.analyseText(noisyText);
      expect(result.amount, equals(63.96));
      expect(result.gstAmount, equals(4.95));
      expect(result.category.name, equals('fuel'));
    });

    test('Date Guardrail: Rejects future dates (e.g. year 2099)', () {
      const futureText = '''
Ampol Retail Pty Ltd
ABN 64 000 175 342
TOTAL AUD \$ 50.00
Date: 25/12/2099
''';
      final result = service.analyseText(futureText);
      expect(result.date.year, isNot(equals(2099)));
      expect(result.date.year, equals(DateTime.now().year));
    });

    test('Date Guardrail: Rejects dates older than ATO 5-year limit (e.g. year 2010)', () {
      const expiredText = '''
Ampol Retail Pty Ltd
ABN 64 000 175 342
TOTAL AUD \$ 50.00
Date: 15/05/2010
''';
      final result = service.analyseText(expiredText);
      expect(result.date.year, isNot(equals(2010)));
      expect(result.date.year, equals(DateTime.now().year));
    });

    test('Date Guardrail: Accepts valid tax invoice within last 5 years', () {
      const validText = '''
Ampol Retail Pty Ltd
ABN 64 000 175 342
TOTAL AUD \$ 50.00
Date: 19/10/2023
''';
      final result = service.analyseText(validText);
      expect(result.date.year, equals(2023));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(19));
    });

    test('ABN Guardrail: Must be 11 numeric digits formatted XX XXX XXX XXX without illegal symbols', () {
      const abnText = '''
Ampol Retail Pty Ltd
ABN: 64-000-175-342
TOTAL AUD \$ 50.00
19/10/2023
''';
      final result = service.analyseText(abnText);
      expect(result.abn, equals('64 000 175 342'));
      final digits = result.abn!.replaceAll(' ', '');
      expect(RegExp(r'^\d{11}$').hasMatch(digits), isTrue);
    });

    test('Total & GST Sanity: GST cannot exceed Total amount', () {
      const validExpense = '''
Bunnings Warehouse
ABN: 11 000 123 456
TOTAL \$ 110.00
GST \$ 10.00
15/01/2024
''';
      final result = service.analyseText(validExpense);
      expect(result.amount, equals(110.00));
      expect(result.gstAmount, equals(10.00));
      expect(result.gstAmount! <= result.amount, isTrue);
    });
  });
}
