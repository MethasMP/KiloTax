import 'package:flutter/material.dart';

import 'app_color.dart';

/// Role-based typography for readable evidence, trip and tax workflows.
///
/// Rules enforced by this file:
///  - A screen never writes a raw `fontSize:`. If nothing fits, add a tier here.
///  - Every numeric style carries [tabular] so live values do not jitter.
///  - Every text tier sets `height`, so vertical rhythm does not drift.
class AppType {
  AppType._();

  /// Digits share one advance width, so a live odometer or dollar value does
  /// not shift horizontally as its digits change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// 44 / w700 / -1.0 / 1.05 — hero number on a screen (Old Money timepiece chronograph style).
  static const TextStyle metric = TextStyle(
    fontSize: 44,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    fontFeatures: tabular,
    color: AppColor.surfaceNavy,
  );

  /// 20 / w700 / -0.3 / 1.15 — compact metric readout for callouts and telemetry pills.
  static const TextStyle metricSmall = TextStyle(
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: tabular,
    color: AppColor.ink,
  );

  /// 72 / w700 / -1.8 / 1.0 — full-bleed live odometer readout.
  static const TextStyle metricXL = TextStyle(
    fontSize: 72,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.8,
    fontFeatures: tabular,
    color: AppColor.ink,
  );

  /// 28 / w700 / -0.5 / 1.18 — screen title and modal headline (Tailored bespoke heading).
  static const TextStyle title = TextStyle(
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColor.ink,
  );

  /// 22 / w700 / -0.3 / 1.25 — secondary hero.
  static const TextStyle titleSmall = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColor.ink,
  );

  /// 20 / w600 / -0.3 / 1.2 — section heading inside a scroll view.
  static const TextStyle section = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColor.ink,
  );

  /// 17 / w600 / 0 / 1.3 — card headline and list-row primary text.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColor.ink,
  );

  /// 17 / w600 / 0 / 1.3 — [cardTitle] for values in an aligned column.
  static const TextStyle cardNumeric = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: tabular,
    color: AppColor.ink,
  );

  /// 16 / w400 / 0 / 1.45 — body copy and paragraphs.
  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColor.ink,
  );

  /// 16 / w600 / 0 / 1.45 — inline emphasis inside body copy.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColor.ink,
  );

  /// 14 / w400 / 0 / 1.4 — secondary text, list-row subtitle.
  static const TextStyle secondary = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColor.inkMuted,
  );

  /// 12 / w600 / +0.4 / 1.3 — ALL-CAPS eyebrow above a value.
  /// Positive tracking is required: uppercase glyphs need optical space.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColor.inkMuted,
  );

  /// 12 / w600 / 0 / 1.3 — bottom-navigation label. Navigation must grow
  /// with system text scaling and allow labels to wrap.
  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColor.inkMuted,
  );

  /// Material text theme, so unstyled Material widgets inherit the scale
  /// instead of Material 3 defaults.
  static const TextTheme textTheme = TextTheme(
    displayLarge: metric,
    displayMedium: metricXL,
    headlineMedium: title,
    headlineSmall: titleSmall,
    titleLarge: section,
    titleMedium: cardTitle,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: secondary,
    labelLarge: bodyStrong,
    labelSmall: eyebrow,
  );
}
