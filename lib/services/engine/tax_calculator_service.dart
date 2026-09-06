import '../../core/constants/app_constants.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/tax_summary.dart';

class TaxCalculatorService {
  /// CENTS / KM (Layer 4A):
  /// Statutory formula: min(Business KM, 5,000) * $0.91
  static double calculateCentsPerKm(double businessKm) {
    if (businessKm <= 0) return 0.0;
    final eligibleKm = businessKm > AppConstants.centsPerKmCapKm
        ? AppConstants.centsPerKmCapKm
        : businessKm;
    return eligibleKm * AppConstants.centsPerKmRate2026;
  }

  /// LOGBOOK BUSINESS-USE % (Layer 4B):
  /// Statutory formula: (Business KM / Total KM) * 100
  static double calculateBusinessPercentage(double businessKm, double totalKm) {
    if (totalKm <= 0 || businessKm <= 0) return 0.0;
    final percent = (businessKm / totalKm) * 100.0;
    return percent > 100.0 ? 100.0 : percent;
  }

  /// LOGBOOK CLAIM AMOUNT:
  /// (Eligible Running Expenses * Business-Use %) + 100% Direct Tolls/Parking
  static double calculateLogbookClaim({
    required List<VehicleExpense> expenses,
    required double businessPercentage,
  }) {
    double runningTotal = 0.0;
    double directTotal = 0.0;

    for (final exp in expenses) {
      if (exp.category == ExpenseCategory.tollsParking) {
        // Direct deduction: work parking/tolls are 100% claimable
        directTotal += exp.amount * (exp.businessPercentage / 100.0);
      } else {
        // Scaled by logbook business %
        runningTotal += exp.amount;
      }
    }

    final scaledRunning = runningTotal * (businessPercentage / 100.0);
    return scaledRunning + directTotal;
  }

  /// TAX SUMMARY (Layer 5):
  /// Evaluates both methods and generates the comparison report
  static TaxSummary evaluateSummary({
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
  }) {
    double businessKm = 0.0;
    double personalKm = 0.0;

    for (final t in trips) {
      if (t.isBusiness) {
        businessKm += t.distanceKm;
      } else {
        personalKm += t.distanceKm;
      }
    }

    final totalKm = businessKm + personalKm;
    final businessPct = calculateBusinessPercentage(businessKm, totalKm);

    double totalRunning = 0.0;
    double totalDirect = 0.0;

    for (final exp in expenses) {
      if (exp.category == ExpenseCategory.tollsParking) {
        totalDirect += exp.amount * (exp.businessPercentage / 100.0);
      } else {
        totalRunning += exp.amount;
      }
    }

    final centsClaim = calculateCentsPerKm(businessKm);
    final logbookClaim = (totalRunning * (businessPct / 100.0)) + totalDirect;

    final recommended = logbookClaim >= centsClaim
        ? RecommendedMethod.logbook
        : RecommendedMethod.centsPerKm;

    final diff = (logbookClaim - centsClaim).abs();

    return TaxSummary(
      totalKm: totalKm,
      businessKm: businessKm,
      personalKm: personalKm,
      businessPercentage: businessPct,
      totalRunningExpenses: totalRunning,
      totalDirectDeductions: totalDirect,
      centsPerKmClaim: centsClaim,
      logbookClaim: logbookClaim,
      recommendedMethod: recommended,
      taxSavingsDiff: diff,
    );
  }
}
