import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/storage/receipt_image_optimization_service.dart';

void main() {
  group('ReceiptImageOptimizationService (Frontier WebP Engine)', () {
    late ReceiptImageOptimizationService service;
    late Directory tempDir;

    setUp(() async {
      service = ReceiptImageOptimizationService();
      tempDir = await Directory.systemTemp.createTemp('kilotax_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Computes deterministic SHA-256 hash for raw file bytes', () {
      final testBytes = Uint8List.fromList('KiloTax Tax Evidence Receipt Audit'.codeUnits);
      final hash = service.computeSha256(testBytes);

      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // 32-byte hex = 64 characters
      // Deterministic check
      expect(service.computeSha256(testBytes), equals(hash));
    });

    test('Calculates proportional downsampling dimensions within 1800px constraint', () {
      // 1. Portrait 4000x3000 (standard 12MP smartphone photo)
      final dim1 = service.calculateTargetDimensions(3000, 4000, maxDimension: 1800);
      expect(dim1.height, equals(1800));
      expect(dim1.width, equals(1350));

      // 2. Ultra-long Bunnings docket (e.g. 1000 x 5000)
      final dim2 = service.calculateTargetDimensions(1000, 5000, maxDimension: 1800);
      expect(dim2.height, equals(1800));
      expect(dim2.width, equals(360));

      // 3. Small receipt already below 1800px (e.g. 800 x 1200)
      final dim3 = service.calculateTargetDimensions(800, 1200, maxDimension: 1800);
      expect(dim3.width, equals(800));
      expect(dim3.height, equals(1200));
    });

    test('Generates standard .webp target path alongside original', () {
      final rawFile = File('${tempDir.path}/raw_docket.jpg');
      final targetPath = service.generateWebpOutputPath(rawFile.path);

      expect(targetPath.endsWith('.webp'), isTrue);
      expect(targetPath, contains('raw_docket_opt_'));
    });

    test('Simulated compression pipeline returns OptimizedReceiptResult with valid metadata', () async {
      final rawFile = File('${tempDir.path}/docket.png');
      final dummyData = Uint8List(1024 * 50); // 50 KB dummy image
      await rawFile.writeAsBytes(dummyData);

      // Using mock compressor to run deterministically in headless CI/Unit tests
      final mockService = ReceiptImageOptimizationService(
        compressorDelegate: (source, target, width, height, quality) async {
          final targetFile = File(target);
          await targetFile.writeAsBytes(Uint8List(1024 * 10)); // 10 KB simulated WebP
          return targetFile;
        },
      );

      final result = await mockService.optimizeReceipt(rawFile);

      expect(result.file.existsSync(), isTrue);
      expect(result.originalSizeBytes, equals(50 * 1024));
      expect(result.compressedSizeBytes, equals(10 * 1024));
      expect(result.compressionRatio, closeTo(0.20, 0.01)); // 80% reduction
      expect(result.sha256Hash.length, equals(64));
    });

    test('Throws or safely returns fallback if source file does not exist', () async {
      final missingFile = File('${tempDir.path}/non_existent.jpg');

      expect(
        () async => await service.optimizeReceipt(missingFile),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
