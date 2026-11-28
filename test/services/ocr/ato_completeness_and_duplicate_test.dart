import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/ocr/receipt_pre_db_validator.dart';

void main() {
  const validator = ReceiptPreDbValidator();
  final now = DateTime(2026, 11, 25, 17, 0);

  ReceiptOcrResult makeResult({
    String merchant = 'BP Berwick',
    double amount = 65.00,
    double? gstAmount = 5.91,
    String? abn = '12345678901',
    DateTime? date,
    bool dateNeedsReview = false,
    bool hasMixedItems = false,
    String rawText = 'BP BERWICK\nUNLEADED 91 \$65.00\nTOTAL \$65.00',
  }) {
    return ReceiptOcrResult(
      merchant: merchant,
      amount: amount,
      gstAmount: gstAmount,
      abn: abn,
      date: date ?? now,
      dateNeedsReview: dateNeedsReview,
      hasMixedItems: hasMixedItems,
      category: ExpenseCategory.fuel,
      confidence: 0.90,
      currency: 'AUD',
      evidence: const [],
      rawText: rawText,
    );
  }

  group('P0: ATO 5-Point Completeness Gate', () {
    test('returns 5/5 audit-ready when all ATO statutory fields are present', () {
      final result = validator.validateAndSanitize(
        ocrResult: makeResult(amount: 95.00, abn: '12345678901'),
        currentSystemTime: now,
      );
      expect(result.atoReport.score, 5);
      expect(result.atoReport.isAuditReady, isTrue);
      expect(result.atoReport.missingItems, isEmpty);
    });

    test('flags missing ABN when amount exceeds \$82.50 AUD threshold', () {
      final result = validator.validateAndSanitize(
        ocrResult: makeResult(amount: 85.00, abn: null),
        currentSystemTime: now,
      );
      expect(result.atoReport.score, 4);
      expect(result.atoReport.isAuditReady, isFalse);
      expect(result.atoReport.missingItems, contains('ABN (required over \$82.50)'));
    });

    test('does not require ABN when amount is \$82.50 or under', () {
      final result = validator.validateAndSanitize(
        ocrResult: makeResult(amount: 82.50, abn: null),
        currentSystemTime: now,
      );
      expect(result.atoReport.score, 5);
      expect(result.atoReport.isAuditReady, isTrue);
    });
  });

  group('P1: Smart Duplicate Guard & Mixed-Item Quarantine', () {
    test('detects duplicate receipt with same merchant, amount, and calendar day', () {
      final existing = [
        ReceiptFingerprint(
          merchant: 'bp berwick',
          amount: 65.00,
          date: DateTime(2026, 11, 25, 8, 30),
        ),
      ];
      final result = validator.validateAndSanitize(
        ocrResult: makeResult(merchant: 'BP Berwick', amount: 65.00),
        currentSystemTime: now,
        existingReceipts: existing,
      );
      expect(result.isDuplicateSuspected, isTrue);
      expect(result.warningMessages,
          contains('Possible duplicate receipt detected'));
    });

    test('does not flag duplicate when amount or date differs', () {
      final existing = [
        ReceiptFingerprint(
          merchant: 'BP Berwick',
          amount: 65.00,
          date: DateTime(2026, 11, 24, 17, 0),
        ),
      ];
      final result = validator.validateAndSanitize(
        ocrResult: makeResult(merchant: 'BP Berwick', amount: 65.00),
        currentSystemTime: now,
        existingReceipts: existing,
      );
      expect(result.isDuplicateSuspected, isFalse);
    });
  });
}
