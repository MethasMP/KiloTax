import 'package:flutter/material.dart';
import '../theme/app_color.dart';

/// Compatibility names backed by the shared theme palette.
class AppColors {
  static const Color deepNavy = AppColor.surfaceNavy;
  static const Color ink = AppColor.ink;
  static const Color background = AppColor.canvas;
  static const Color card = AppColor.surface;
  static const Color border = AppColor.line;
  static const Color borderSubtle = AppColor.hairline;
  static const Color muted = AppColor.inkMuted;
  static const Color brandPrimary = AppColor.brand;
  static const Color brandElectric = AppColor.brandBright;
  static const Color brandElectricLight = AppColor.brandTint;
  static const Color amber = AppColor.attention;
  static const Color amberLight = AppColor.attentionTint;
  static const Color amberDark = AppColor.attentionStrong;
  static const Color emerald = AppColor.positive;
  static const Color emeraldLight = AppColor.positiveTint;
  static const Color crimson = AppColor.critical;
  static const Color crimsonLight = AppColor.criticalTint;
  static const Color workBlue = AppColor.surfaceNavy;
  static const Color workBlueLight = AppColor.surfaceMuted;
  static const Color darkSurface = AppColor.navyRaised;
  static const Color darkBorder = AppColor.navyLine;
  static const Color textSecondaryDark = AppColor.navy300;
  static const Color telemetryReady = AppColor.brand;
  static const Color telemetryReadyLight = AppColor.brandTint;
  static const Color telemetryLive = AppColor.positive;
  static const Color telemetryLiveLight = AppColor.positiveTint;
  static final Color brandGlow = AppColor.brand.withValues(alpha: 0.12);
  static final Color anchorGlow = AppColor.surfaceNavy.withValues(alpha: 0.08);
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
  final String? legislativeRef;
  final String? sourceUrl;

  const AtoTaxRule({
    required this.financialYear,
    required this.centsPerKmRate,
    required this.centsPerKmMaxKm,
    required this.carDepreciationLimit,
    this.logbookMinWeeks = 12,
    this.logbookValidityYears = 5,
    this.legislativeRef,
    this.sourceUrl,
  });

  double get maxCentsPerKmClaim => centsPerKmRate * centsPerKmMaxKm;

  Map<String, dynamic> toJson() {
    return {
      'financialYear': financialYear,
      'centsPerKmRate': centsPerKmRate,
      'centsPerKmMaxKm': centsPerKmMaxKm,
      'carDepreciationLimit': carDepreciationLimit,
      'logbookMinWeeks': logbookMinWeeks,
      'logbookValidityYears': logbookValidityYears,
      'legislativeRef': legislativeRef,
      'sourceUrl': sourceUrl,
    };
  }

  factory AtoTaxRule.fromJson(Map<String, dynamic> json) {
    return AtoTaxRule(
      financialYear: (json['financialYear'] ??
          json['financial_year'] ??
          '2026-27') as String,
      centsPerKmRate:
          ((json['centsPerKmRate'] ?? json['cents_per_km_rate'] ?? 0.91) as num)
              .toDouble(),
      centsPerKmMaxKm: ((json['centsPerKmMaxKm'] ??
              json['cents_per_km_max_km'] ??
              5000.0) as num)
          .toDouble(),
      carDepreciationLimit: ((json['carDepreciationLimit'] ??
              json['car_depreciation_limit'] ??
              69674.0) as num)
          .toDouble(),
      logbookMinWeeks:
          ((json['logbookMinWeeks'] ?? json['logbook_min_weeks'] ?? 12) as num)
              .toInt(),
      logbookValidityYears: ((json['logbookValidityYears'] ??
              json['logbook_validity_years'] ??
              5) as num)
          .toInt(),
      legislativeRef:
          (json['legislativeRef'] ?? json['legislative_ref']) as String?,
      sourceUrl: (json['sourceUrl'] ?? json['source_url']) as String?,
    );
  }
}

class AppConstants {
  static const String appTitle = 'KiloClaim';

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

  // Supabase Cloud Vault Config (Project: KiloClaim)
  static const String supabaseUrl = 'https://mwtxfdqcyalsohruzmps.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13dHhmZHFjeWFsc29ocnV6bXBzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2ODIzNDYsImV4cCI6MjEwNDI1ODM0Nn0.OLMf4bsr1kgnzDieaf4q3dYTpZGsp01bYepfXpDwNKs';
  static const String googleWebClientId =
      '186185970853-jfclnteqdk1isnbg6k7fhr1p8i638lf3.apps.googleusercontent.com';
  static const String googleIosClientId =
      '186185970853-lonc1tc0iokhucjd046che8gq3q8mqj1.apps.googleusercontent.com';
  static const String googleAndroidClientId =
      '186185970853-cg07rohjdv3jk14882pe8k0mu4cjbcpi.apps.googleusercontent.com';
  static const String receiptStorageBucket = 'receipts';

  // Legal & Compliance URLs (Public Hosted Portal)
  static const String privacyPolicyUrl = 'https://methasmp.github.io/KiloClaim/legal/#privacy';
  static const String termsOfServiceUrl = 'https://methasmp.github.io/KiloClaim/legal/#terms';
  static const String supportUrl = 'https://methasmp.github.io/KiloClaim/legal/#support';
}

/// Strict Typography Hierarchy locked from Product Architect & UX spec:
/// Page title: 28 / w600
/// Greeting: 28 / w600
/// Hero number: 40–44 / w600
/// Section title: 20 / w600
/// Card primary: 16 / w500–600
/// Body: 15–16 / w400
/// Secondary: 14 / w400
/// Caption: 12–13 / w400–500
/// Bottom nav: 12–13 / w500
/// Button: 15–16 / w600
class AppTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.5,
  );

  static const TextStyle heroTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.5,
  );

  static const TextStyle greeting = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.5,
  );

  static const TextStyle heroNumber = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -1.0,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.3,
  );

  static const TextStyle cardPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle labelBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle cardPrimarySubtle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.4,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle secondaryMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle captionMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  static const TextStyle bottomNav = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
}

class AppShadows {
  // Layered Tactile Button Shadow with Ambient Glow
  static List<BoxShadow> get buttonElevated => [
    BoxShadow(
      color: AppColors.brandGlow,
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // Concentric Card Soft Elevation
  static List<BoxShadow> get cardSoft => [
    BoxShadow(
      color: AppColors.deepNavy.withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Floating Island Tab Bar Shadow
  static List<BoxShadow> get floatingNav => [
    BoxShadow(
      color: AppColors.anchorGlow,
      blurRadius: 30,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: -1,
    ),
  ];
}
