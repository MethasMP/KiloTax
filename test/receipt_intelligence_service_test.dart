import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('ReceiptIntelligenceService', () {
    const service = ReceiptIntelligenceService();

    test(
        'extracts fuel receipts with total, merchant, date, and high confidence',
        () {
      final result = service.analyseText('''
BP Connect Mascot
Tax Invoice
ABN 12 345 678 901
Diesel Pump 04
Litres 78.20
Total AUD \$142.50
11/09/2026
''');

      expect(result.category, ExpenseCategory.fuel);
      expect(result.merchant, anyOf(equals('Bp'), startsWith('Bp'), startsWith('BP')));
      expect(result.amount, 142.50);
      expect(result.date, DateTime(2026, 9, 11));
      expect(result.isHighConfidence, isTrue);
    });

    test('classifies EV charging receipts as Fuel & Oil running cost', () {
      final result = service.analyseText('''
Chargefox
EV charging session
Energy 42.8 kWh
Amount paid \$31.72
12/09/2026
''');

      expect(result.category, ExpenseCategory.fuel);
      expect(result.merchant, 'Chargefox');
      expect(result.amount, 31.72);
      expect(result.confidence, greaterThanOrEqualTo(0.78));
    });

    test('prefers maintenance when oil or tyre terms appear on service bills',
        () {
      final result = service.analyseText('''
Bridgestone Select
Wheel alignment
Tyre puncture repair
Engine oil filter
Grand Total \$289.00
10/09/2026
''');

      expect(result.category, ExpenseCategory.maintenanceTyres);
      expect(result.merchant, startsWith('Bridgestone'));
      expect(result.amount, 289.00);
      expect(result.isHighConfidence, isTrue);
    });

    test('does not treat generic oil-related maintenance as fuel', () {
      final result = service.analyseText('''
Shell Service Centre
Tax Invoice
Engine oil 5W-30
Oil filter
Labour
Total \$186.40
12/09/2026
''');

      expect(result.category, ExpenseCategory.maintenanceTyres);
      expect(result.evidence, contains('engine oil context'));
      expect(result.evidence, isNot(contains('fuel product')));
    });

    test('lowers confidence when fuel and maintenance evidence conflict', () {
      final result = service.analyseText('''
Ampol Foodary
Diesel Pump 02
Engine oil 5W-30
Total \$92.15
12/09/2026
''');

      expect(result.category, ExpenseCategory.fuel);
      expect(result.confidence, lessThan(0.78));
      expect(result.isHighConfidence, isFalse);
    });
  });
}
