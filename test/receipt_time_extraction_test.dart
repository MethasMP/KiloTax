import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('ReceiptIntelligenceService Time Extraction & AM/PM Precision Tests', () {
    const service = ReceiptIntelligenceService();

    test('Extracts 12-hour format with PM correctly (e.g. 10:42 PM)', () {
      const receiptText = '''
        AMPOL PETROLEUM
        ALEXANDRIA NSW
        DATE: 24/10/2026 10:42 PM
        PUMP 04 UNLEADED
        TOTAL: \$85.50
        GST INCL: \$7.77
      ''';

      final result = service.analyseText(receiptText);
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(24));
      expect(result.date.hour, equals(22)); // 10 PM -> 22
      expect(result.date.minute, equals(42));
    });

    test('Extracts 12-hour format with AM correctly (e.g. 08:15 AM)', () {
      const receiptText = '''
        BUNNINGS WAREHOUSE
        MASCOT NSW
        28-Oct-2026 08:15:30 AM
        TOTAL AUD \$142.00
      ''';

      final result = service.analyseText(receiptText);
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(28));
      expect(result.date.hour, equals(8));
      expect(result.date.minute, equals(15));
    });

    test('Extracts 24-hour POS format correctly (e.g. TIME 14:35)', () {
      const receiptText = '''
        BP CONNECT
        DATE 15/09/2026
        TIME 14:35:12
        TOTAL \$60.00
      ''';

      final result = service.analyseText(receiptText);
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(9));
      expect(result.date.day, equals(15));
      expect(result.date.hour, equals(14));
      expect(result.date.minute, equals(35));
    });
  });
}
