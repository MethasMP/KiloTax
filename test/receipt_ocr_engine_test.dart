import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  final response = {
    'engine': 'paddleocr',
    'version': '3.3.2/PP-OCRv5/en',
    'text': 'TOTAL 60.50',
    'extractedAt': '2026-11-12T00:00:00Z',
    'blocks': [
      {
        'page': 1,
        'text': 'TOTAL 60.50',
        'bounds': [0, 1, 20, 30],
        'score': 0.98
      }
    ]
  };
  test('visual rows associate GST with its amount across OCR columns', () {
    final List<ReceiptOcrBlock> blocks = [
      ReceiptOcrBlock(page: 1, text: 'SYNTHETIC FUEL SHOP', bounds: [52.0, 59.0, 539.0, 104.0]),
      ReceiptOcrBlock(page: 1, text: 'TAX INVOICE', bounds: [49.0, 159.0, 337.0, 205.0]),
      ReceiptOcrBlock(page: 1, text: 'ABN 12 345 678 901', bounds: [50.0, 258.0, 516.0, 306.0]),
      ReceiptOcrBlock(page: 1, text: '10/11/2026', bounds: [51.0, 359.0, 312.0, 406.0]),
      ReceiptOcrBlock(page: 1, text: 'Unleaded fuel', bounds: [52.0, 460.0, 387.0, 504.0]),
      ReceiptOcrBlock(page: 1, text: '\$60.50', bounds: [427.0, 456.0, 592.0, 508.0]),
      ReceiptOcrBlock(page: 1, text: 'GST included', bounds: [50.0, 557.0, 362.0, 606.0]),
      ReceiptOcrBlock(page: 1, text: '\$5.50', bounds: [452.0, 554.0, 594.0, 611.0]),
      ReceiptOcrBlock(page: 1, text: 'TOTAL AUD', bounds: [49.0, 658.0, 287.0, 707.0]),
      ReceiptOcrBlock(page: 1, text: '\$60.50', bounds: [426.0, 654.0, 593.0, 710.0]),
      ReceiptOcrBlock(page: 1, text: 'PAID VISA', bounds: [49.0, 758.0, 287.0, 807.0]),
      ReceiptOcrBlock(page: 1, text: '\$60.50', bounds: [426.0, 755.0, 593.0, 811.0]),
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
  test('default stays offline and unset Paddle fails before upload', () {
    expect(ReceiptOcrEngineFactory.create(), isA<MlKitReceiptOcrEngine>());
    expect(() => ReceiptOcrEngineFactory.create(usePaddle: true, endpoint: ''),
        throwsStateError);
    expect(
        () => PaddleReceiptOcrEngine(
            endpoint: Uri.parse('http://remote.test/ocr')),
        throwsArgumentError);
  });
  test('validates bounds, score, version and extraction time', () {
    final result = PaddleReceiptOcrEngine.parseResponse(response);
    expect(result.blocks.single.score, 0.98);
    expect(result.extractedAt.isUtc, isTrue);
    for (final invalid in [
      {...response, 'version': ''},
      {...response, 'extractedAt': 'nonsense'},
      {
        ...response,
        'blocks': [
          {
            'page': 1,
            'text': 'x',
            'bounds': [2, 0, 1, 3],
            'score': 2
          }
        ]
      }
    ]) {
      expect(() => PaddleReceiptOcrEngine.parseResponse(invalid),
          throwsFormatException);
    }
  });
  test('explicit upload transmits bytes and token and propagates errors',
      () async {
    final directory = await Directory.systemTemp.createTemp('ocr-test');
    final file =
        await File('${directory.path}/receipt.png').writeAsBytes([1, 2, 3]);
    addTearDown(() => directory.delete(recursive: true));
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.bodyBytes, [1, 2, 3]);
      return http.Response(jsonEncode(response), 200);
    });
    final engine = PaddleReceiptOcrEngine(
        endpoint: Uri.parse('http://localhost/ocr'),
        token: 'test-token',
        client: client);
    expect((await engine.recognizeFile(file.path)).text, 'TOTAL 60.50');
    final failure = PaddleReceiptOcrEngine(
        endpoint: Uri.parse('http://localhost/ocr'),
        client: MockClient(
            (_) async => http.Response('secret internal message', 503)));
    await expectLater(
        failure.recognizeFile(file.path), throwsA(isA<HttpException>()));
    final timeout = PaddleReceiptOcrEngine(
        endpoint: Uri.parse('http://localhost/ocr'),
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('{}', 200);
        }));
    await expectLater(
        timeout.recognizeFile(file.path), throwsA(isA<Exception>()));
  });
}
