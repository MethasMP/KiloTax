import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('ReceiptIntelligenceService isLikelyPersonalItem', () {
    const service = ReceiptIntelligenceService();

    final testCases = [
      'ice break',
      'ICE BREAK 500ML',
      'coke',
      'Diet Coke 375ml',
      'coca cola',
      'coca cola zero',
      'snack',
      'chips',
      'Smiths Chips',
      'chocolate',
      'Cadbury Chocolate Bar',
      'drink',
      'Soft drink',
      'coffee',
      'Flat white coffee',
      'confectionery',
      'sandwich',
      'Ham & Cheese Sandwich',
      'pie',
      'Four\'N Twenty Meat Pie',
      'energy drink',
      'red bull',
      'Red Bull 250ml can',
    ];

    for (final item in testCases) {
      test('identifies "$item" as likely personal item', () {
        expect(service.isLikelyPersonalItem(item), isTrue);
      });
    }

    final nonPersonalCases = [
      'Unleaded 91',
      'Diesel',
      'Prem98 Fuel',
      'Engine Oil 5W-30',
      'Brake Fluid',
      'Tire repair',
      'Car wash',
      '',
      '   ',
    ];

    for (final item in nonPersonalCases) {
      test('does not identify "$item" as personal item', () {
        expect(service.isLikelyPersonalItem(item), isFalse);
      });
    }
  });
}
