import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  const auditService = ReceiptAuditService();

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
