import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import '../../data/models/vehicle_expense.dart';
import 'receipt_intelligence_service.dart';

/// Keeps machine observations separate from revision-bound human approval.
class ReceiptAuditService {
  final Future<bool> Function(Uint8List)? imageVerifier;
  const ReceiptAuditService({this.imageVerifier});

  Future<ReceiptAuditTrail> create({
    required String merchant,
    required double amount,
    required ExpenseCategory category,
    required String? imagePath,
    ReceiptOcrResult? ocrResult,
    ReceiptAuditTrail? existingAudit,
    bool confirmedByUser = false,
    bool detailsChanged = false,
    DateTime? date,
    String? currency,
    String? abn,
    String? invoiceNumber,
    double? gstAmount,
    String? engineId,
    String? engineVersion,
    List<Map<String, dynamic>> blocks = const [],
    String? reviewedBy,
    String? batchId,
    bool imageReplacementReviewed = false,
    Map<String, dynamic> fieldValues = const {},
    DateTime? capturedAt,
    DateTime? extractedAt,
  }) async {
    final now = DateTime.now();
    Uint8List? bytes;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        await File(imagePath).exists()) {
      bytes = await File(imagePath).readAsBytes();
    }
    final fingerprint = bytes == null || bytes.isEmpty
        ? null
        : sha256.convert(bytes).toString();
    final previous = existingAudit;
    final originalHash =
        previous?.extractionImageSha256 ?? previous?.imageSha256;
    final replaced = originalHash != null && fingerprint != originalHash;
    final current = <String, dynamic>{
      ...?previous?.currentFields,
      'merchant': merchant,
      'amount': amount,
      'category': category.name,
      if (date != null) 'date': date.toIso8601String(),
      if (currency != null) 'currency': currency,
      if (abn != null) 'abn': abn,
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (gstAmount != null) 'gstAmount': gstAmount,
      ...fieldValues
    };
    final observations = <String, dynamic>{
      'merchant': ocrResult?.merchant ?? previous?.ocrMerchant,
      'amount': ocrResult?.amount ?? previous?.ocrAmount,
      'category': ocrResult?.category.name ?? previous?.ocrCategory,
      'date': (ocrResult?.parsedDate ?? previous?.ocrDate)?.toIso8601String(),
      'currency': ocrResult?.currency ?? previous?.ocrCurrency,
      'abn': ocrResult != null ? ocrResult.abn : previous?.ocrAbn,
      'invoiceNumber': ocrResult != null
          ? ocrResult.invoiceNumber
          : previous?.ocrInvoiceNumber,
      'gstAmount':
          ocrResult != null ? ocrResult.gstAmount : previous?.ocrGstAmount
    };
    bool same(Object? a, Object? b) {
      if (a is num && b is num) return (a - b).abs() < 0.000001;
      if (a is List && b is List) {
        return a.length == b.length &&
            List.generate(a.length, (i) => i).every((i) => same(a[i], b[i]));
      }
      if (a is Map && b is Map) {
        return a.length == b.length &&
            a.keys.every((k) => b.containsKey(k) && same(a[k], b[k]));
      }
      return a == b;
    }

    final changedFields = current.keys.where((key) {
      final baseline = previous?.currentFields.containsKey(key) == true
          ? previous!.currentFields[key]
          : observations[key];
      return !same(baseline, current[key]);
    }).toList();
    final changed = detailsChanged || replaced || changedFields.isNotEmpty;
    final revision =
        (previous?.revision ?? 1) + (previous != null && changed ? 1 : 0);
    final events = <ReceiptFieldCorrection>[...?previous?.corrections];
    final reasons = <String>{...?previous?.correctionReasons};
    for (final key in changedFields) {
      events.add(ReceiptFieldCorrection(
          field: key,
          oldValue: previous?.currentFields.containsKey(key) == true
              ? previous!.currentFields[key]
              : observations[key],
          newValue: current[key],
          timestamp: now,
          revision: revision));
      reasons.add('$key corrected');
    }
    if (replaced && imageReplacementReviewed) {
      events.add(ReceiptFieldCorrection(
          field: 'imageSha256',
          oldValue: originalHash,
          newValue: fingerprint,
          timestamp: now,
          revision: revision));
    }
    if (confirmedByUser) {
      final readable = bytes != null &&
          bytes.isNotEmpty &&
          await (imageVerifier?.call(bytes) ?? _decode(bytes));
      if ((fieldValues.containsKey('date') && fieldValues['date'] == null) ||
          (currency != null && currency != 'AUD') ||
          (fieldValues.containsKey('currency') &&
              fieldValues['currency'] != 'AUD') ||
          !readable ||
          merchant.trim().isEmpty ||
          !amount.isFinite ||
          amount <= 0 ||
          (replaced && !imageReplacementReviewed)) {
        throw const FormatException(
            'Attach a readable receipt and explicitly review any replacement image before confirming.');
      }
    }
    final preserve = previous != null &&
        !changed &&
        fingerprint != null &&
        fingerprint == previous.imageSha256 &&
        previous.reviewedRevision == previous.revision;
    return ReceiptAuditTrail(
        imageSha256: fingerprint,
        extractionImageSha256: imageReplacementReviewed
            ? fingerprint
            : originalHash ?? fingerprint,
        rawOcrText: ocrResult?.rawText ?? previous?.rawOcrText,
        ocrMerchant: ocrResult?.merchant ?? previous?.ocrMerchant,
        ocrAmount: ocrResult?.amount ?? previous?.ocrAmount,
        ocrGstAmount:
            ocrResult != null ? ocrResult.gstAmount : previous?.ocrGstAmount,
        ocrAbn: ocrResult != null ? ocrResult.abn : previous?.ocrAbn,
        ocrCategory: ocrResult?.category.name ?? previous?.ocrCategory,
        ocrDate: ocrResult != null ? ocrResult.parsedDate : previous?.ocrDate,
        ocrCurrency:
            ocrResult != null ? ocrResult.currency : previous?.ocrCurrency,
        ocrInvoiceNumber: ocrResult != null
            ? ocrResult.invoiceNumber
            : previous?.ocrInvoiceNumber,
        ocrConfidence: ocrResult?.confidence ?? previous?.ocrConfidence,
        ocrEvidence: [
          ...?ocrResult?.evidence,
          if (ocrResult == null) ...?previous?.ocrEvidence,
          if (replaced) 'extraction_image_changed'
        ],
        engineId: engineId ?? previous?.engineId,
        engineVersion: engineVersion ?? previous?.engineVersion,
        parserVersion: 'receipt-rules-2',
        blocks: blocks.isEmpty ? previous?.blocks ?? const [] : blocks,
        corrections: events,
        correctionReasons: reasons.toList(),
        currentFields: current,
        revision: revision,
        reviewedRevision: confirmedByUser
            ? revision
            : preserve
                ? previous.reviewedRevision
                : null,
        reviewedBy: confirmedByUser
            ? reviewedBy
            : preserve
                ? previous.reviewedBy
                : null,
        batchId: confirmedByUser
            ? batchId
            : preserve
                ? previous.batchId
                : null,
        reviewStatus: confirmedByUser
            ? ReceiptReviewStatus.confirmed
            : preserve
                ? previous.reviewStatus
                : ocrResult == null
                    ? ReceiptReviewStatus.manualReview
                    : ReceiptReviewStatus.needsReview,
        capturedAt: previous?.capturedAt ?? capturedAt ?? now,
        extractedAt:
            ocrResult != null ? extractedAt ?? now : previous?.extractedAt,
        reviewedAt: confirmedByUser
            ? now
            : preserve
                ? previous.reviewedAt
                : null);
  }

  static Future<bool> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final valid = frame.image.width > 0 && frame.image.height > 0;
        frame.image.dispose();
        return valid;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return false;
    }
  }
}
