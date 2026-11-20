import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_color.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_typography.dart';

/// Dashed Border Custom Painter
///
/// Draws a clean, dashed stroke around a rounded rectangle with zero third-party packages.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 4.0,
    this.dashGap = 3.0,
    this.radius = R.control,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final halfStroke = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        halfStroke,
        halfStroke,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius > halfStroke ? radius - halfStroke : 0),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.radius != radius;
  }
}

/// Audit & Evidence Voucher Strip
///
/// Designed after official tax vouchers and compliance slips.
/// Features a dashed border (1.5dp stroke, [AppColor.line] or [AppColor.navyLine]),
/// a muted surface background (`AppColor.surfaceMuted`), and an audit-proof
/// compliance token display (e.g. ABN, Logbook Period, Trip Cryptographic Proof Hash).
/// Includes a guaranteed 48x48dp touch-floor 1-tap copy/share action for tradie thumbs.
class AuditEvidenceStrip extends StatelessWidget {
  /// Primary label/title of the evidence (e.g. "ATO LOGBOOK PERIOD", "ABN VERIFIED").
  final String label;

  /// The verifiable value or proof token (e.g. "ABN 84 123 456 789", "SHA-256 #9F82A4").
  final String value;

  /// Optional secondary caption or timestamp (e.g. "12-Week Period ending 28 Jun").
  final String? caption;

  /// Optional leading icon or badge (e.g. `Icons.verified_user_outlined`, `Icons.receipt_long`).
  final Widget? leading;

  /// The text string copied to clipboard on tap. Defaults to [value].
  final String? copyPayload;

  /// Callback when user taps the action button (or the strip itself).
  /// If null, default behavior copies [copyPayload] to clipboard and triggers haptic feedback.
  final VoidCallback? onActionPressed;

  /// Tooltip / label for the action icon. Defaults to "Copy Audit Proof".
  final String actionTooltip;

  /// Icon for the action button. Defaults to `Icons.copy_rounded`.
  final IconData actionIcon;

  /// Border color for the dashed perimeter. Defaults to [AppColor.line].
  final Color borderColor;

  /// Background fill color. Defaults to [AppColor.surfaceMuted].
  final Color backgroundColor;

  /// Custom text color for value and caption.
  final Color? textColor;

  /// Custom label color for the eyebrow header.
  final Color? labelColor;

  /// Corner radius. Defaults to [R.control] (10.0dp).
  final double borderRadius;

  const AuditEvidenceStrip({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.leading,
    this.copyPayload,
    this.onActionPressed,
    this.actionTooltip = 'Copy Audit Proof',
    this.actionIcon = Icons.copy_rounded,
    this.borderColor = AppColor.line,
    this.backgroundColor = AppColor.surfaceMuted,
    this.textColor,
    this.labelColor,
    this.borderRadius = R.control,
  });

  void _handleCopy(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onActionPressed != null) {
      onActionPressed!();
      return;
    }

    final payload = copyPayload ?? value;
    Clipboard.setData(ClipboardData(text: payload));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard: $payload',
          style: AppType.secondary.copyWith(color: AppColor.onNavy),
        ),
        backgroundColor: AppColor.surfaceNavy,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: borderColor,
        strokeWidth: 1.5,
        dashWidth: 4.0,
        dashGap: 3.0,
        radius: borderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.only(
          left: S.lg,
          top: S.sm,
          bottom: S.sm,
          right: S.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: S.md),
            ],
            // Text Details Column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppType.eyebrow.copyWith(
                      color: labelColor ?? AppColor.inkSubtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppType.cardNumeric.copyWith(
                      color: textColor ?? AppColor.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      style: AppType.secondary.copyWith(
                        color: textColor != null
                            ? textColor!.withValues(alpha: 0.7)
                            : AppColor.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 48x48dp Touch Target Floor Action Button
            Semantics(
              button: true,
              label: actionTooltip,
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: actionTooltip,
                  child: InkWell(
                    onTap: () => _handleCopy(context),
                    borderRadius: BorderRadius.circular(R.chip),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: S.huge,
                        minHeight: S.huge,
                      ),
                      child: Center(
                        child: Icon(
                          actionIcon,
                          size: 20,
                          color: textColor ?? AppColor.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
