import 'dart:io';
import 'package:image/image.dart' as img;

enum ReceiptClarityStatus { sharp, acceptable, blurry }

class ReceiptClarityAssessment {
  final double edgeVariance;
  final ReceiptClarityStatus status;
  final bool isBlurry;

  const ReceiptClarityAssessment({
    required this.edgeVariance,
    required this.status,
    required this.isBlurry,
  });
}

class PreprocessedReceiptResult {
  final String enhancedPath;
  final ReceiptClarityAssessment clarity;

  const PreprocessedReceiptResult({
    required this.enhancedPath,
    required this.clarity,
  });
}

/// Pre-processing filter designed specifically for faded thermal receipt paper,
/// in-cab glare environments, and blur pre-assessment.
class ThermalReceiptImagePreprocessor {
  const ThermalReceiptImagePreprocessor();

  /// Assesses image sharpness using high-frequency edge variance (Laplacian gradient proxy).
  /// Fast computation (<20ms) using downsampled grayscale window.
  Future<ReceiptClarityAssessment> assessClarity(String inputPath) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const ReceiptClarityAssessment(
          edgeVariance: 0.0,
          status: ReceiptClarityStatus.blurry,
          isBlurry: true,
        );
      }

      final bytes = await inputFile.readAsBytes();
      if (bytes.isEmpty) {
        return const ReceiptClarityAssessment(
          edgeVariance: 0.0,
          status: ReceiptClarityStatus.blurry,
          isBlurry: true,
        );
      }

      final original = img.decodeImage(bytes);
      if (original == null) {
        return const ReceiptClarityAssessment(
          edgeVariance: 0.0,
          status: ReceiptClarityStatus.blurry,
          isBlurry: true,
        );
      }

      // Downsample to 256x256 for fast edge variance calculation
      final small = img.copyResize(original, width: 256, height: 256);
      final gray = img.grayscale(small);

      // Compute discrete Laplacian convolution variance
      // Kernel:
      //  0  1  0
      //  1 -4  1
      //  0  1  0
      double sum = 0.0;
      double sumSq = 0.0;
      int count = 0;

      for (int y = 1; y < gray.height - 1; y++) {
        for (int x = 1; x < gray.width - 1; x++) {
          final center = gray.getPixel(x, y).r;
          final top = gray.getPixel(x, y - 1).r;
          final bottom = gray.getPixel(x, y + 1).r;
          final left = gray.getPixel(x - 1, y).r;
          final right = gray.getPixel(x + 1, y).r;

          final laplacian = (top + bottom + left + right - (4 * center)).toDouble();
          sum += laplacian;
          sumSq += laplacian * laplacian;
          count++;
        }
      }

      if (count == 0) {
        return const ReceiptClarityAssessment(
          edgeVariance: 0.0,
          status: ReceiptClarityStatus.blurry,
          isBlurry: true,
        );
      }

      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);

      // Variance thresholds:
      // Sharp text with high contrast edges typically yields variance > 100
      // Blurry / washed out images yield variance < 100
      final isBlurry = variance < 100.0;
      final status = variance >= 180.0
          ? ReceiptClarityStatus.sharp
          : (variance >= 100.0
              ? ReceiptClarityStatus.acceptable
              : ReceiptClarityStatus.blurry);

      return ReceiptClarityAssessment(
        edgeVariance: variance,
        status: status,
        isBlurry: isBlurry,
      );
    } catch (_) {
      return const ReceiptClarityAssessment(
        edgeVariance: 0.0,
        status: ReceiptClarityStatus.blurry,
        isBlurry: true,
      );
    }
  }

  /// Full pre-processing pipeline: assesses clarity and enhances faded thermal contrast.
  Future<PreprocessedReceiptResult> preprocessReceipt({
    required String inputPath,
    required String outputPath,
  }) async {
    final clarity = await assessClarity(inputPath);
    final enhanced = await enhanceThermalReceipt(
      inputPath: inputPath,
      outputPath: outputPath,
    );

    return PreprocessedReceiptResult(
      enhancedPath: enhanced,
      clarity: clarity,
    );
  }

  /// Processes the image at [inputPath] to enhance faint thermal ink,
  /// normalize exposure, and write an optimized copy to [outputPath].
  ///
  /// If processing fails or input cannot be decoded, returns [inputPath] unchanged.
  Future<String> enhanceThermalReceipt({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return inputPath;

      final bytes = await inputFile.readAsBytes();
      if (bytes.isEmpty) return inputPath;

      final original = img.decodeImage(bytes);
      if (original == null) return inputPath;

      // 1. Downscale if excessively massive to maintain ~100-200ms processing budget
      var processed = original;
      const maxDim = 1800;
      if (processed.width > maxDim || processed.height > maxDim) {
        if (processed.width > processed.height) {
          processed = img.copyResize(processed, width: maxDim);
        } else {
          processed = img.copyResize(processed, height: maxDim);
        }
      }

      // 2. Convert to grayscale to remove yellow/blue thermal paper staining
      processed = img.grayscale(processed);

      // 3. Contrast & gamma adjustment to emphasize faded dot-matrix / thermal print
      // Gamma > 1.0 darkens midtones, making faded gray print stand out
      processed = img.adjustColor(
        processed,
        contrast: 1.35,
        gamma: 0.85,
      );

      // 4. Save enhanced JPEG
      final outputBytes = img.encodeJpg(processed, quality: 88);
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(outputBytes);

      return outputPath;
    } catch (_) {
      // Fallback cleanly to original path if any decoding exception occurs
      return inputPath;
    }
  }
}
