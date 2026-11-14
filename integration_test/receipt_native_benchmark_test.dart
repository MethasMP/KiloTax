import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native ML Kit recognizes the same labeled synthetic receipt',
      (tester) async {
    const encoded = String.fromEnvironment('RECEIPT_BENCHMARK_IMAGE');
    if (encoded.isEmpty) {
      throw StateError(
          'Supply the labeled synthetic image with RECEIPT_BENCHMARK_IMAGE.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt-native-benchmark.png');
    await file.writeAsBytes(base64Decode(encoded), flush: true);
    try {
      final extraction = await MlKitReceiptOcrEngine().recognizeFile(file.path);
      final parsed =
          const ReceiptIntelligenceService().analyseText(extraction.text);
      print('RECEIPT_NATIVE_RESULT:${jsonEncode({
            'engine': extraction.engine,
            'version': extraction.version,
            'text': extraction.text,
            'extractedAt': extraction.extractedAt.toIso8601String(),
            'blocks': extraction.blocks
                .map((b) => {
                      'page': b.page,
                      'text': b.text,
                      'bounds': b.bounds,
                      'score': b.score
                    })
                .toList(),
          })}');
      expect(extraction.blocks, isNotEmpty);
      expect(parsed.amount, 60.50);
      expect(parsed.gstAmount, 5.50);
      expect(parsed.currency, 'AUD');
      expect(parsed.parsedDate, DateTime(2026, 11, 10));
    } finally {
      await file.delete();
    }
  });
}
