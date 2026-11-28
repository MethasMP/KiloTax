import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/ocr/receipt_ocr_engine.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';

void main() {
  test('visual rows associate GST with its amount across OCR columns', () {
    final blocks = [
      ReceiptOcrBlock(page: 1, text: 'SAMPLE FUEL', bounds: [10, 10, 100, 25]),
      ReceiptOcrBlock(page: 1, text: 'DATE: 10/11/2026', bounds: [10, 30, 120, 45]),
      ReceiptOcrBlock(page: 1, text: 'SUBTOTAL', bounds: [10, 50, 60, 65]),
      ReceiptOcrBlock(page: 1, text: '55.00', bounds: [120, 50, 150, 65]),
      ReceiptOcrBlock(page: 1, text: 'GST', bounds: [10, 70, 40, 85]),
      ReceiptOcrBlock(page: 1, text: '5.50', bounds: [120, 70, 150, 85]),
      ReceiptOcrBlock(page: 1, text: 'TOTAL AUD', bounds: [10, 90, 80, 105]),
      ReceiptOcrBlock(page: 1, text: '60.50', bounds: [120, 90, 150, 105]),
    ];
    final parsed = const ReceiptIntelligenceService()
        .analyseText(ReceiptReadingOrder.assemble(blocks));
    expect(parsed.amount, 60.50);
    expect(parsed.gstAmount, 5.50);
    expect(parsed.currency, 'AUD');
    expect(parsed.parsedDate, DateTime(2026, 11, 10));
  });

  test('visual rows never merge adjacent receipt lines or separate pages', () {
    final text = ReceiptReadingOrder.assemble([
      ReceiptOcrBlock(page: 2, text: 'NEXT PAGE', bounds: [0, 0, 20, 10]),
      ReceiptOcrBlock(page: 1, text: 'GST', bounds: [0, 0, 20, 10]),
      ReceiptOcrBlock(page: 1, text: '5.50', bounds: [40, 0, 60, 10]),
      ReceiptOcrBlock(page: 1, text: 'TOTAL', bounds: [0, 12, 20, 22]),
    ]);
    expect(text, 'GST  5.50\nTOTAL\nNEXT PAGE');
  });

  test('ReceiptOcrEngineFactory creates offline ML Kit engine', () {
    expect(ReceiptOcrEngineFactory.create(), isA<MlKitReceiptOcrEngine>());
  });
}
