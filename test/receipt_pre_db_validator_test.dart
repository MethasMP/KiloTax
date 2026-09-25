import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/ocr/receipt_pre_db_validator.dart';

void main() {
  const validator = ReceiptPreDbValidator();
  // Fixed reference time for deterministic testing: 15 Sep 2024 (Financial Year 2024-2025: 1 Jul 2024 - 30 Jun 2025)
  final mockNow = DateTime(2024, 9, 15, 14, 30);

  group('ReceiptPreDbValidator - Date Integrity Rules (ATO FY Compliance)', () {
    test('Accepts valid date within current Australian Financial Year', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Ampol Retail',
        amount: 85.50,
        gstAmount: 7.77,
        abn: '64 000 175 342',
        date: DateTime(2024, 8, 20), // Valid inside FY24-25
        category: ExpenseCategory.fuel,
        confidence: 0.95,
        evidence: [],
        rawText: 'Ampol',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isTrue);
      expect(result.severity, equals(ValidationSeverity.valid));
      expect(result.errorMessages, isEmpty);
    });

    test('REJECTS Future Date strictly', () {
      final ocr = ReceiptOcrResult(
        merchant: 'BP Connect',
        amount: 50.00,
        date: DateTime(2024, 9, 20), // 5 days in the future!
        category: ExpenseCategory.fuel,
        confidence: 0.90,
        evidence: [],
        rawText: 'BP',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isFalse);
      expect(result.severity, equals(ValidationSeverity.rejected));
      expect(result.errorMessages.any((e) => e.contains('Date in future')), isTrue);
    });

    test('REJECTS Backdated receipt outside current Australian Financial Year', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Shell Coles Express',
        amount: 110.00,
        date: DateTime(2023, 10, 19), // Prior FY (FY23-24 while mockNow is FY24-25)
        category: ExpenseCategory.fuel,
        confidence: 0.92,
        evidence: [],
        rawText: 'Shell',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isFalse);
      expect(result.severity, equals(ValidationSeverity.rejected));
      expect(
        result.errorMessages.any((e) => e.contains('outside current Australian Financial Year')),
        isTrue,
      );
    });

    test('REJECTS receipt prior to 1 July of active Logbook with Apple HIG microcopy', () {
      // User started logbook today: 13 Sep 2026 (FY 2026-27, starts 1 Jul 2026)
      final logbookStart = DateTime(2026, 9, 13);
      final systemNow = DateTime(2026, 9, 13, 16, 30);
      
      // User scans a receipt from January 2026 (prior FY 2025-26)
      final ocr = ReceiptOcrResult(
        merchant: 'Ampol Foodary',
        amount: 80.00,
        gstAmount: 7.27,
        date: DateTime(2026, 1, 15),
        category: ExpenseCategory.fuel,
        confidence: 0.95,
        evidence: [],
        rawText: 'Ampol',
      );

      final result = validator.validateAndSanitize(
        ocrResult: ocr,
        currentSystemTime: systemNow,
        logbookStartDate: logbookStart,
      );

      expect(result.isValid, isFalse);
      expect(result.severity, equals(ValidationSeverity.rejected));
      expect(result.humanGuidance, isNotNull);
      // Apple HIG Glanceability checks
      expect(result.humanGuidance!.title, equals('Receipt from last tax year'));
      expect(result.humanGuidance!.title.length, lessThanOrEqualTo(32)); // Title brevity
      expect(result.humanGuidance!.explanation, contains('1 July'));
      expect(result.humanGuidance!.primaryActionLabel, equals('Save Receipt'));
      expect(result.humanGuidance!.secondaryActionLabel, equals("Change Date"));
    });
  });

  group('ReceiptPreDbValidator - Amount & GST Financial Sanity Rules', () {
    test('REJECTS zero or negative amounts', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Caltex',
        amount: 0.00,
        date: DateTime(2024, 8, 10),
        category: ExpenseCategory.fuel,
        confidence: 0.5,
        evidence: [],
        rawText: '',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isFalse);
      expect(result.errorMessages.any((e) => e.contains('strictly greater than 0.00')), isTrue);
    });

    test('REJECTS GST greater than total amount', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Bunnings Warehouse',
        amount: 100.00,
        gstAmount: 120.00, // Impossible GST!
        date: DateTime(2024, 8, 10),
        category: ExpenseCategory.toolsMaterials,
        confidence: 0.8,
        evidence: [],
        rawText: '',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isFalse);
      expect(result.errorMessages.any((e) => e.contains('cannot exceed total amount')), isTrue);
    });

    test('WARNS when GST exceeds standard ATO 1/11th threshold', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Supercheap Auto',
        amount: 110.00,
        gstAmount: 25.00, // ATO expected is ~$10.00 (1/11th)
        date: DateTime(2024, 8, 10),
        category: ExpenseCategory.maintenanceTyres,
        confidence: 0.8,
        evidence: [],
        rawText: '',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isTrue); // Not fatal error, but needs review
      expect(result.severity, equals(ValidationSeverity.needsReview));
      expect(result.warningMessages.any((w) => w.contains('exceeds standard ATO 1/11th rate')), isTrue);
    });
  });

  group('ReceiptPreDbValidator - ABN ATO Modulus 89 & Merchant Sanitization', () {
    test('Cleans ABN into pure 11 digits and validates ATO Modulus 89 checksum', () {
      // Ampol genuine ABN: 64 000 175 342
      final ocr = ReceiptOcrResult(
        merchant: 'Ampol Retail Pty Ltd \n <script>alert(1)</script> | ~~',
        amount: 63.96,
        gstAmount: 4.95,
        abn: '64-000.175 342 (ABN)',
        date: DateTime(2024, 8, 10),
        category: ExpenseCategory.fuel,
        confidence: 0.95,
        evidence: [],
        rawText: '',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.isValid, isTrue);
      // Cleaned ABN: digits only
      expect(result.sanitizedAbn, equals('64000175342'));
      // Cleaned Merchant: stripped script brackets, pipes, tildes, newlines
      expect(result.sanitizedMerchant, equals('Ampol Retail Pty Ltd scriptalert(1)/script'));
    });

    test('WARNS when ABN fails ATO Modulus 89 checksum', () {
      final ocr = ReceiptOcrResult(
        merchant: 'Random Fuel',
        amount: 50.00,
        abn: '12345678901', // Invalid checksum!
        date: DateTime(2024, 8, 10),
        category: ExpenseCategory.fuel,
        confidence: 0.85,
        evidence: [],
        rawText: '',
      );

      final result = validator.validateAndSanitize(ocrResult: ocr, currentSystemTime: mockNow);
      expect(result.severity, equals(ValidationSeverity.needsReview));
      expect(result.warningMessages.any((w) => w.contains('failed official ATO Modulus 89')), isTrue);
    });
  });
}
