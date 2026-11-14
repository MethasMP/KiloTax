import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  test('Flutter Paddle provider reads a synthetic image through the real local service', () async {
    final engine = PaddleReceiptOcrEngine(endpoint: Uri.parse('http://127.0.0.1:8765/ocr'),
      token: 'receipt-local-smoke-only', timeout: const Duration(minutes: 4));
    final extraction = await engine.recognizeFile('tool/paddle_ocr/fixtures/synthetic_fuel.png');
    final result = const ReceiptIntelligenceService().analyseText(extraction.text);
    expect(extraction.engine, 'paddleocr');
    expect(extraction.blocks, isNotEmpty);
    expect(result.amount, 60.50);
    expect(result.gstAmount, 5.50);
    expect(result.currency, 'AUD');
    expect(result.parsedDate, DateTime(2026,11,10));
  }, timeout: const Timeout(Duration(minutes: 5)), skip: !const bool.fromEnvironment('RUN_PADDLE_HTTP'));
}
