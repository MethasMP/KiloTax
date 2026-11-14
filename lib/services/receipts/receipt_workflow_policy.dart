import '../../data/models/vehicle_expense.dart';
import '../ocr/receipt_intelligence_service.dart';
import '../ocr/receipt_pre_db_validator.dart';

/// The same gates apply after extraction, after edits and immediately before commit.
class ReceiptWorkflowPolicy {
  const ReceiptWorkflowPolicy();

  List<String> approvalIssues(VehicleExpense expense) {
    final audit = expense.receiptAudit;
    if (audit == null || audit.reviewStatus != ReceiptReviewStatus.confirmed) {
      return [];
    }
    final issues = <String>[];
    if (audit.reviewedRevision != null &&
        audit.reviewedRevision != audit.revision) {
      issues.add('Receipt changed after approval');
    }
    final actual = <String, dynamic>{
      'merchant': expense.supplier,
      'vehicleId': expense.vehicleId,
      'amount': expense.amount,
      'date': expense.date.toIso8601String(),
      'currency': expense.currency,
      'category': expense.category.name,
      'gstAmount': expense.gstAmount,
      'abn': expense.supplierAbn,
      'invoiceNumber': expense.invoiceNumber,
      'allocations': expense.allocations.map((a) => a.toJson()).toList()
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

    for (final entry in actual.entries) {
      if (!audit.currentFields.containsKey(entry.key)) continue;
      final approved = audit.currentFields[entry.key];
      if (!same(approved, entry.value)) {
        issues.add('Review changed ${entry.key} before saving');
      }
    }
    return issues;
  }

  List<String> coreIssues(VehicleExpense expense, {DateTime? now}) {
    final issues = <String>[];
    if (!expense.amount.isFinite ||
        expense.amount <= 0 ||
        (expense.amount * 100 - (expense.amount * 100).round()).abs() >
            0.00001) {
      issues.add('Enter a positive total with at most two decimal places');
    }
    if (expense.currency != 'AUD') {
      issues.add(expense.currency == null
          ? 'Confirm receipt currency'
          : 'Foreign currency requires review; no automatic AUD conversion');
    }
    if (expense.date
        .isAfter((now ?? DateTime.now()).add(const Duration(minutes: 5)))) {
      issues.add('Choose the actual purchase date');
    }
    if (expense.allocationError != null) issues.add(expense.allocationError!);
    return issues;
  }

  List<String> reviewIssues(
    VehicleExpense expense, {
    bool purchaseDateUnknown = false,
    bool extractionReviewed = false,
    bool duplicateReviewed = false,
    Iterable<VehicleExpense> others = const [],
    DateTime? now,
  }) {
    final issues = coreIssues(expense, now: now);
    if (purchaseDateUnknown) issues.add('Choose purchase date');
    if (expense.supplier?.trim().isEmpty ?? true) issues.add('Check merchant');
    final raw = expense.receiptAudit?.rawOcrText;
    final parsed = raw == null
        ? null
        : const ReceiptIntelligenceService().analyseText(raw);
    if (parsed != null && parsed.hasMixedItems && expense.allocations.isEmpty) {
      issues.add('Split mixed vehicle and private items');
    }
    if (expense.allocations
        .any((a) => a.purpose == AllocationPurpose.unresolved)) {
      issues.add('Resolve uncertain item allocations');
    }
    if (!extractionReviewed && (parsed == null || !parsed.isHighConfidence)) {
      issues.add('Check extracted details');
    }
    if (!extractionReviewed && !expense.category.isCarExpense) {
      issues.add('Review category and work/private use');
    }
    if (!duplicateReviewed &&
        others.any((e) => possibleDuplicate(expense, e))) {
      issues.add('Possible duplicate — review before keeping separately');
    }
    final validation = const ReceiptPreDbValidator().validateAndSanitize(
      ocrResult: ReceiptOcrResult(
          merchant: expense.supplier ?? '',
          amount: expense.amount,
          date: expense.date,
          category: expense.category,
          confidence: 0,
          gstAmount: expense.gstAmount,
          abn: expense.supplierAbn,
          currency: expense.currency,
          evidence: const [],
          rawText: raw ?? ''),
      currentSystemTime: now,
    );
    if (validation.isVaultOnlyRecommended && !expense.isVaultOnly) {
      issues.add('Review receipt period before recording');
    }
    if (!extractionReviewed && validation.warningMessages.isNotEmpty) {
      issues.addAll(validation.warningMessages);
    }
    return issues.toSet().toList();
  }

  bool possibleDuplicate(VehicleExpense left, VehicleExpense right) {
    if (left.id == right.id || right.isDeleted) return false;
    if (left.sha256Hash != null && left.sha256Hash == right.sha256Hash) {
      return true;
    }
    if (left.invoiceNumber?.trim().isNotEmpty == true &&
        left.invoiceNumber == right.invoiceNumber &&
        left.supplier?.trim().toLowerCase() ==
            right.supplier?.trim().toLowerCase()) {
      return true;
    }
    return left.supplier?.trim().isNotEmpty == true &&
        left.supplier?.trim().toLowerCase() ==
            right.supplier?.trim().toLowerCase() &&
        left.currency == right.currency &&
        (left.amount - right.amount).abs() < 0.005 &&
        left.date.year == right.date.year &&
        left.date.month == right.date.month &&
        left.date.day == right.date.day;
  }
}
