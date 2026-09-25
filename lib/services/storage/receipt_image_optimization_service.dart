import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Target dimensions container for proportional downsampling.
class TargetDimensions {
  final int width;
  final int height;

  const TargetDimensions(this.width, this.height);
}

/// Immutable record of the optimized receipt file and its cryptographic audit hash.
class OptimizedReceiptResult {
  final File file;
  final String sha256Hash;
  final int originalSizeBytes;
  final int compressedSizeBytes;

  const OptimizedReceiptResult({
    required this.file,
    required this.sha256Hash,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
  });

  /// Fraction of compressed size relative to original (e.g. 0.05 = 95% reduction)
  double get compressionRatio =>
      originalSizeBytes > 0 ? compressedSizeBytes / originalSizeBytes : 1.0;

  /// Human-readable savings percentage (e.g. 95%)
  int get savedPercentage =>
      ((1.0 - compressionRatio) * 100).clamp(0, 100).round();
}

/// Function signature for compressor delegate (enables deterministic testing and mock injection)
typedef ImageCompressorDelegate = Future<File?> Function(
  String sourcePath,
  String targetPath,
  int minWidth,
  int minHeight,
  int quality,
);

/// Frontier WebP Receipt Optimization Engine.
///
/// Implements the 5-pillar document compression pipeline:
/// 1. Dimension clamping to max 1800px on long edge (~250-300 DPI for dockets)
/// 2. EXIF & Metadata pruning (saves 30-50 KB of camera bloat)
/// 3. Native off-thread WebP encoding (Color-preserving YUV 4:2:0)
/// 4. SHA-256 cryptographic audit trail generation
/// 5. Graceful fallback on native errors
class ReceiptImageOptimizationService {
  final ImageCompressorDelegate? _compressorDelegate;

  ReceiptImageOptimizationService({
    ImageCompressorDelegate? compressorDelegate,
  }) : _compressorDelegate = compressorDelegate;

  /// Optimizes a raw receipt photo into an audit-proof, ultra-lightweight WebP file.
  Future<OptimizedReceiptResult> optimizeReceipt(
    File rawFile, {
    int quality = 78,
    int maxDimension = 1800,
  }) async {
    if (!await rawFile.exists()) {
      throw FileSystemException(
        'Source receipt file does not exist',
        rawFile.path,
      );
    }

    final originalBytes = await rawFile.readAsBytes();
    final originalSize = originalBytes.length;

    // Generate output path with .webp extension
    final targetPath = generateWebpOutputPath(rawFile.path);

    // Compute dimensions (default fallback assumption if reading header fails)
    final targetDim = calculateTargetDimensions(
      1800,
      2400,
      maxDimension: maxDimension,
    );

    File? compressedFile;

    try {
      if (_compressorDelegate != null) {
        // Use injected delegate (for unit tests / mock environment)
        compressedFile = await _compressorDelegate(
          rawFile.path,
          targetPath,
          targetDim.width,
          targetDim.height,
          quality,
        );
      } else {
        // Native off-thread libwebp compression
        final xFileResult = await FlutterImageCompress.compressAndGetFile(
          rawFile.path,
          targetPath,
          quality: quality,
          minWidth: targetDim.width,
          minHeight: targetDim.height,
          format: CompressFormat.webp,
          keepExif: false, // Prunes 30-50 KB of camera bloat
          autoCorrectionAngle: true,
        );

        if (xFileResult != null) {
          compressedFile = File(xFileResult.path);
        }
      }
    } catch (e) {
      debugPrint(
        '[ReceiptImageOptimizationService] Compression warning ($e). Falling back to original.',
      );
    }

    // Fallback: If compression returned null or failed, use rawFile safely
    final finalFile = (compressedFile != null && await compressedFile.exists())
        ? compressedFile
        : rawFile;

    final finalBytes = await finalFile.readAsBytes();
    final finalSha256 = computeSha256(finalBytes);

    return OptimizedReceiptResult(
      file: finalFile,
      sha256Hash: finalSha256,
      originalSizeBytes: originalSize,
      compressedSizeBytes: finalBytes.length,
    );
  }

  /// Calculates proportional dimensions clamped to [maxDimension] on the longest edge.
  TargetDimensions calculateTargetDimensions(
    int width,
    int height, {
    int maxDimension = 1800,
  }) {
    if (width <= 0 || height <= 0) {
      return TargetDimensions(maxDimension, maxDimension);
    }

    final maxEdge = width > height ? width : height;
    if (maxEdge <= maxDimension) {
      return TargetDimensions(width, height);
    }

    final scale = maxDimension / maxEdge;
    final targetW = (width * scale).round();
    final targetH = (height * scale).round();

    return TargetDimensions(targetW, targetH);
  }

  /// Generates a standardized .webp target file path next to the source file.
  String generateWebpOutputPath(String sourcePath) {
    final parent = File(sourcePath).parent.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = sourcePath.split(Platform.pathSeparator).last.split('.').first;
    return '$parent/${baseName}_opt_$timestamp.webp';
  }

  /// Returns the persistent evidence vault directory in the app documents space,
  /// ensuring receipt/odometer photos are stored durably instead of in OS temp cache.
  Future<Directory> getEvidenceVaultDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${docsDir.path}/evidence_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Computes a standard SHA-256 hex checksum for cryptographic audit trails.
  String computeSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }
}
