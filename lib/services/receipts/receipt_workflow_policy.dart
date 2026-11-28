import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../ocr/receipt_fallback_engine.dart';
import '../ocr/receipt_intelligence_service.dart';
import '../ocr/receipt_ocr_engine.dart';
import '../ocr/receipt_pre_db_validator.dart';
import '../ocr/spatial_receipt_parser.dart';
import '../tracking/trade_poi_resolver.dart';

/// The same gates apply after extraction, after edits and immediately before commit.
class ReceiptWorkflowPolicy {
  final ReceiptFallbackEngine? fallbackEngine;

  const ReceiptWorkflowPolicy({this.fallbackEngine});

  /// Runs [ReceiptIntelligenceService.analyseText] and fuses context hints from
  /// nearby work trips (trade POI geofences) and prior expenses when OCR misses
  /// merchant, ABN, or category details.
  ReceiptOcrResult analyseWithContext(
    String rawText, {
    DateTime? fallbackDate,
    List<ReceiptOcrBlock>? blocks,
    SpatialParsedReceipt? spatialParsed,
    Iterable<Trip> trips = const [],
    Iterable<VehicleExpense> existingExpenses = const [],
    ReceiptIntelligenceService intelligence =
        const ReceiptIntelligenceService(),
  }) {
    final initial = intelligence.analyseText(
      rawText,
      fallbackDate: fallbackDate,
      blocks: blocks,
      spatialParsed: spatialParsed,
    );

    final activeExpenses = existingExpenses
        .where((e) => !e.isDeleted)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final hasExplicitCategorySignal =
        intelligence.classify(rawText).evidence.isNotEmpty;

    String? merchantHint;
    String? abnHint;
    ExpenseCategory? categoryHint;

    String normalizeDigits(String value) =>
        value.replaceAll(RegExp(r'\D'), '');

    final merchantText = initial.merchant.trim();
    final hasUsableMerchant = merchantText.isNotEmpty &&
        !RegExp(
          r'(\$|smudge|illegible|total|subtotal|gst|eftpos|visa|mastercard|cash|change|date|time|invoice|receipt|\d+\.\d{2})',
          caseSensitive: false,
        ).hasMatch(merchantText);

    if (initial.abn != null) {
      final abnDigits = normalizeDigits(initial.abn!);
      for (final e in activeExpenses) {
        final existingAbn = e.supplierAbn;
        if (existingAbn != null &&
            normalizeDigits(existingAbn) == abnDigits) {
          if (!hasUsableMerchant &&
              (e.supplier?.trim().isNotEmpty ?? false)) {
            merchantHint = e.supplier!.trim();
          }
          if (!hasExplicitCategorySignal) {
            categoryHint = e.category;
          }
          break;
        }
      }
    }

    final knownMerchant = (merchantHint ?? (hasUsableMerchant ? merchantText : '')).trim();
    if (knownMerchant.isNotEmpty) {
      final merchantLower = knownMerchant.toLowerCase();
      for (final e in activeExpenses) {
        if ((e.supplier?.trim().toLowerCase() ?? '') == merchantLower) {
          if (initial.abn == null &&
              abnHint == null &&
              (e.supplierAbn?.trim().isNotEmpty ?? false)) {
            abnHint = e.supplierAbn!.trim();
          }
          if (!hasExplicitCategorySignal && categoryHint == null) {
            categoryHint = e.category;
          }
          if (abnHint != null &&
              (hasExplicitCategorySignal || categoryHint != null)) {
            break;
          }
        }
      }
    }

    final refTime = initial.parsedDate ?? fallbackDate ?? DateTime.now();
    final hasTimeOfDay = initial.parsedDate != null &&
        (initial.parsedDate!.hour != 0 ||
            initial.parsedDate!.minute != 0 ||
            initial.parsedDate!.second != 0);
    String? poiMerchant;
    Duration? bestDelta;

    for (final t in trips) {
      if (t.isDeleted || t.classification == TripClassification.personal) {
        continue;
      }
      final tripTime = t.stoppedAt ?? t.date;
      final sameDay = tripTime.year == refTime.year &&
          tripTime.month == refTime.month &&
          tripTime.day == refTime.day;
      final delta = tripTime.difference(refTime).abs();
      final withinWindow = hasTimeOfDay
          ? delta <= const Duration(hours: 4)
          : (sameDay || delta <= const Duration(hours: 4));
      if (!withinWindow) continue;

      final resolvedPoi = (t.detectedPoi?['merchantName'] as String?)?.trim();
      final tradeMatch = (resolvedPoi != null && resolvedPoi.isNotEmpty)
          ? resolvedPoi
          : (TradePoiResolver.resolve(t.destinationAddress) ??
                  TradePoiResolver.resolve(t.purpose))
              ?.merchantName;
      if (tradeMatch == null || tradeMatch.isEmpty) continue;

      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        poiMerchant = tradeMatch;
      }
    }

    if (poiMerchant != null) {
      final ocrPoiName = !hasUsableMerchant
          ? null
          : TradePoiResolver.resolve(merchantText)?.merchantName;
      final matchesPoi = !hasUsableMerchant ||
          (ocrPoiName != null &&
              ocrPoiName.toLowerCase() == poiMerchant.toLowerCase());

      if (!hasUsableMerchant && merchantHint == null) {
        merchantHint = poiMerchant;
      }
      if (matchesPoi && !hasExplicitCategorySignal && categoryHint == null) {
        categoryHint = ExpenseCategory.toolsMaterials;
      }
      if (matchesPoi && initial.abn == null && abnHint == null) {
        final poiLower = poiMerchant.toLowerCase();
        for (final e in activeExpenses) {
          if ((e.supplier?.trim().toLowerCase() ?? '') == poiLower &&
              (e.supplierAbn?.trim().isNotEmpty ?? false)) {
            abnHint = e.supplierAbn!.trim();
            break;
          }
        }
      }
    }

    if (merchantHint == null && abnHint == null && categoryHint == null) {
      return initial;
    }

    return intelligence.analyseText(
      rawText,
      fallbackDate: fallbackDate,
      blocks: blocks,
      spatialParsed: spatialParsed,
      contextMerchantHint: merchantHint,
      contextAbnHint: abnHint,
      contextCategoryHint: categoryHint,
    );
  }

  /// Evaluates an extraction or processed receipt against confidence gates and
  /// dispatches to the fallback engine asynchronously if confidence is low.
  ///
  /// Returns the original [initialResult] if high confidence or if no fallback engine is configured.
  /// If !initialResult.isHighConfidence and a [fallbackEngine] is provided, executes fallback
  /// parsing and returns the fallback result if non-null, else [initialResult].
  Future<ReceiptOcrResult> processWithFallback({
    required ReceiptOcrResult initialResult,
    required String imagePath,
  }) async {
    if (initialResult.isHighConfidence || fallbackEngine == null) {
      return initialResult;
    }

    try {
      final fallbackResult = await fallbackEngine!.parseImage(imagePath);
      return fallbackResult ?? initialResult;
    } catch (_) {
      return initialResult;
    }
  }

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
    Iterable<Trip> trips = const [],
    DateTime? now,
  }) {
    final issues = coreIssues(expense, now: now);
    if (purchaseDateUnknown) issues.add('Choose purchase date');
    if (expense.supplier?.trim().isEmpty ?? true) issues.add('Check merchant');
    final raw = expense.receiptAudit?.rawOcrText;
    final otherExpenses =
        others.where((e) => !e.isDeleted && e.id != expense.id).toList();
    final parsed = raw == null
        ? null
        : analyseWithContext(
            raw,
            fallbackDate: expense.date,
            trips: trips,
            existingExpenses: otherExpenses,
          );
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
    final existingReceipts = duplicateReviewed
        ? const <ReceiptFingerprint>[]
        : otherExpenses
            .map((e) => ReceiptFingerprint(
                  merchant: e.supplier ?? '',
                  amount: e.amount,
                  date: e.date,
                ))
            .toList(growable: false);
    final validation = const ReceiptPreDbValidator().validateAndSanitize(
      ocrResult: ReceiptOcrResult(
          merchant: expense.supplier ?? '',
          amount: expense.amount,
          date: expense.date,
          dateNeedsReview: purchaseDateUnknown,
          category: expense.category,
          confidence: 0,
          gstAmount: expense.gstAmount,
          abn: expense.supplierAbn,
          currency: expense.currency,
          evidence: const [],
          rawText: raw ?? expense.notes ?? ''),
      currentSystemTime: now,
      existingReceipts: existingReceipts,
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
