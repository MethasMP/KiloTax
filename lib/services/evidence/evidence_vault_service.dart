import 'dart:io';
import '../../data/models/audit_evidence.dart';
import '../storage/receipt_image_optimization_service.dart';

class EvidenceVaultService {
  final ReceiptImageOptimizationService _optimizer;

  EvidenceVaultService({
    ReceiptImageOptimizationService? optimizer,
  }) : _optimizer = optimizer ?? ReceiptImageOptimizationService();

  /// Processes raw captured photo:
  /// 1. Optimizes/compresses image first to eliminate local bloat
  /// 2. Computes SHA-256 hash strictly on the saved, optimized file (prevents hash drift)
  /// 3. Validates against local existing evidence to enforce anti-fraud offline
  Future<(AuditEvidence? evidence, String? errorMessage)> registerEvidence({
    required File rawFile,
    required EvidenceType evidenceType,
    required String? vehicleId,
    String? entityId,
    required List<AuditEvidence> existingEvidence,
    Map<String, dynamic>? watermarkMetadata,
  }) async {
    try {
      // 1. Compress & optimize first (Red Flag 2 resolved)
      final optResult = await _optimizer.optimizeReceipt(rawFile);
      final finalFile = optResult.file;
      final hash = optResult.sha256Hash;
      final bytes = await finalFile.readAsBytes();

      // 3. Offline Anti-Fraud Check: Disallow identical image reuse within vehicle evidence
      final isDuplicate = existingEvidence.any((e) => e.imageSha256 == hash);
      if (isDuplicate) {
        return (
          null,
          'Duplicate photo rejected. This image has already been registered in your evidence vault.'
        );
      }

      // Check specifically between start and end odometer photos
      if (evidenceType == EvidenceType.odometerEnd) {
        final startOdo = existingEvidence.where(
          (e) => e.vehicleId == vehicleId && e.evidenceType == EvidenceType.odometerStart,
        );
        if (startOdo.isNotEmpty && startOdo.any((e) => e.imageSha256 == hash)) {
          return (
            null,
            'Finish odometer photo cannot be identical to starting photo.'
          );
        }
      }

      final evidence = AuditEvidence(
        id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: vehicleId,
        evidenceType: evidenceType,
        entityId: entityId,
        storagePath: finalFile.path,
        imageSha256: hash,
        fileSizeBytes: bytes.length,
        mimeType: 'image/webp',
        capturedAt: DateTime.now(),
        captureSource: 'camera_live',
        watermarkMetadata: watermarkMetadata ?? {},
      );

      return (evidence, null);
    } catch (e) {
      return (null, 'Evidence processing failed: $e');
    }
  }
}
