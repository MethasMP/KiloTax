import 'package:flutter/material.dart';

import '../../core/theme/app_color.dart';
import '../../core/theme/app_typography.dart';

/// Money & Metric Display
///
/// Hierarchical numeric display designed for high-glanceability and zero cognitive load.
/// Displays whole units (dollars or integer percentage) in authoritative bold typography
/// (`AppType.metric`) and decimal portions (.xx or .x%) in compact typography (`AppType.metricSmall`)
/// with 60% muted opacity.
///
/// Guaranteed tabular figure layout (`AppType.tabular`) to prevent odometer/readout jitter.
class MoneyDisplay extends StatelessWidget {
  /// The numeric amount or value to display.
  final num? amount;

  /// Custom formatted string if not using raw [amount] (e.g. "4,850.50").
  final String? customValue;

  /// Currency or unit prefix (e.g. '$', 'AU$'). Defaults to '$'.
  final String? prefix;

  /// Suffix string (e.g. '%', '/yr', ' km').
  final String? suffix;

  /// Number of decimal places to format if [amount] is provided. Defaults to 2.
  final int decimalPlaces;

  /// Base style for the integer portion and symbol. Defaults to [AppType.metric].
  final TextStyle? integerStyle;

  /// Base style for the decimal portion and optional suffix. Defaults to [AppType.metricSmall].
  final TextStyle? decimalStyle;

  /// Text color override. Defaults to [AppColor.ink] (or adapt to context).
  final Color? color;

  /// Muted decimal color override. Defaults to 60% alpha of [color] or [AppColor.inkMuted].
  final Color? decimalColor;

  /// Semantic accessibility label for screen readers.
  final String? semanticsLabel;

  /// Text alignment. Defaults to [TextAlign.start].
  final TextAlign textAlign;

  const MoneyDisplay({
    super.key,
    this.amount,
    this.customValue,
    this.prefix = r'$',
    this.suffix,
    this.decimalPlaces = 2,
    this.integerStyle,
    this.decimalStyle,
    this.color,
    this.decimalColor,
    this.semanticsLabel,
    this.textAlign = TextAlign.start,
  }) : assert(amount != null || customValue != null,
            'Either amount or customValue must be provided');

  /// Convenience constructor for percentage readouts (e.g. 82.4%).
  factory MoneyDisplay.percentage({
    Key? key,
    required num percentage,
    int decimalPlaces = 1,
    TextStyle? integerStyle,
    TextStyle? decimalStyle,
    Color? color,
    Color? decimalColor,
    TextAlign textAlign = TextAlign.start,
  }) {
    return MoneyDisplay(
      key: key,
      amount: percentage,
      prefix: null,
      suffix: '%',
      decimalPlaces: decimalPlaces,
      integerStyle: integerStyle,
      decimalStyle: decimalStyle,
      color: color,
      decimalColor: decimalColor,
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColor.ink;
    final effectiveDecimalColor = decimalColor ??
        (color != null
            ? color!.withValues(alpha: 0.60)
            : AppColor.inkMuted);

    final baseIntStyle = (integerStyle ?? AppType.metric).copyWith(
      color: effectiveColor,
      fontFeatures: AppType.tabular,
    );

    final baseDecStyle = (decimalStyle ?? AppType.metricSmall).copyWith(
      color: effectiveDecimalColor,
      fontFeatures: AppType.tabular,
    );

    // Format the value into whole and decimal components
    String wholePart = '0';
    String decimalPart = '';

    if (customValue != null) {
      final parts = customValue!.split('.');
      wholePart = parts[0];
      if (parts.length > 1) {
        decimalPart = '.${parts[1]}';
      }
    } else if (amount != null) {
      final isNegative = amount! < 0;
      final absAmount = amount!.abs();

      if (decimalPlaces > 0) {
        final fixedStr = absAmount.toStringAsFixed(decimalPlaces);
        final parts = fixedStr.split('.');
        wholePart = _formatWithCommas(parts[0]);
        if (parts.length > 1) {
          decimalPart = '.${parts[1]}';
        }
      } else {
        wholePart = _formatWithCommas(absAmount.round().toString());
      }

      if (isNegative) {
        wholePart = '-$wholePart';
      }
    }

    final fullReadableString =
        '${prefix ?? ''}$wholePart$decimalPart${suffix ?? ''}';

    return Semantics(
      label: semanticsLabel ?? fullReadableString,
      value: fullReadableString,
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(
          style: baseIntStyle,
          children: [
            if (prefix != null && prefix!.isNotEmpty)
              TextSpan(text: prefix),
            TextSpan(
              text: wholePart,
            ),
            if (decimalPart.isNotEmpty)
              TextSpan(
                text: decimalPart,
                style: baseDecStyle,
              ),
            if (suffix != null && suffix!.isNotEmpty)
              TextSpan(
                text: suffix,
                style: baseDecStyle,
              ),
          ],
        ),
      ),
    );
  }

  static String _formatWithCommas(String intString) {
    final chars = intString.split('');
    final buffer = StringBuffer();
    final len = chars.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }
    return buffer.toString();
  }
}
