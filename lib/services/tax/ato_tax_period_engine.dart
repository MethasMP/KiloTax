import 'package:flutter/foundation.dart';

/// Represents the lifecycle phase of an Australian Financial Year at any given date.
enum TaxSeasonPhase {
  /// Regular earning and expense incurring period (1 July - 30 June)
  activeSpending,

  /// General public self-lodgment window (1 July - 31 October following FY close)
  selfLodgmentWindow,

  /// Extended Tax Agent window (1 November - 15 May following year)
  taxAgentExtendedWindow,

  /// Closed financial year (archived, requires formal amendment to claim)
  closedArchived,
}

/// Action recommendation for a scanned receipt based on date heuristics.
enum ReceiptRoutingDecision {
  /// Saved directly to current active financial year
  saveToCurrentFinancialYear,

  /// Scanned during tax season: belonged to just-ended FY, can be lodged now
  claimInPendingTaxReturn,

  /// Rejected because date is in the future
  rejectedFutureDate,

  /// Stale historical receipt beyond active claim window
  rejectedStalePriorYear,
}

/// Financial Year snapshot container with strict ATO cut-off dates.
@immutable
class AtoFinancialYear {
  final int startYear; // e.g. 2026 for FY 2026-27
  final int endYear;   // e.g. 2027

  const AtoFinancialYear(this.startYear) : endYear = startYear + 1;

  /// FY string format e.g. 'FY 2026–27'
  String get label => 'FY $startYear–${endYear.toString().substring(2)}';

  /// 1 July 00:00:00
  DateTime get startDate => DateTime(startYear, 7, 1);

  /// 30 June 23:59:59 (Last second to incur an expense)
  DateTime get expenseCutoffDate => DateTime(endYear, 6, 30, 23, 59, 59);

  /// 1 July 00:00:00 (Tax lodgment season opens)
  DateTime get lodgmentOpenDate => DateTime(endYear, 7, 1);

  /// 31 October 23:59:59 (Strict deadline for self-lodgers via myGov)
  DateTime get selfLodgeDeadline => DateTime(endYear, 10, 31, 23, 59, 59);

  /// 15 May 23:59:59 (Extended deadline when registered with a Tax Agent)
  DateTime get taxAgentDeadline => DateTime(endYear + 1, 5, 15, 23, 59, 59);

  bool containsExpenseDate(DateTime date) {
    return (date.isAfter(startDate) || date.isAtSameMomentAs(startDate)) &&
        (date.isBefore(expenseCutoffDate) || date.isAtSameMomentAs(expenseCutoffDate));
  }
}

/// Zero-Confusion ATO Tax Timeline & Receipt Routing Engine
class AtoTaxPeriodEngine {
  const AtoTaxPeriodEngine();

  /// Gets the financial year for any given expense/receipt date.
  AtoFinancialYear forDate(DateTime date) {
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    return AtoFinancialYear(startYear);
  }

  /// Evaluates current system date against a financial year to determine active phase.
  TaxSeasonPhase determinePhase({
    required AtoFinancialYear fy,
    required DateTime systemDate,
    bool hasRegisteredTaxAgent = false,
  }) {
    if (systemDate.isBefore(fy.lodgmentOpenDate)) {
      return TaxSeasonPhase.activeSpending;
    }
    if (systemDate.isBefore(fy.selfLodgeDeadline) ||
        systemDate.isAtSameMomentAs(fy.selfLodgeDeadline)) {
      return TaxSeasonPhase.selfLodgmentWindow;
    }
    if (hasRegisteredTaxAgent) {
      if (systemDate.isBefore(fy.taxAgentDeadline) ||
          systemDate.isAtSameMomentAs(fy.taxAgentDeadline)) {
        return TaxSeasonPhase.taxAgentExtendedWindow;
      }
    }
    return TaxSeasonPhase.closedArchived;
  }

  /// Evaluates where a scanned receipt belongs without confusing the user.
  ReceiptRoutingDecision routeReceipt({
    required DateTime receiptDate,
    required DateTime systemDate,
    bool hasRegisteredTaxAgent = false,
  }) {
    // 1. Prevent future dates
    if (receiptDate.isAfter(systemDate.add(const Duration(minutes: 5)))) {
      return ReceiptRoutingDecision.rejectedFutureDate;
    }

    final currentFy = forDate(systemDate);

    // 2. Receipt belongs to current active spending year
    if (currentFy.containsExpenseDate(receiptDate)) {
      return ReceiptRoutingDecision.saveToCurrentFinancialYear;
    }

    // 3. Receipt belongs to prior year, but we are currently in tax season for that prior year
    final priorFy = AtoFinancialYear(currentFy.startYear - 1);
    if (priorFy.containsExpenseDate(receiptDate)) {
      final priorPhase = determinePhase(
        fy: priorFy,
        systemDate: systemDate,
        hasRegisteredTaxAgent: hasRegisteredTaxAgent,
      );
      if (priorPhase == TaxSeasonPhase.selfLodgmentWindow ||
          priorPhase == TaxSeasonPhase.taxAgentExtendedWindow) {
        return ReceiptRoutingDecision.claimInPendingTaxReturn;
      }
    }

    // 4. Stale receipt from 2+ years ago or closed period
    return ReceiptRoutingDecision.rejectedStalePriorYear;
  }

  /// Calculates human-friendly countdown message for dashboard UI.
  String getTaxSeasonCountdownMessage({
    required DateTime systemDate,
    bool hasRegisteredTaxAgent = false,
  }) {
    final currentFy = forDate(systemDate);
    final priorFy = AtoFinancialYear(currentFy.startYear - 1);
    final phase = determinePhase(
      fy: priorFy,
      systemDate: systemDate,
      hasRegisteredTaxAgent: hasRegisteredTaxAgent,
    );

    switch (phase) {
      case TaxSeasonPhase.activeSpending:
        final daysLeft = priorFy.expenseCutoffDate.difference(systemDate).inDays;
        return '$daysLeft days left in ${priorFy.label} expense cycle';
      case TaxSeasonPhase.selfLodgmentWindow:
        final days = priorFy.selfLodgeDeadline.difference(systemDate).inDays;
        return 'Tax Season (${priorFy.label}): $days days remaining until 31 Oct deadline!';
      case TaxSeasonPhase.taxAgentExtendedWindow:
        final days = priorFy.taxAgentDeadline.difference(systemDate).inDays;
        return 'Tax Agent Extension (${priorFy.label}): $days days left until 15 May deadline';
      case TaxSeasonPhase.closedArchived:
        return 'Tax year ${priorFy.label} is finalized.';
    }
  }
}
