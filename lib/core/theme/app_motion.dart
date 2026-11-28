import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion tokens. Replaces 11 inline durations and 7 inline curves, and
/// collapses three different press scales (0.972 / 0.94 / 0.94) plus two
/// controls with no press feedback at all into one behaviour.
class AppMotion {
  AppMotion._();

  /// Immediate feedback: ripple, icon swap.
  static const Duration instant = Duration(milliseconds: 90);

  /// Press down on any pressable control.
  static const Duration press = Duration(milliseconds: 100);

  /// Release back to rest.
  static const Duration release = Duration(milliseconds: 220);

  /// A state change: toggle, chip selection, tab switch.
  static const Duration state = Duration(milliseconds: 160);

  /// An element entering: sheet, card, dialog.
  static const Duration enter = Duration(milliseconds: 400);

  /// One-time welcome illustration and copy entrance.
  static const Duration welcome = Duration(milliseconds: 800);

  /// Folio planes settle before the rest of the welcome entrance completes.
  static const Duration brandAssembly = Duration(milliseconds: 560);
  static const Duration brandPlaneStagger = Duration(milliseconds: 80);
  static const double brandAssemblyTravel = 6;

  /// Background-only ambience: sheen, pulse. Never used as user feedback.
  static const Duration ambient = Duration(milliseconds: 1400);

  static const Curve pressIn = Curves.easeOutCubic;
  static const Curve settle = Curves.easeOut;
  static const Curve toggle = Curves.easeInOut;
  static const Curve enterCurve = Curves.easeOutCubic;

  /// The single press compression for every pressable control.
  /// Elastic and back-overshoot curves are deliberately absent: they read as
  /// playful, which contradicts a tax-compliance product.
  static const double pressScale = 0.972;

  /// True when the platform asks for reduced motion. Callers should substitute
  /// [Duration.zero] rather than merely shortening the animation.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or [Duration.zero] when reduce-motion is on.
  static Duration respecting(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Three haptic levels. Previously four intensities were used for comparable
/// actions, three levels apart on adjacent controls in the same nav bar.
class AppHaptic {
  AppHaptic._();

  /// Tab switch, chip selection, toggle.
  static void select() => HapticFeedback.selectionClick();

  /// Secondary button, opening a sheet.
  static void light() => HapticFeedback.lightImpact();

  /// Saved, confirmed, destructive acknowledgement.
  static void commit() => HapticFeedback.mediumImpact();
}
