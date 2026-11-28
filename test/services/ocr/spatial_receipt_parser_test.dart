import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/ocr/receipt_ocr_engine.dart';
import 'package:kiloclaim/services/ocr/spatial_receipt_parser.dart';

void main() {
  group('SpatialReceiptParser', () {
    late SpatialReceiptParser parser;

    setUp(() {
      parser = const SpatialReceiptParser();
    });

    test('extracts Total amount when label and value are on same horizontal line', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL AUD',
          bounds: [50.0, 500.0, 150.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$152.40',
          bounds: [350.0, 502.0, 450.0, 528.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.total, equals('152.40'));
      expect(result.totalAmount, equals(152.40));
    });

    test('extracts GST amount when label and value are horizontally aligned', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'INCLUDES GST 10%',
          bounds: [50.0, 450.0, 200.0, 480.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '13.85',
          bounds: [380.0, 452.0, 450.0, 478.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.gst, equals('13.85'));
      expect(result.gstAmount, equals(13.85));
    });

    test('extracts ABN when label is followed horizontally by 11-digit ABN', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'ABN:',
          bounds: [60.0, 120.0, 120.0, 145.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '26 008 672 179',
          bounds: [140.0, 121.0, 320.0, 144.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.abn, equals('26008672179'));
    });

    test('extracts Date when label is followed horizontally by date string', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'DATE:',
          bounds: [50.0, 200.0, 110.0, 225.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '18/11/2026',
          bounds: [130.0, 201.0, 250.0, 224.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.date, equals('18/11/2026'));
    });

    test('extracts Invoice Number when label is followed horizontally by invoice code', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TAX INVOICE NO.',
          bounds: [50.0, 160.0, 220.0, 185.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'INV-98234-A',
          bounds: [240.0, 162.0, 380.0, 186.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.invoiceNumber, equals('INV-98234-A'));
    });

    test('rejects blocks on different visual lines (vertical displacement beyond tolerance)', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL',
          bounds: [50.0, 500.0, 150.0, 530.0], // height = 30
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$99.00',
          bounds: [350.0, 550.0, 450.0, 580.0], // 50px below, exceeds 0.5 * height tolerance
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.total, isNull);
    });

    test('rejects blocks positioned to the left of the anchor', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: '\$152.40',
          bounds: [50.0, 500.0, 150.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL',
          bounds: [250.0, 500.0, 350.0, 530.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.total, isNull);
    });

    test('rejects blocks exceeding max horizontal gap distance', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL',
          bounds: [50.0, 500.0, 100.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$50.00',
          bounds: [2000.0, 500.0, 2100.0, 530.0], // 1900px away, exceeds max gap
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.total, isNull);
    });

    test('selects closest horizontal candidate when multiple blocks exist on same line', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL',
          bounds: [50.0, 500.0, 120.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: 'AUD',
          bounds: [140.0, 500.0, 190.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 1,
          text: '\$88.50',
          bounds: [350.0, 500.0, 420.0, 530.0],
        ),
      ];

      final result = parser.parse(blocks);
      // 'AUD' is not an amount candidate; parser selects the valid amount block or pairs the amount
      expect(result.totalAmount, equals(88.50));
    });

    test('handles multi-page blocks by isolating spatial lookups to the same page', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL',
          bounds: [50.0, 500.0, 150.0, 530.0],
        ),
        ReceiptOcrBlock(
          page: 2, // different page!
          text: '\$152.40',
          bounds: [350.0, 500.0, 450.0, 530.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.total, isNull);
    });

    test('handles anchor blocks that embed both label and value in one line', () {
      final blocks = [
        ReceiptOcrBlock(
          page: 1,
          text: 'TOTAL: \$45.20',
          bounds: [50.0, 500.0, 250.0, 530.0],
        ),
      ];

      final result = parser.parse(blocks);
      expect(result.totalAmount, equals(45.20));
    });
  });
}
