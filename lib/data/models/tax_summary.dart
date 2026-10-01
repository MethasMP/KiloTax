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
  final double totalRunningExpenses;
  final double totalDirectDeductions; // 100% deductible tolls & parking
  final double centsPerKmClaim; // min(businessKm, 5000) * $0.91
  final double
      logbookClaim; // (totalRunningExpenses * businessPercentage) + direct

  // Backing fields for optional override of derived calculations if explicitly provided
  final double? _businessPercentageOverride;
  final RecommendedMethod? _recommendedMethodOverride;
  final double? _taxSavingsDiffOverride;

  TaxSummary({
    required this.totalKm,
    required this.businessKm,
    required this.personalKm,
    double? businessPercentage,
    required this.totalRunningExpenses,
    required this.totalDirectDeductions,
    required this.centsPerKmClaim,
    required this.logbookClaim,
    RecommendedMethod? recommendedMethod,
    double? taxSavingsDiff,
  })  : _businessPercentageOverride = businessPercentage,
        _recommendedMethodOverride = recommendedMethod,
        _taxSavingsDiffOverride = taxSavingsDiff;

  /// Business use percentage: (businessKm / totalKm) * 100 capped at 100%
  double get businessPercentage {
    final override = _businessPercentageOverride;
    if (override != null) return override;
    if (totalKm <= 0 || businessKm <= 0) return 0.0;
    final pct = (businessKm / totalKm) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  /// Recommended deduction method based on highest claim yield
  RecommendedMethod get recommendedMethod {
    final override = _recommendedMethodOverride;
    if (override != null) return override;
    return logbookClaim > centsPerKmClaim
        ? RecommendedMethod.logbook
        : RecommendedMethod.centsPerKm;
  }

  /// Absolute monetary difference between methods
  double get taxSavingsDiff {
    final override = _taxSavingsDiffOverride;
    if (override != null) return override;
    return (logbookClaim - centsPerKmClaim).abs();
  }

  /// Highest allowable claim amount between logbook and cents per km
  double get highestClaim => recommendedMethod == RecommendedMethod.logbook
      ? logbookClaim
      : centsPerKmClaim;
}
