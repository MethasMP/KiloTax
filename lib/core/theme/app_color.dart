import 'package:flutter/material.dart';

/// Shared colour roles for the Obsidian & Terracotta interface.
/// Warm surfaces, neutral content and restrained orange actions.
/// Contrast is a property of a foreground/background pair, not a palette.
class AppColor {
  AppColor._();

  // ---------------------------------------------------------------- surfaces
  static const Color canvas = Color(0xFFFAF9F6);

  static const Color surfaceSunken = Color(0xFFE7E5E4);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F4F1);

  static const Color surfaceNavy = Color(0xFF18181B);

  static const Color navyRaised = Color(0xFF27272A);

  static const Color navyLine = Color(0xFF3F3F46);

  // ----------------------------------------------------------------- content
  static const Color ink = Color(0xFF18181B);

  static const Color inkMuted = Color(0xFF3F3F46);

  /// High-contrast token (Zinc 600) tuned for sunlight readability and anti-glare
  /// visibility on ute dashboard mounts. Exceeds WCAG AA on canvas/white (7.4:1).
  static const Color inkSubtle = Color(0xFF52525B);

  static const Color onNavy = Color(0xFFFFFFFF);
  static const Color onNavyMuted = Color(0xFFD4D4D8);

  // ------------------------------------------------------------------- lines
  static const Color hairline = Color(0xFFE7E5E4);

  static const Color line = Color(0xFFD6D3D1);

  // ------------------------------------------------------------------ brand
  /// AA normal-text contrast with white; used for actions and light-surface labels.
  static const Color brand = Color(0xFFC2410C);

  /// Decorative accent; do not pair with small white text.
  static const Color brandBright = Color(0xFFEA580C);

  static const Color brandTint = Color(0xFFFFF1E8);
  static const Color brandTintStrong = Color(0xFFFFDFC9);

  // --------------------------------------------------------------- positive
  static const Color positive = Color(0xFF15803D);

  static const Color positiveStrong = Color(0xFF166534);

  static const Color positiveTint = Color(0xFFECFDF5);
  static const Color positiveTintStrong = Color(0xFFD1FAE5);
  static const Color positiveBright = Color(0xFF10B981);
  static const Color positiveInk = Color(0xFF065F46);

  // -------------------------------------------------------------- attention
  static const Color attention = Color(0xFFD97706);
  static const Color attentionStrong = Color(0xFFB45309);
  static const Color attentionTint = Color(0xFFFEF3C7);
  static const Color attentionTintSoft = Color(0xFFFFFBEB);
  static const Color attentionTintStrong = Color(0xFFFDE68A);
  static const Color attentionInk = Color(0xFF92400E);

  // --------------------------------------------------------------- critical
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalStrong = Color(0xFFB91C1C);
  static const Color criticalTint = Color(0xFFFEF2F2);
  static const Color criticalTintStrong = Color(0xFFFEE2E2);
  static const Color criticalInk = Color(0xFF991B1B);

  // ------------------------------------------------------- navy / hero scale
  static const Color navy800 = Color(0xFF18181B);
  static const Color navy700 = Color(0xFF27272A);
  static const Color navy600 = Color(0xFF3F3F46);
  static const Color navy500 = Color(0xFF52525B);
  static const Color navy400 = Color(0xFF71717A);
  static const Color navy300 = Color(0xFFA1A1AA);
  static const Color navy200 = Color(0xFFD4D4D8);
  static const Color cyan400 = Color(0xFF10B981);
  static const Color red400 = Color(0xFFEF4444);

  // --------------------------------------------------------------- scrims
  static const Color scrimSoft = Color(0x0C000000);
  static const Color scrimMedium = Color(0x1F000000);
  static const Color scrimStrong = Color(0x3D000000);

  // ------------------------------------------------------- Material ColorScheme
  static const ColorScheme scheme = ColorScheme.light(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: brandTint,
    onPrimaryContainer: brand,
    secondary: positive,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: positiveTint,
    onSecondaryContainer: positiveInk,
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: surfaceMuted,
    outline: line,
    outlineVariant: hairline,
    error: critical,
    onError: Color(0xFFFFFFFF),
  );
}
