import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_audit_service.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const auditService = ReceiptAuditService();

  test('human review preserves OCR history and survives an unchanged save',
      () async {
    final directory = await Directory.systemTemp.createTemp('receipt-review-');
    addTearDown(() => directory.delete(recursive: true));
    final image = await File('${directory.path}/receipt.jpg').writeAsBytes(
        base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC'));
    final captured = DateTime(2026, 8, 1);
    final previous = ReceiptAuditTrail(
      reviewStatus: ReceiptReviewStatus.needsReview,
      capturedAt: captured,
      rawOcrText: 'Original total 9.00',
      ocrAmount: 9,
      correctionReasons: ['amount corrected'],
    );
    final reviewed = await auditService.create(
      merchant: 'Local parking',
      amount: 12,
      category: ExpenseCategory.tollsParking,
      imagePath: image.path,
      existingAudit: previous,
      confirmedByUser: true,
      detailsChanged: true,
    );
    expect(reviewed.reviewStatus, ReceiptReviewStatus.confirmed);
    expect(reviewed.rawOcrText, 'Original total 9.00');
    expect(reviewed.ocrAmount, 9);
    expect(reviewed.correctionReasons, contains('amount corrected'));
    expect(reviewed.capturedAt, captured);
    expect(reviewed.reviewedAt, isNotNull);
    final savedAgain = await auditService.create(
      merchant: 'Local parking',
      amount: 12,
      category: ExpenseCategory.tollsParking,
      imagePath: image.path,
      existingAudit: reviewed,
    );
    expect(savedAgain.reviewStatus, ReceiptReviewStatus.confirmed);
    expect(savedAgain.reviewedAt, reviewed.reviewedAt);
    expect(ReceiptAuditTrail.fromJson(savedAgain.toJson()).reviewStatus,
        ReceiptReviewStatus.confirmed);
    final changed = await auditService.create(
      merchant: 'Local parking',
      amount: 15,
      category: ExpenseCategory.tollsParking,
      imagePath: image.path,
      existingAudit: reviewed,
      detailsChanged: true,
    );
    expect(changed.reviewStatus, ReceiptReviewStatus.manualReview);
    expect(changed.reviewedAt, isNull);
  });

  test('confirmation rejects absent or empty receipt bytes', () async {
    final directory = await Directory.systemTemp.createTemp('empty-receipt-');
    addTearDown(() => directory.delete(recursive: true));
    final empty = await File('${directory.path}/empty.jpg').writeAsBytes([]);
    for (final path in [null, empty.path]) {
      await expectLater(
          auditService.create(
            merchant: 'Parking',
            amount: 12,
            category: ExpenseCategory.tollsParking,
            imagePath: path,
            confirmedByUser: true,
          ),
          throwsFormatException);
    }
  });

  test('marks an OCR result for review when no receipt image is retained',
      () async {
    final result = ReceiptOcrResult(
      merchant: 'Bp',
      amount: 142.50,
      date: DateTime(2026, 9, 11),
      category: ExpenseCategory.fuel,
      confidence: 0.90,
      evidence: ['fuel product', 'litres'],
      rawText: 'BP Diesel Litres Total 142.50',
    );

    final audit = await auditService.create(
      merchant: 'Bp',
      amount: 142.50,
      category: ExpenseCategory.fuel,
      imagePath: null,
      ocrResult: result,
    );

    expect(audit.reviewStatus, ReceiptReviewStatus.needsReview);
    expect(audit.needsReview, isTrue);
  });

  test('records corrections instead of silently overwriting OCR suggestions',
      () async {
    final result = ReceiptOcrResult(
      merchant: 'Shell',
      amount: 99.00,
      date: DateTime(2026, 9, 11),
      category: ExpenseCategory.fuel,
      confidence: 0.90,
      evidence: ['fuel product'],
      rawText: 'Shell Diesel',
    );

    final audit = await auditService.create(
      merchant: 'Shell Service Centre',
      amount: 186.40,
      category: ExpenseCategory.maintenanceTyres,
      imagePath: null,
      ocrResult: result,
    );

    expect(
        audit.correctionReasons,
        containsAll(
            ['merchant corrected', 'amount corrected', 'category corrected']));
  });
}
