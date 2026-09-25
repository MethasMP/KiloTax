import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  test('Executes ReceiptIntelligenceService on actual user uploaded Ampol receipt', () {
    const ocrText = '''
Ampol Retail Pty Ltd
T/As Ampol Foodary Sydney
123 George Street, Sydney NSW 2000 Ph 02
9123 4567
“A” Denotes GST Inclusive Item
ABN: 64 000 175 342
>>>>>>>>>29>>>> Tax Invoice <<<<<<<<ecccce
09 PREMOBA 23.69L @ \$2.339/L \$ 55.41 A
Discount 0.040/L \$  0.95-A
COCA COLA 6OOML \$ 4.50 B
2 x SNICKERS 506 \$ 5.00 B
Store No.:
1800
Total includes GST \$ 63.96
CBA Saving \$ 63.96
10.00 ¥ GST A \$ 4.95
TERMINAL: 02874700
REFERENCE: 816059
CARD NO: 7263(c)
PAN SEQ NO: 00
AID: 4000000004 1010
TVR: 00000008001
TSI: 0000
ATC: 00181
ARGC: ‘3ADOTE740AF 14BBB
PURCHASE \$ 63.96
TOTAL AUD \$ 63.96
19/10/23 09:22
MASTERCARD:
AUTH NO.; 071837
APPROVED 00
Your next fuel saving offer in your
account will expire on 01/11/2023
Woolworths Rewards card accepted
T&Cs apply. ampol.com.au
Card: 9344640303253
eT
990107290202310190000000054.. 460
Date Time Num POS CNo PSNo
19/10/23 09:22 10729 01 10385 777
/| AMPOL
Store ID: 44414
How did we do today? Let us know via
ampol feedback@ampo | .com.au
‘or call us on 1800 240 398
''';

    final service = ReceiptIntelligenceService();
    final result = service.analyseText(ocrText);

    print('\n======================================================');
    print('KILOTAX ALGORITHM EXTRACTION REPORT (ZERO AI)');
    print('======================================================');
    print('Merchant Name   : ${result.merchant}');
    print('ABN Number      : ${result.abn}');
    print('Date Incurred   : ${result.date.toIso8601String().split('T').first}');
    print('Total Amount    : \$${result.amount.toStringAsFixed(2)}');
    print('GST Extracted   : \$${result.gstAmount?.toStringAsFixed(2)}');
    print('Tax Category    : ${result.category.displayName} (${result.category.name})');
    print('Claim Basket    : ${result.category.isDirectlyDeductibleByDefault ? "Direct Work Deduction (100%)" : "Car Running Cost (Logbook Scaled)"}');
    print('Confidence Score: ${(result.confidence * 100).toStringAsFixed(1)}% (isHighConfidence: ${result.isHighConfidence})');
    print('------------------------------------------------------');
    print('Settlement & Evidence Chain:');
    for (final ev in result.evidence) {
      print('  • $ev');
    }
    print('======================================================\n');

    expect(result.amount, equals(63.96));
    expect(result.abn, contains('64 000 175 342'));
    expect(result.merchant, contains('Ampol'));
  });
}
