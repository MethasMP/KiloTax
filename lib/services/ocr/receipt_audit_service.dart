import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../data/models/vehicle_expense.dart';
import 'receipt_intelligence_service.dart';

/// Produces an audit record without treating OCR output as accounting truth.
class ReceiptAuditService {
  const ReceiptAuditService();

  Future<ReceiptAuditTrail> create({
    required String merchant,
    required double amount,
    required ExpenseCategory category,
    required String? imagePath,
    ReceiptOcrResult? ocrResult,
  }) async {
    final fingerprint = await _sha256(imagePath);
    final corrections = <String>[];
    if (ocrResult != null) {
      if (!_sameText(merchant, ocrResult.merchant)) {
        corrections.add('merchant corrected');
      }
      if ((amount - ocrResult.amount).abs() > 0.005) {
        corrections.add('amount corrected');
      }
      if (category != ocrResult.category) corrections.add('category corrected');
    }

    final verified = fingerprint != null &&
        ocrResult != null &&
        ocrResult.isHighConfidence &&
        corrections.isEmpty;

    final evidence = <String>[
      ...?ocrResult?.evidence,
      if (ocrResult?.gstAmount != null &&
          ((ocrResult!.amount - (ocrResult.gstAmount! * 11)).abs() <= 0.60))
        'gst_split_verified',
    ];

    return ReceiptAuditTrail(
      imageSha256: fingerprint,
      rawOcrText: ocrResult?.rawText,
      ocrMerchant: ocrResult?.merchant,
      ocrAmount: ocrResult?.amount,
      ocrGstAmount: ocrResult?.gstAmount,
      ocrAbn: ocrResult?.abn,
      ocrCategory: ocrResult?.category.name,
      ocrConfidence: ocrResult?.confidence,
      ocrEvidence: evidence,
      correctionReasons: corrections,
      reviewStatus: verified
          ? ReceiptReviewStatus.verified
          : ocrResult == null
              ? ReceiptReviewStatus.manualReview
              : ReceiptReviewStatus.needsReview,
      capturedAt: DateTime.now(),
    );
  }

  Future<String?> _sha256(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    final file = File(imagePath);
    if (!await file.exists()) return null;
    return sha256.convert(await file.readAsBytes()).toString();
  }

  bool _sameText(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();
}
