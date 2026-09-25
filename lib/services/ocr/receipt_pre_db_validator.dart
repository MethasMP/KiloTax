import '../../data/models/vehicle_expense.dart';
import '../tax/ato_tax_period_engine.dart';
import 'receipt_intelligence_service.dart';

/// Validation status returned by the pre-database guardrail.
enum ValidationSeverity {
  valid,
  needsReview,
  rejected,
}

/// Human-friendly explanation designed according to Apple Human Interface Guidelines.
class HumanizedValidationError {
  final String title;
  final String explanation;
  final String primaryActionLabel;
  final String secondaryActionLabel;

  const HumanizedValidationError({
    required this.title,
    required this.explanation,
    required this.primaryActionLabel,
    this.secondaryActionLabel = 'Cancel',
  });
}

/// Comprehensive validation & sanitization result before persistence.
class ReceiptValidationResult {
  final ValidationSeverity severity;
  final bool isValid;
  final List<String> errorMessages;
  final List<String> warningMessages;
  final HumanizedValidationError? humanGuidance;

  // Sanitized / normalized values ready for DB insertion
  final String sanitizedMerchant;
  final double sanitizedAmount;
  final double? sanitizedGstAmount;
  final String? sanitizedAbn;
  final DateTime validatedDate;
  final ExpenseCategory validatedCategory;

  // Tax isolation guardrails
  final bool isVaultOnlyRecommended;
  final String? vaultReason;
  final double? recommendedCappedGst;

  const ReceiptValidationResult({
    required this.severity,
    required this.isValid,
    required this.errorMessages,
    required this.warningMessages,
    required this.sanitizedMerchant,
    required this.sanitizedAmount,
    required this.sanitizedGstAmount,
    required this.sanitizedAbn,
    required this.validatedDate,
    required this.validatedCategory,
    this.humanGuidance,
    this.isVaultOnlyRecommended = false,
    this.vaultReason,
    this.recommendedCappedGst,
  });
}

/// Pre-Database Gatekeeper: Enforces strict ATO tax integrity with Apple Human Interface microcopy.
class ReceiptPreDbValidator {
  const ReceiptPreDbValidator();

  /// Validates and sanitizes raw OCR extraction before saving to SQLite/Database.
  ReceiptValidationResult validateAndSanitize({
    required ReceiptOcrResult ocrResult,
    DateTime? currentSystemTime,
    DateTime? logbookStartDate,
  }) {
    final now = currentSystemTime ?? DateTime.now();
    final errors = <String>[];
    final warnings = <String>[];
    HumanizedValidationError? humanGuidance;
    bool isVaultOnly = false;
    String? vaultReason;
    double? recommendedCappedGst;

    final taxEngine = const AtoTaxPeriodEngine();
    final receiptDate = ocrResult.date;
    final currentFy = taxEngine.forDate(now);

    // ==========================================
    // 1. DATE VALIDATION & LOGBOOK BOUNDARY
    // ==========================================
    if (receiptDate.isAfter(now.add(const Duration(minutes: 5)))) {
      errors.add('Date in future: ${receiptDate.toIso8601String().split('T').first}');
      humanGuidance = const HumanizedValidationError(
        title: 'Check receipt date',
        explanation: 'The camera detected a future date on this receipt. Would you like to use today\'s date instead?',
        primaryActionLabel: 'Use Today\'s Date',
        secondaryActionLabel: 'Change Date',
      );
    } else if (logbookStartDate != null) {
      final logbookFyStart = taxEngine.forDate(logbookStartDate).startDate;
      if (receiptDate.isBefore(logbookFyStart)) {
        errors.add('Receipt date precedes logbook active financial year');
        isVaultOnly = true;
        vaultReason = 'prior_tax_year';
        humanGuidance = const HumanizedValidationError(
          title: 'Receipt from last tax year',
          explanation:
              'This purchase is dated before 1 July. We\'ll save the photo for your records so you have proof, without mixing it into this year\'s tax claim.',
          primaryActionLabel: 'Save Receipt',
          secondaryActionLabel: 'Change Date',
        );
      }
    } else if (receiptDate.isBefore(currentFy.startDate)) {
      errors.add('Date is outside current Australian Financial Year');
      isVaultOnly = true;
      vaultReason = 'prior_tax_year';
      humanGuidance = const HumanizedValidationError(
        title: 'Receipt from last tax year',
        explanation:
            'This purchase is dated before 1 July. We\'ll save the photo for your records so you have proof, without mixing it into this year\'s tax claim.',
        primaryActionLabel: 'Save Receipt',
        secondaryActionLabel: 'Change Date',
      );
    }

    // ==========================================
    // 2. AMOUNT VALIDATION (PURE NUMERIC > 0)
    // ==========================================
    double cleanAmount = ocrResult.amount;
    if (cleanAmount <= 0.0) {
      errors.add('Amount must be strictly greater than 0.00');
      humanGuidance ??= const HumanizedValidationError(
        title: 'Amount not detected',
        explanation: 'We couldn\'t clearly read the total amount from this receipt. Please type the amount below.',
        primaryActionLabel: 'Enter Amount',
        secondaryActionLabel: 'Retake Photo',
      );
    }
    cleanAmount = double.parse(cleanAmount.toStringAsFixed(2));

    // ==========================================
    // 3. GST VALIDATION (ATO 1/11th STANDARD)
    // ==========================================
    double? cleanGst = ocrResult.gstAmount;
    if (cleanGst != null) {
      cleanGst = double.parse(cleanGst.toStringAsFixed(2));
      if (cleanGst < 0.0) {
        errors.add('GST cannot be negative: \$${cleanGst.toStringAsFixed(2)}');
      } else if (cleanGst > cleanAmount) {
        errors.add('GST (\$${cleanGst.toStringAsFixed(2)}) cannot exceed total amount (\$${cleanAmount.toStringAsFixed(2)})');
      } else {
        final maxTheoreticalGst = double.parse(((cleanAmount / 11.0) + 0.05).toStringAsFixed(2));
        final legalMaxGst = double.parse((cleanAmount / 11.0).toStringAsFixed(2));
        if (cleanGst > maxTheoreticalGst) {
          recommendedCappedGst = legalMaxGst;
          warnings.add(
            'GST (\$${cleanGst.toStringAsFixed(2)}) exceeds standard ATO 1/11th rate for total \$${cleanAmount.toStringAsFixed(2)} (max expected: \$${maxTheoreticalGst.toStringAsFixed(2)})',
          );
          humanGuidance ??= HumanizedValidationError(
            title: 'Check GST amount',
            explanation:
                'For a \$${cleanAmount.toStringAsFixed(2)} purchase, GST cannot exceed \$${legalMaxGst.toStringAsFixed(2)}. The camera may have misread the tax line.',
            primaryActionLabel: 'Fix to \$${legalMaxGst.toStringAsFixed(2)}',
            secondaryActionLabel: 'Keep \$${cleanGst.toStringAsFixed(2)}',
          );
        }
      }
    }

    // ==========================================
    // 4. ABN & MERCHANT SANITIZATION
    // ==========================================
    String? cleanAbn;
    if (ocrResult.abn != null && ocrResult.abn!.trim().isNotEmpty) {
      cleanAbn = ocrResult.abn!.replaceAll(RegExp(r'\D'), '');
      if (cleanAbn.length != 11) {
        warnings.add('ABN must be exactly 11 digits (found: $cleanAbn, length: ${cleanAbn.length})');
      } else if (!isValidAtoAbnChecksum(cleanAbn)) {
        warnings.add('ABN $cleanAbn failed official ATO Modulus 89 checksum verification');
      }
    }

    String cleanMerchant = ocrResult.merchant
        .replaceAll(RegExp(r'[\r\n\t\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'[|~¥§©®<>\{\}\[\]\\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanMerchant.isEmpty) {
      warnings.add('Merchant empty');
      cleanMerchant = 'Fuel & Vehicle Expense';
    }

    final severity = errors.isNotEmpty
        ? ValidationSeverity.rejected
        : warnings.isNotEmpty
            ? ValidationSeverity.needsReview
            : ValidationSeverity.valid;

    return ReceiptValidationResult(
      severity: severity,
      isValid: errors.isEmpty,
      errorMessages: errors,
      warningMessages: warnings,
      humanGuidance: humanGuidance,
      sanitizedMerchant: cleanMerchant,
      sanitizedAmount: cleanAmount,
      sanitizedGstAmount: cleanGst,
      sanitizedAbn: cleanAbn,
      validatedDate: receiptDate,
      validatedCategory: ocrResult.category,
      isVaultOnlyRecommended: isVaultOnly,
      vaultReason: vaultReason,
      recommendedCappedGst: recommendedCappedGst,
    );
  }

  /// Validates tax method compatibility (e.g. Cents-per-km vs Fuel/Repairs double-dipping)
  HumanizedValidationError? checkMethodConflict({
    required bool isCentsPerKm,
    required ExpenseCategory category,
    required int rateCents,
    String vehicleName = 'vehicle',
  }) {
    if (isCentsPerKm && category.isCarExpense) {
      return HumanizedValidationError(
        title: 'Fuel already covered',
        explanation:
            'Your $vehicleName is claiming ${rateCents}c/km, which already includes fuel and servicing. We\'ll store the receipt for your records without claiming it twice.',
        primaryActionLabel: 'Save Receipt',
        secondaryActionLabel: 'Cancel',
      );
    }
    return null;
  }

  /// ATO Modulus 89 Algorithm
  static bool isValidAtoAbnChecksum(String abnDigits) {
    if (abnDigits.length != 11) return false;
    const weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      final digit = int.tryParse(abnDigits[i]);
      if (digit == null) return false;
      final effectiveDigit = (i == 0) ? (digit - 1) : digit;
      sum += effectiveDigit * weights[i];
    }
    return sum % 89 == 0;
  }
}
