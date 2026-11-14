import 'package:flutter/material.dart';

import 'app_color.dart';

/// 4pt spacing grid. Replaces 123 distinct `EdgeInsets` expressions and 15
/// distinct spacer heights, 40% of which were off-grid.
class S {
  S._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  /// Horizontal page gutter. Every full-width scroll view uses this.
  static const EdgeInsets gutter = EdgeInsets.symmetric(horizontal: xl);

  /// The single interior padding for every card, so card text edges align
  /// down the whole scroll view.
  static const EdgeInsets cardPad = EdgeInsets.all(xl);

  /// Vertical gap between two stacked cards.
  static const double cardGap = lg;

  /// Gap between a label and the value beneath it.
  static const double labelGap = xs;
}

/// Four corner radii. Replaces 19 distinct values where 10/12/14/16/18/20
/// were all in heavy use for the same visual roles.
class R {
  R._();

  /// Chips, badges, avatars.
  static const double chip = 8.0;

  /// Buttons, inputs, segmented controls.
  static const double control = 10.0;

  /// Cards.
  static const double card = 16.0;

  /// Bottom sheets, hero cards, dialogs.
  static const double sheet = 24.0;

  static BorderRadius get chipR => BorderRadius.circular(chip);
  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get sheetR => BorderRadius.circular(sheet);

  static BorderRadius get sheetTopR =>
      const BorderRadius.vertical(top: Radius.circular(sheet));

  /// Concentric inner radius. An element nested inside a rounded container must
  /// use this rather than guessing, or the corners will not run parallel.
  static double inner(double outer, double padding) => outer - padding;

  static BorderRadius innerR(double outer, double padding) =>
      BorderRadius.circular(inner(outer, padding));
}

/// Three elevation levels with warm tailored ambient shadows.
class AppElevation {
  AppElevation._();

  /// A card resting on the warm linen canvas. Soft cashmere shadow,
  /// defined primarily by its tailored boundary.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0C181B1F),
      blurRadius: 18,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x05181B1F),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  /// Floating chrome: nav bar, FAB, popover.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x140F1722),
      blurRadius: 32,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x0A181B1F),
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  /// Temporarily raised: dialog, bottom sheet, drag preview.
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x1E0F1722),
      blurRadius: 44,
      offset: Offset(0, 16),
      spreadRadius: -6,
    ),
  ];

  /// The raised treatment for an accent surface that needs to read as lifted.
  static List<BoxShadow> accentGlow(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.18),
      blurRadius: 18,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  /// Standard 1px card border using refined parchment tone.
  static Border get cardBorder => Border.all(color: AppColor.line, width: 1);
}
