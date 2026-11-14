import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';

void main() {
  test('copyWith can clear optional observed fields explicitly', () {
    final expense = VehicleExpense(
        id: 'e',
        vehicleId: 'v',
        amount: 90,
        category: ExpenseCategory.fuel,
        date: DateTime(2026),
        currency: 'AUD',
        gstAmount: 8.18,
        supplierAbn: '123',
        invoiceNumber: 'INV1');
    final cleared = expense.copyWith(
        currency: null,
        gstAmount: null,
        supplierAbn: null,
        invoiceNumber: null);
    expect(cleared.currency, isNull);
    expect(cleared.gstAmount, isNull);
    expect(cleared.supplierAbn, isNull);
    expect(cleared.invoiceNumber, isNull);
    expect(expense.copyWith().currency, 'AUD');
    expect(expense.copyWith(gstAmount: 0).gstAmount, 0.0);
  });
  test('unknown to known observation records a correction event', () async {
    final service = ReceiptAuditService();
    final existing = ReceiptAuditTrail(
        reviewStatus: ReceiptReviewStatus.needsReview,
        capturedAt: DateTime(2026),
        currentFields: {'currency': null});
    final updated = await service.create(
        merchant: 'Fuel',
        amount: 90,
        category: ExpenseCategory.fuel,
        imagePath: null,
        existingAudit: existing,
        fieldValues: {'currency': 'AUD'});
    final event = updated.corrections.singleWhere((e) => e.field == 'currency');
    expect(event.oldValue, isNull);
    expect(event.newValue, 'AUD');
  });
  test('mixed items and currency are explicit observations', () {
    const parser = ReceiptIntelligenceService();
    final mixed = parser.analyseText(
        'AMPOL SERVICE STATION\nDiesel 80.00\nChocolate 10.00\nTOTAL USD 90.00');
    expect(mixed.hasMixedItems, isTrue);
    expect(mixed.currency, 'USD');
    expect(mixed.parsedDate, isNull);
    expect(mixed.dateNeedsReview, isTrue);
    expect(mixed.isHighConfidence, isFalse);
    expect(parser.classify('SERVICE STATION DIESEL 80').hasConflictingEvidence,
        isFalse);
    expect(parser.analyseText('Diesel\nTOTAL \$90.00').currency, isNull);
  });
  test('stored OCR corrections invalidate approval and retain events',
      () async {
    final dir = await Directory.systemTemp.createTemp('revision-');
    addTearDown(() => dir.delete(recursive: true));
    final image = await File('${dir.path}/image').writeAsBytes([1, 2, 3]);
    final service = ReceiptAuditService(imageVerifier: (_) async => true);
    final approved = await service.create(
        merchant: 'Fuel',
        amount: 90,
        category: ExpenseCategory.fuel,
        imagePath: image.path,
        existingAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.needsReview,
            capturedAt: DateTime(2026),
            ocrAmount: 80),
        confirmedByUser: true,
        fieldValues: {'currency': 'AUD', 'date': '2026-11-01'});
    expect(
        approved.corrections.any(
            (e) => e.field == 'amount' && e.oldValue == 80 && e.newValue == 90),
        isTrue);
    final edited = await service.create(
        merchant: 'Fuel',
        amount: 95,
        category: ExpenseCategory.fuel,
        imagePath: image.path,
        existingAudit: approved);
    expect(edited.revision, approved.revision + 1);
    expect(edited.reviewedRevision, isNull);
    expect(edited.reviewStatus, ReceiptReviewStatus.manualReview);
    await image.writeAsBytes([4, 5, 6]);
    await expectLater(
        service.create(
            merchant: 'Fuel',
            amount: 95,
            category: ExpenseCategory.fuel,
            imagePath: image.path,
            existingAudit: edited,
            confirmedByUser: true),
        throwsFormatException);
    final replacement = await service.create(
        merchant: 'Fuel',
        amount: 95,
        category: ExpenseCategory.fuel,
        imagePath: image.path,
        existingAudit: edited,
        confirmedByUser: true,
        imageReplacementReviewed: true);
    expect(replacement.extractionImageSha256, replacement.imageSha256);
    expect(ReceiptAuditTrail.fromJson(replacement.toJson()).reviewedRevision,
        replacement.revision);
  });
  test('confirmation rejects non-image bytes with real decoder', () async {
    final dir = await Directory.systemTemp.createTemp('invalid-image-');
    addTearDown(() => dir.delete(recursive: true));
    final image = await File('${dir.path}/image').writeAsBytes([1, 2, 3]);
    await expectLater(
        const ReceiptAuditService().create(
            merchant: 'Fuel',
            amount: 90,
            category: ExpenseCategory.fuel,
            imagePath: image.path,
            confirmedByUser: true),
        throwsFormatException);
  });
}
