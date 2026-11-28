import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiloclaim/services/ocr/thermal_receipt_image_preprocessor.dart';

void main() {
  group('ThermalReceiptImagePreprocessor - Clarity Assessment & Pipeline (TDD)', () {
    const preprocessor = ThermalReceiptImagePreprocessor();

    late String sharpImagePath;
    late String blurryImagePath;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('receipt_clarity_test_');

      // 1. Generate synthetic sharp image with high-contrast text edges
      final sharpImg = img.Image(width: 400, height: 400);
      img.fill(sharpImg, color: img.ColorRgb8(255, 255, 255));
      // Draw crisp black lines / edges
      for (var y = 50; y < 350; y += 20) {
        img.drawLine(
          sharpImg,
          x1: 50,
          y1: y,
          x2: 350,
          y2: y,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 3,
        );
      }
      sharpImagePath = '${tempDir.path}/sharp.jpg';
      await File(sharpImagePath).writeAsBytes(img.encodeJpg(sharpImg));

      // 2. Generate synthetic blurry image (uniform blur / smoothed gradient with zero high-frequency edges)
      final blurImg = img.Image(width: 400, height: 400);
      img.fill(blurImg, color: img.ColorRgb8(240, 240, 240));
      // Very soft, low contrast, washed out pattern
      for (var y = 0; y < 400; y++) {
        for (var x = 0; x < 400; x++) {
          final val = (240 + ((x + y) % 10) * 0.5).round().clamp(0, 255);
          blurImg.setPixelRgb(x, y, val, val, val);
        }
      }
      blurryImagePath = '${tempDir.path}/blurry.jpg';
      await File(blurryImagePath).writeAsBytes(img.encodeJpg(blurImg));
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('assessClarity returns high edge variance for sharp receipt image', () async {
      final clarity = await preprocessor.assessClarity(sharpImagePath);

      expect(clarity.isBlurry, isFalse);
      expect(clarity.edgeVariance, greaterThan(100.0));
      expect(clarity.status, equals(ReceiptClarityStatus.sharp));
    });

    test('assessClarity detects motion-blurred or washed-out images with low edge variance', () async {
      final clarity = await preprocessor.assessClarity(blurryImagePath);

      expect(clarity.isBlurry, isTrue);
      expect(clarity.edgeVariance, lessThan(100.0));
      expect(clarity.status, equals(ReceiptClarityStatus.blurry));
    });

    test('preprocessReceipt processes sharp image and outputs enhanced file', () async {
      final enhancedPath = '${tempDir.path}/enhanced.jpg';
      final result = await preprocessor.preprocessReceipt(
        inputPath: sharpImagePath,
        outputPath: enhancedPath,
      );

      expect(result.clarity.isBlurry, isFalse);
      expect(File(result.enhancedPath).existsSync(), isTrue);
      expect(File(result.enhancedPath).lengthSync(), greaterThan(500));
    });
  });
}
