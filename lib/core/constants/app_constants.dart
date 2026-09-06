import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF0F172A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color crimson = Color(0xFFDC2626);
  static const Color crimsonLight = Color(0xFFFEF2F2);
  static const Color workBlue = Color(0xFF2563EB);
  static const Color workBlueLight = Color(0xFFEFF6FF);
  static const Color amber = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFFFBEB);
}

/// Versioned ATO Tax Legislation Rules (Income Year Aligned)
/// Prevents hardcoding tax rates and allows historical audit reproducibility
class AtoTaxRule {
  final String financialYear; // e.g. '2026-27'
  final double centsPerKmRate; // 91 cents
  final double centsPerKmMaxKm; // 5,000 km
  final double carDepreciationLimit; // ,674
  final int logbookMinWeeks; // 12 weeks
  final int logbookValidityYears; // 5 years

  const AtoTaxRule({
    required this.financialYear,
    required this.centsPerKmRate,
    required this.centsPerKmMaxKm,
    required this.carDepreciationLimit,
    this.logbookMinWeeks = 12,
    this.logbookValidityYears = 5,
  });

  double get maxCentsPerKmClaim => centsPerKmRate * centsPerKmMaxKm;
}

class AppConstants {
  static const String appTitle = 'KiloTax';

  // Active ATO Tax Year: 2026-27
  static const AtoTaxRule activeTaxRule = AtoTaxRule(
    financialYear: '2026-27',
    centsPerKmRate: 0.91,
    centsPerKmMaxKm: 5000.0,
    carDepreciationLimit: 69674.0,
  );

  static double get centsPerKmRate2026 => activeTaxRule.centsPerKmRate;
  static double get centsPerKmCapKm => activeTaxRule.centsPerKmMaxKm;
  static double get maxCentsPerKmClaim => activeTaxRule.maxCentsPerKmClaim;
  static int get statutoryLogbookWeeks => activeTaxRule.logbookMinWeeks;
  static int get statutoryLogbookDays => activeTaxRule.logbookMinWeeks * 7;
}
