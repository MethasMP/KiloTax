import '../../data/models/annual_odometer.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import 'evidence_review_service.dart';

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

class AnnualOdometerComparison {
  final AnnualVehicleOdometer record;
  final List<Trip> trips;

  const AnnualOdometerComparison(this.record, this.trips);

  String? get problem {
    final end = record.closingDate;
    final closing = record.closingOdometer;
    if (end == null || closing == null) {
      return 'Closing date or reading not recorded';
    }
    if (!record.openingOdometer.isFinite ||
        !closing.isFinite ||
        record.openingOdometer < 0 ||
        closing < record.openingOdometer ||
        _day(end).isBefore(_day(record.openingDate))) {
      return 'Invalid odometer dates or readings; comparison unavailable';
    }
    return null;
  }

  List<Trip> get matchedTrips {
    if (problem != null) return const [];
    final start = _day(record.openingDate);
    final end = _day(record.closingDate!);
    return trips
        .where((trip) =>
            !_day(trip.date).isBefore(start) && !_day(trip.date).isAfter(end))
        .toList();
  }

  double? get odometerKm =>
      problem == null ? record.closingOdometer! - record.openingOdometer : null;
  double? get recordedKm => problem == null
      ? matchedTrips.fold<double>(0, (sum, trip) => sum + trip.distanceKm)
      : null;
  double? get differenceKm =>
      problem == null ? odometerKm! - recordedKm! : null;

  bool overlaps(AnnualOdometerComparison other) =>
      problem == null &&
      other.problem == null &&
      !_day(record.closingDate!).isBefore(_day(other.record.openingDate)) &&
      !_day(other.record.closingDate!).isBefore(_day(record.openingDate));
}

class ExpenseCategoryRecord {
  final ExpenseCategory category;
  double gross = 0;
  double basis = 0;
  double evidenceGap = 0;

  ExpenseCategoryRecord(this.category);
}

class TaxPackAnalysis {
  final EvidenceReviewReport report;
  final Map<String, ReceiptFileInspection> inspections;
  final Map<String, List<Map<String, dynamic>>> receiptPages;

  const TaxPackAnalysis(this.report, this.inspections, this.receiptPages);

  double get privateKm => report.trips
      .where((trip) => trip.classification != TripClassification.unclassified)
      .fold(0, (sum, trip) => sum + trip.distanceKm - trip.businessDistanceKm);
  double get undecidedKm => report.trips
      .where((trip) => trip.classification == TripClassification.unclassified)
      .fold(0, (sum, trip) => sum + trip.distanceKm);

  bool usableAud(VehicleExpense expense) =>
      expense.currency == 'AUD' &&
      expense.amount.isFinite &&
      expense.amount >= 0;
  bool get canIllustrateCosts =>
      report.expenses.where((expense) => !expense.isVaultOnly).every(usableAud);
  int get outsideAudCount =>
      report.expenses.where((expense) => !usableAud(expense)).length;

  bool hasCompleteFiles(VehicleExpense expense) {
    final pages = receiptPages[expense.id] ?? const [];
    return inspections[expense.id]?.status == ReceiptFileStatus.available &&
        pages.isNotEmpty &&
        pages.every((page) =>
            page['status'] == 'available' &&
            page['archivePath'] is String &&
            !(page['archivePath'] as String).endsWith('.bin'));
  }

  double get grossAud => report.expenses
      .where(usableAud)
      .fold(0, (sum, expense) => sum + expense.amount);
  double get vaultAud => report.expenses
      .where((expense) => usableAud(expense) && expense.isVaultOnly)
      .fold(0, (sum, expense) => sum + expense.amount);
  int get completeDocumentCount =>
      report.expenses.where(hasCompleteFiles).length;
  double get completeDocumentAud => report.expenses
      .where((expense) => usableAud(expense) && hasCompleteFiles(expense))
      .fold(0, (sum, expense) => sum + expense.amount);
  double get evidenceGapAud => grossAud - completeDocumentAud;

  List<ExpenseCategoryRecord> get categories {
    final rows = <ExpenseCategory, ExpenseCategoryRecord>{};
    ExpenseCategoryRecord row(ExpenseCategory category) =>
        rows.putIfAbsent(category, () => ExpenseCategoryRecord(category));
    for (final expense in report.expenses.where(usableAud)) {
      if (expense.allocations.isNotEmpty && expense.allocationError == null) {
        for (final line in expense.allocations) {
          final result = row(line.category ?? expense.category);
          result.gross += line.amount;
          if (!hasCompleteFiles(expense)) result.evidenceGap += line.amount;
        }
      } else {
        final result = row(expense.category);
        result.gross += expense.amount;
        if (!hasCompleteFiles(expense)) result.evidenceGap += expense.amount;
      }
      for (final component in expense.claimComponents) {
        row(component.category).basis +=
            component.category.isDirectlyDeductibleByDefault
                ? component.amount * component.businessPercentage / 100
                : component.amount;
      }
    }
    return rows.values.toList()
      ..sort((a, b) => a.category.index.compareTo(b.category.index));
  }

  double get runningBasis => categories
      .where((row) => !row.category.isDirectlyDeductibleByDefault)
      .fold(0, (sum, row) => sum + row.basis);
  double get directBasis => categories
      .where((row) => row.category.isDirectlyDeductibleByDefault)
      .fold(0, (sum, row) => sum + row.basis);
  double get excludedAllocationAud =>
      grossAud - vaultAud - runningBasis - directBasis;
}
