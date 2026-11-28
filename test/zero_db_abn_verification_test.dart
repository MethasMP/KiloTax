import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/ocr/australian_business_register_service.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';

void main() {
  group('Zero-Merchant Database & Statutory ABN Invariant Engine (Item 1)', () {
    const service = ReceiptIntelligenceService();
    const abrService = AustralianBusinessRegisterService();

    test('1. Validates receipt as High Confidence even with ZERO merchant name if valid ABN & GST match', () {
      // In this receipt, the header/merchant name is completely torn off or blacked out,
      // but ABN, GST, and Total are crisp.
      final noMerchantText = '''
TAX INVOICE
ABN 53 004 085 616
TOTAL AUD \$110.00
INCL GST \$10.00
12/11/2026
''';

      final result = service.analyseText(noMerchantText);

      // System does NOT require a local merchant database to approve this tax invoice
      expect(result.abn, equals('53 004 085 616'));
      expect(result.amount, equals(110.00));
      expect(result.gstAmount, equals(10.00));
      expect(result.evidence, contains('abn_mod89_valid'));
      expect(result.evidence, contains('gst_invariant_match'));
      expect(result.isHighConfidence, isTrue);
    });

    test('2. ABR Service formats and resolves verified ABN without local database storage', () async {
      const validBunningsAbn = '53004085616';
      final entity = await abrService.resolveEntityName(rawAbn: validBunningsAbn);

      expect(entity.isVerified, isTrue);
      expect(entity.entityName, equals('ABN 53 004 085 616'));

      // If invalid Mod-89 ABN is supplied:
      final invalidEntity = await abrService.resolveEntityName(rawAbn: '12345678901');
      expect(invalidEntity.isVerified, isFalse);
    });
  });
}
