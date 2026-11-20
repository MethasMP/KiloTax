import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/audit_evidence.dart';
import '../storage/receipt_image_optimization_service.dart';
import '../storage/receipt_storage_service.dart';

class EvidenceVaultService {
  final ReceiptImageOptimizationService _optimizer;
  final ReceiptStorageService? _storageService;
  final Directory? _vaultDirectory;

  EvidenceVaultService({
    ReceiptImageOptimizationService? optimizer,
    ReceiptStorageService? storageService,
    Directory? vaultDirectory,
  })  : _optimizer = optimizer ?? ReceiptImageOptimizationService(),
        _storageService = storageService,
        _vaultDirectory = vaultDirectory;

  ReceiptStorageService? get storageService => _storageService;

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
      final optResult = await _optimizer.optimizeReceipt(rawFile);
      final finalFile = optResult.file;
      final hash = optResult.sha256Hash;
      final bytes = await finalFile.readAsBytes();

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
          (e) =>
              e.vehicleId == vehicleId &&
              e.evidenceType == EvidenceType.odometerStart,
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

  /// Registers verified audit evidence row following post-upload hash integrity check (INV-A01 & INV-A04).
  ///
  /// Guarantees client SHA-256 matches storage hash before writing the audit_evidence record.
  Future<(AuditEvidence? evidence, String? errorMessage)> registerVerifiedAuditEvidence({
    required List<int> bytes,
    required EvidenceType evidenceType,
    required String userId,
    String? vehicleId,
    String? entityId,
    required UploadResult uploadResult,
    Map<String, dynamic>? watermarkMetadata,
  }) async {
    if (!uploadResult.matchesClientHash || uploadResult.storagePath == null) {
      return (
        null,
        'Evidence integrity verification failed: ${uploadResult.errorMessage ?? "Storage hash does not match client SHA-256."}'
      );
    }

    final clientHash = ReceiptStorageService.computeSha256(bytes);
    if (clientHash.toLowerCase() != uploadResult.confirmedSha256?.toLowerCase()) {
      return (
        null,
        'Evidence integrity verification failed: Client SHA-256 does not match confirmed storage hash.'
      );
    }

    final evidence = AuditEvidence(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicleId,
      evidenceType: evidenceType,
      entityId: entityId,
      storagePath: uploadResult.storagePath!,
      imageSha256: clientHash,
      fileSizeBytes: bytes.length,
      mimeType: 'image/webp',
      capturedAt: DateTime.now(),
      captureSource: 'camera_live',
      watermarkMetadata: watermarkMetadata ?? {},
    );

    return (evidence, null);
  }

  /// Purges all local cached images and documents in the evidence vault
  Future<void> clearLocalVault() async {
    try {
      final vaultDir = _vaultDirectory ?? await _optimizer.getEvidenceVaultDirectory();
      if (await vaultDir.exists()) {
        final entities = vaultDir.listSync(recursive: true);
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } catch (e) {
            debugPrint('[EvidenceVaultService] Warning deleting file: ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[EvidenceVaultService] Warning clearing local vault: $e');
    }
  }
}
