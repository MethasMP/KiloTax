import '../../core/constants/app_constants.dart';

enum RecommendedMethod {
  centsPerKm,
  logbook;

  String get displayName {
    switch (this) {
      case RecommendedMethod.centsPerKm:
        return 'Cents per KM (Simpler, Capped at \$4,550)';
      case RecommendedMethod.logbook:
        return 'ATO Logbook Method (Actual Expenses × Business %)';
    }
  }
}

/// Tax Summary Entity conforming to Layer 5 (TAX SUMMARY)
class TaxSummary {
  final double totalKm;
  final double businessKm;
  final double personalKm;
  final double businessPercentage; // (businessKm / totalKm) * 100
  final double totalRunningExpenses;
  final double totalDirectDeductions; // 100% deductible tolls & parking
  final double centsPerKmClaim; // min(businessKm, 5000) * $0.91
  final double logbookClaim; // (totalRunningExpenses * businessPercentage) + direct
  final RecommendedMethod recommendedMethod;
  final double taxSavingsDiff; // difference between the higher and lower method

  TaxSummary({
    required this.totalKm,
    required this.businessKm,
    required this.personalKm,
    required this.businessPercentage,
    required this.totalRunningExpenses,
    required this.totalDirectDeductions,
    required this.centsPerKmClaim,
    required this.logbookClaim,
    required this.recommendedMethod,
    required this.taxSavingsDiff,
  });

  double get highestClaim => recommendedMethod == RecommendedMethod.logbook ? logbookClaim : centsPerKmClaim;
}
