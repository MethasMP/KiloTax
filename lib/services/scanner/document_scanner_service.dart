import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../storage/receipt_image_optimization_service.dart';

/// Mission-critical Document Scanner Service (Step 1: Hardware-accelerated scanning).
/// Handles Apple VisionKit (iOS) and Native Document Scanner Intent (Android)
/// with graceful zero-crash fallbacks for Simulators and older devices.
/// Retains captured source bytes before OCR; derived images must not replace originals.
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
  Future<String?> scanDocument({
    bool allowFallbackToCamera = true,
    int noOfPages = 1,
  }) async {
    final results = await scanBatchDocuments(
      maxPages: noOfPages,
      allowFallbackToCamera: allowFallbackToCamera,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Scans multiple documents/receipts in a single batch session.
  ///
  /// Uses hardware-accelerated document scanning (VisionKit on iOS, Document Scanner Intent on Android).
  /// Retains all valid captured source images in app storage.
  ///
  /// Returns a list of absolute paths of the scanned image files, or empty list if cancelled.
  Future<List<String>> scanBatchDocuments({
    int maxPages = 20,
    bool allowFallbackToCamera = true,
  }) async {
    try {
      final List<String>? pictures =
          await CunningDocumentScanner.getPictures(noOfPages: maxPages);

      if (pictures != null && pictures.isNotEmpty) {
        final List<String> optimizedPaths = [];
        for (final rawPath in pictures) {
          final trimmed = rawPath.trim();
          if (trimmed.isNotEmpty) {
            final optimized = await _optimizeIfValid(trimmed);
            if (optimized != null && optimized.isNotEmpty) {
              optimizedPaths.add(optimized);
            }
          }
        }
        if (optimizedPaths.isNotEmpty) {
          debugPrint(
            '[DocumentScannerService] Native batch scan successful: ${optimizedPaths.length} pages',
          );
          return optimizedPaths;
        }
      }

      // User cancelled or returned empty list
      return [];
    } catch (e, stack) {
      debugPrint(
          '[DocumentScannerService] Native document scanner failed: $e\n$stack');

      // (e.g. running inside iOS Simulator or device without VisionKit support)
      if (allowFallbackToCamera) {
        debugPrint(
            '[DocumentScannerService] Falling back to standard ImagePicker camera...');
        try {
          final XFile? photo = await _picker.pickImage(
            source: ImageSource.camera,
          );
          if (photo != null) {
            final optimized = await _optimizeIfValid(photo.path);
            if (optimized != null && optimized.isNotEmpty) {
              return [optimized];
            }
          }
          return [];
        } catch (pickerError) {
          debugPrint(
              '[DocumentScannerService] Camera fallback failed: $pickerError');
          return [];
        }
      }

      return [];
    }
  }

  /// Selects an existing photo or receipt screenshot from the photo library.
  Future<String?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      return await _optimizeIfValid(photo?.path);
    } catch (e) {
      debugPrint('[DocumentScannerService] Gallery picker failed: $e');
      return null;
    }
  }

  /// Selects one or more existing receipt photos from the photo library.
  Future<List<String>> pickMultipleFromGallery() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage();
      final List<String> optimizedPaths = [];
      for (final photo in photos) {
        final optimized = await _optimizeIfValid(photo.path);
        if (optimized != null && optimized.isNotEmpty) {
          optimizedPaths.add(optimized);
        }
      }
      return optimizedPaths;
    } catch (e) {
      debugPrint(
          '[DocumentScannerService] Multi-image gallery picker failed: $e');
      return [];
    }
  }

  /// Retains the captured source before any lossy processing.
  Future<String?> _optimizeIfValid(String? rawPath) async {
    if (rawPath == null || rawPath.isEmpty) return null;
    final file = File(rawPath);
    if (!await file.exists()) {
      // In mock/test environments where file is simulated, return raw path
      return rawPath;
    }

    final directory = await _optimizer.getEvidenceVaultDirectory();
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final extension = file.path.split('.').last.toLowerCase();
    final safeExtension =
        {'png', 'jpg', 'jpeg', 'webp', 'heic'}.contains(extension)
            ? extension
            : 'image';
    final retained = File('${directory.path}/source_$hash.$safeExtension');
    if (!await retained.exists()) {
      await retained.writeAsBytes(bytes, flush: true);
    }
    return retained.path;
  }
}
