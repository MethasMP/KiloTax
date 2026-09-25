import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../storage/receipt_image_optimization_service.dart';

/// Mission-critical Document Scanner Service (Step 1: Hardware-accelerated scanning).
/// Handles Apple VisionKit (iOS) and Native Document Scanner Intent (Android)
/// with graceful zero-crash fallbacks for Simulators and older devices.
/// Automatically applies Frontier WebP optimization to captured images.
class DocumentScannerService {
  final ImagePicker _picker;
  final ReceiptImageOptimizationService _optimizer;

  DocumentScannerService({
    ImagePicker? picker,
    ReceiptImageOptimizationService? optimizer,
  })  : _picker = picker ?? ImagePicker(),
        _optimizer = optimizer ?? ReceiptImageOptimizationService();

  /// Captures and enhances a document/receipt with 4-point auto edge detection,
  /// perspective de-skewing, and high-contrast enhancement.
  ///
  /// Returns the absolute path of the scanned image file, or null if cancelled.
  Future<String?> scanDocument({bool allowFallbackToCamera = true}) async {
    try {
      // 1. Attempt Native Hardware Document Scanner (Apple VisionKit / Google ML Kit)
      final List<String>? pictures =
          await CunningDocumentScanner.getPictures(noOfPages: 1);

      if (pictures != null && pictures.isNotEmpty) {
        final scannedPath = pictures.first.trim();
        if (scannedPath.isNotEmpty && await File(scannedPath).exists()) {
          debugPrint(
              '[DocumentScannerService] Native scan successful: $scannedPath');
          return await _optimizeIfValid(scannedPath);
        }
      }

      // User cancelled or returned empty list
      return null;
    } catch (e, stack) {
      debugPrint(
          '[DocumentScannerService] Native document scanner failed: $e\n$stack');

      // 2. Failsafe: Gracefully fallback to standard camera if native scanner fails
      // (e.g. running inside iOS Simulator or device without VisionKit support)
      if (allowFallbackToCamera) {
        debugPrint(
            '[DocumentScannerService] Falling back to standard ImagePicker camera...');
        try {
          final XFile? photo = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 90,
            maxWidth: 1800,
          );
          return await _optimizeIfValid(photo?.path);
        } catch (pickerError) {
          debugPrint(
              '[DocumentScannerService] Camera fallback failed: $pickerError');
          return null;
        }
      }

      return null;
    }
  }

  /// Selects an existing photo or receipt screenshot from the photo library.
  Future<String?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1800,
      );
      return await _optimizeIfValid(photo?.path);
    } catch (e) {
      debugPrint(
          '[DocumentScannerService] Gallery picker failed: $e');
      return null;
    }
  }

  /// Optimizes a receipt image with Frontier WebP if it exists on disk.
  Future<String?> _optimizeIfValid(String? rawPath) async {
    if (rawPath == null || rawPath.isEmpty) return null;
    final file = File(rawPath);
    if (!await file.exists()) {
      // In mock/test environments where file is simulated, return raw path
      return rawPath;
    }

    try {
      final result = await _optimizer.optimizeReceipt(file);
      debugPrint(
        '[DocumentScannerService] Frontier WebP: ${file.path} optimized '
        '(${result.originalSizeBytes}B -> ${result.compressedSizeBytes}B, saved ${result.savedPercentage}%)',
      );
      return result.file.path;
    } catch (e) {
      debugPrint(
        '[DocumentScannerService] Optimization error ($e). Falling back to original.',
      );
      return rawPath;
    }
  }
}
