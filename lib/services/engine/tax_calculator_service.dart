import '../../core/constants/app_constants.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/tax_summary.dart';

class TaxCalculatorService {
  /// CENTS / KM (Layer 4A):
  /// Statutory formula: min(Business KM, Cap KM) * ATO Rate
  static double calculateCentsPerKm(double businessKm, [AtoTaxRule? rule]) {
    if (businessKm <= 0) return 0.0;
    final activeRule = rule ?? AppConstants.activeTaxRule;
    final eligibleKm = businessKm > activeRule.centsPerKmMaxKm
        ? activeRule.centsPerKmMaxKm
        : businessKm;
    return eligibleKm * activeRule.centsPerKmRate;
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
  /// Stored vault evidence (isVaultOnly == true) is strictly excluded from active claim.
  static double calculateLogbookClaim({
    required List<VehicleExpense> expenses,
    required double businessPercentage,
  }) {
    double runningTotal = 0.0;
    double directTotal = 0.0;

    for (final exp in expenses.expand((e) => e.claimComponents)) {
      if (exp.isVaultOnly) continue; // Exclude prior-year / vault-only records

      if (exp.category.isDirectlyDeductibleByDefault) {
        // Direct deduction: work parking/tolls/tools are 100% directly claimable
        directTotal += exp.amount * (exp.businessPercentage / 100.0);
      } else {
        // Scaled by logbook business %
        runningTotal += exp.amount;
      }
    }

    final scaledRunning = runningTotal * (businessPercentage / 100.0);
    return scaledRunning + directTotal;
  }

  /// CENTS / KM (Layer 4A - Multi-Vehicle Independent Statutory Cap):
  /// ITAA 1997 Subdivision 28-C / s.28-25:
  /// The 5,000 km statutory cap applies PER CAR per income year, not per taxpayer.
  /// Groups business trips by vehicleId, calculates min(vehicleBusinessKm, cap) * rate,
  /// and sums them up.
  static double calculateMultiVehicleCentsPerKm({
    required List<Trip> trips,
    AtoTaxRule? taxRule,
  }) {
    final breakdown = calculatePerVehicleBreakdown(
      trips: trips,
      taxRule: taxRule,
    );
    return breakdown.values.fold<double>(0.0, (sum, claim) => sum + claim);
  }

  /// Returns map of vehicleId -> capped claim amount in dollars.
  static Map<String, double> calculatePerVehicleBreakdown({
    required List<Trip> trips,
    AtoTaxRule? taxRule,
  }) {
    final activeRule = taxRule ?? AppConstants.activeTaxRule;
    final Map<String, double> vehicleBusinessKmMap = {};

    for (final trip in trips) {
      if (!trip.isBusiness) continue;
      final vId = trip.vehicleId.isEmpty ? 'default' : trip.vehicleId;
      vehicleBusinessKmMap[vId] =
          (vehicleBusinessKmMap[vId] ?? 0.0) + trip.businessDistanceKm;
    }

    final Map<String, double> result = {};
    for (final entry in vehicleBusinessKmMap.entries) {
      final cappedKm = entry.value > activeRule.centsPerKmMaxKm
          ? activeRule.centsPerKmMaxKm
          : entry.value;
      result[entry.key] = cappedKm * activeRule.centsPerKmRate;
    }
    return result;
  }

  /// TAX SUMMARY (Layer 5):
  /// Evaluates both methods and generates the comparison report.
  /// Ignores vault-only / prior-year archived receipts from current FY claim.
  /// When [multiVehicle] is true, centsPerKmClaim applies independent 5,000 km statutory caps per vehicle.
  static TaxSummary evaluateSummary({
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    AtoTaxRule? taxRule,
    bool multiVehicle = false,
  }) {
    double businessKm = 0.0;
    double personalKm = 0.0;

    for (final t in trips.where((t) => !t.isDeleted)) {
      businessKm += t.businessDistanceKm;
      personalKm += t.distanceKm - t.businessDistanceKm;
    }

    final totalKm = businessKm + personalKm;
    final businessPct = calculateBusinessPercentage(businessKm, totalKm);

    double totalRunning = 0.0;
    double totalDirect = 0.0;

    for (final exp in expenses.expand((e) => e.claimComponents)) {
      if (exp.isVaultOnly) continue; // Exclude prior-year / vault-only records

      if (exp.category.isDirectlyDeductibleByDefault) {
        totalDirect += exp.amount * (exp.businessPercentage / 100.0);
      } else {
        totalRunning += exp.amount;
      }
    }

    final centsClaim = multiVehicle
        ? calculateMultiVehicleCentsPerKm(trips: trips, taxRule: taxRule)
        : calculateCentsPerKm(businessKm, taxRule);
    final logbookClaim = (totalRunning * (businessPct / 100.0)) + totalDirect;

    final recommended = logbookClaim > centsClaim
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
