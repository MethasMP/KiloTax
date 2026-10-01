import 'package:flutter/material.dart';

class AppColors {
  // Precision Utility Core Palette (Pacific Cyber-Navy & Electric Ultramarine Standard)
  static const Color deepNavy = Color(
      0xFF0B132B); // Deep Cyber-Navy 950: Rich oceanic foundation, zero flat pitch black
  static const Color ink = Color(
      0xFF090E1A); // High-contrast crisp Obsidian Ink (WCAG AAA 15:1)
  static const Color background = Color(
      0xFFF4F6FB); // Ice Slate Canvas: Anti-glare outdoor resilience
  static const Color card = Color(0xFFFFFFFF); // Pure white card surface
  static const Color border = Color(
      0xFFE2E8F0); // Hairline boundary Slate 200
  static const Color borderSubtle = Color(
      0xFFEDF2F7); // Subtle 0.5px internal separator
  static const Color muted = Color(
      0xFF4B5565); // Slate 600: High-readability secondary labels (WCAG AAA)

  // Primary Brand & Electric Accents (Linear / Stripe fintech luxury)
  static const Color brandPrimary = Color(
      0xFF1E40AF); // Ultramarine 800: Deep tactile primary CTA
  static const Color brandElectric = Color(
      0xFF2563EB); // Electric Blue 600: Dynamic active states, telemetry pulse
  static const Color brandElectricLight = Color(
      0xFFEFF6FF); // Electric Blue 50: Pill highlights
  static final Color brandGlow = const Color(
      0xFF2563EB).withValues(alpha: 0.28); // Ambient CTA drop aura
  static final Color anchorGlow = const Color(
      0xFF0B132B).withValues(alpha: 0.12); // Floating island drop aura

  // Status & Utility Accents (Contextual Value Only)
  static const Color amber = Color(
      0xFFD97706); // Amber 600: Action required, needs attention
  static const Color amberLight = Color(0xFFFEF3C7); // Amber 100
  static const Color amberDark = Color(
      0xFFB45309); // Amber 700: High-contrast progress bars

  static const Color emerald = Color(
      0xFF059669); // Emerald 600: Tax-ready, audit verified, cash savings
  static const Color emeraldLight = Color(0xFFECFDF5); // Emerald 50

  static const Color crimson = Color(
      0xFFDC2626); // Red 600: Critical issues, duplicates
  static const Color crimsonLight = Color(0xFFFEF2F2); // Red 50

  static const Color workBlue = Color(
      0xFF1E40AF); // Ultramarine Primary
  static const Color workBlueLight = Color(0xFFEFF6FF);

  // Dark Theme / HUD Surface Accents (Slate High-Contrast)
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400

  // Telemetry Ambient States
  static const Color telemetryReady = Color(
      0xFF2563EB); // Blue 600: Armed and standing by
  static const Color telemetryReadyLight = Color(0xFFEFF6FF); // Blue 50
  static const Color telemetryLive = Color(
      0xFF059669); // Emerald 600: Live tracking
  static const Color telemetryLiveLight = Color(0xFFECFDF5);
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

  // Supabase Cloud Vault Config (Project: KiloTax)
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
  static const String privacyPolicyUrl = 'https://methasmp.github.io/KiloTax/legal/#privacy';
  static const String termsOfServiceUrl = 'https://methasmp.github.io/KiloTax/legal/#terms';
  static const String supportUrl = 'https://methasmp.github.io/KiloTax/legal/#support';
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
