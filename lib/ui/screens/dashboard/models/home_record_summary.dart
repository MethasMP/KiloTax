import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/tax_summary.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../services/engine/evidence_review_service.dart';
import '../../../../services/engine/tax_calculator_service.dart';

class HomeRecordSummary {
  final EvidenceReviewReport report;
  final TaxSummary reviewed;
  final List<EvidenceReviewItem> pendingItems;
  final AtoTaxRule taxRule;
  final int reviewedTripCount;
  final int reviewedExpenseCount;
  final int elapsedDays;
  final double? deduction;

  const HomeRecordSummary._({
    required this.report,
    required this.reviewed,
    required this.pendingItems,
    required this.taxRule,
    required this.reviewedTripCount,
    required this.reviewedExpenseCount,
    required this.elapsedDays,
    required this.deduction,
  });

  factory HomeRecordSummary.fromReport(EvidenceReviewReport report,
      {required AtoTaxRule taxRule, required DateTime now}) {
    final pendingItems = List<EvidenceReviewItem>.unmodifiable(report.items
        .where((item) =>
            item is! ExpenseReviewItem ||
            item.reasons.any(
                (reason) => reason != ExpenseReviewReason.uncheckedPhoto)));
    final pendingTrips = pendingItems
        .whereType<TripReviewItem>()
        .map((item) => item.tripId)
        .toSet();
    final pendingExpenses = pendingItems
        .whereType<ExpenseReviewItem>()
        .map((item) => item.expenseId)
        .toSet();
    final trips =
        report.trips.where((trip) => !pendingTrips.contains(trip.id)).toList();
    final expenses = report.expenses
        .where((expense) =>
            !expense.isVaultOnly && !pendingExpenses.contains(expense.id))
        .toList();
    final reviewed = TaxCalculatorService.evaluateSummary(
        trips: trips, expenses: expenses, taxRule: taxRule);
    final start = report.vehicle?.logbookStartDate;
    final elapsed = start == null
        ? 0
        : DateTime(now.year, now.month, now.day)
                .difference(DateTime(start.year, start.month, start.day))
                .inDays +
            1;
    final isCpk = report.vehicle?.taxMethod == TaxMethod.centsPerKm;
    final hasLogbookBasis = report.vehicle?.taxMethod != TaxMethod.logbook ||
        (start != null && (report.vehicle?.initialOdometer ?? 0) > 0);
    final hasBasis =
        trips.isNotEmpty && hasLogbookBasis && (isCpk || expenses.isNotEmpty);
    return HomeRecordSummary._(
      report: report,
      reviewed: reviewed,
      pendingItems: pendingItems,
      taxRule: taxRule,
      reviewedTripCount: trips.length,
      reviewedExpenseCount: expenses.length,
      elapsedDays: elapsed.clamp(0, AppConstants.statutoryLogbookDays),
      deduction: hasBasis
          ? isCpk
              ? reviewed.centsPerKmClaim
              : reviewed.logbookClaim
          : null,
    );
  }

  bool get isCpk => report.vehicle?.taxMethod == TaxMethod.centsPerKm;
  bool get isLogbook => report.vehicle?.taxMethod == TaxMethod.logbook;
  bool get hasLogbookStart => report.vehicle?.logbookStartDate != null;
}
