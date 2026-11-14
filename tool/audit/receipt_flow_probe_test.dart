// Diagnostic probes for the receipt-flow audit. These record current behavior;
// they are not acceptance tests or evidence of OCR accuracy on real images.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_pre_db_validator.dart';

void main() {
  test('record current extraction and audit boundary behavior', () async {
    const parser = ReceiptIntelligenceService();
    const audit = ReceiptAuditService();
    final directory =
        await Directory.systemTemp.createTemp('receipt-flow-probe-');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/not-an-image.jpg')
        .writeAsBytes([1, 2, 3]);
    final text = '''
AMPOL ALEXANDRIA
Tax Invoice
01/11/2026
DIESEL 40L 80.00
CHOCOLATE 10.00
TOTAL AUD 90.00
GST 8.18
EFTPOS 90.00
''';
    final mixed = parser.analyseText(text);
    final validation =
        const ReceiptPreDbValidator().validateAndSanitize(ocrResult: mixed);
    final captured = await audit.create(
        merchant: mixed.merchant,
        amount: mixed.amount,
        category: mixed.category,
        imagePath: file.path,
        ocrResult: mixed);
    final edited = await audit.create(
        merchant: mixed.merchant,
        amount: mixed.amount + 20,
        category: mixed.category,
        imagePath: file.path,
        existingAudit: captured,
        detailsChanged: true);
    await expectLater(
        audit.create(
            merchant: mixed.merchant,
            amount: mixed.amount,
            category: mixed.category,
            imagePath: file.path,
            confirmedByUser: true),
        throwsA(isA<FormatException>()));
    final usd = parser.analyseText(text.replaceAll('AUD', 'USD'));
    final pendingReasons = <String>[
      if (mixed.dateNeedsReview) 'date',
      if (!mixed.amount.isFinite || mixed.amount <= 0) 'amount',
      if (mixed.merchant.isEmpty) 'merchant',
      if (!mixed.isHighConfidence) 'confidence',
      if (!mixed.category.isCarExpense) 'category',
      if (mixed.hasMixedItems) 'mixed items',
      if (!validation.isValid || validation.isVaultOnlyRecommended)
        'validation',
    ];
    expect(pendingReasons, contains('mixed items'));
    expect(usd.isHighConfidence, isFalse);
    expect(edited.correctionReasons, contains('amount corrected'));
    print(const JsonEncoder.withIndent('  ').convert({
      'mixed_receipt': {
        'total': mixed.amount,
        'category': mixed.category.name,
        'confidence': mixed.confidence,
        'batch_gate_issues': pendingReasons
      },
      'usd_receipt': {
        'total': usd.amount,
        'category': usd.category.name,
        'high_confidence': usd.isHighConfidence,
        'currency_field_in_result': usd.currency
      },
      'edited_total': {
        'original_ocr_amount': edited.ocrAmount,
        'current_amount': mixed.amount + 20,
        'correction_reasons': edited.correctionReasons
      },
      'non_image_three_bytes': {'confirmation_status': 'rejected'},
    }));
  });
}
