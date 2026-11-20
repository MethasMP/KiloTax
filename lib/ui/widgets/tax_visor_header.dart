import 'package:flutter/material.dart';

import '../../core/theme/app_color.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_typography.dart';

/// Tax Visor / Context Shield
///
/// An authoritative, high-contrast dark top context shield (`AppColor.surfaceNavy`)
/// designed to be glare-proof in direct Australian sunlight (e.g. 5 PM ute cab).
/// Features a smooth curved bottom edge (`R.sheet = 24.0dp`), safe area top padding,
/// customizable title/subtitle/actions, and an optional status pill (e.g. "Week 7 of 12"
/// or "Tracking Active").
class TaxVisorHeader extends StatelessWidget {
  /// Primary title displayed within the visor.
  final String title;

  /// Optional secondary subtitle or description line.
  final String? subtitle;

  /// Optional status pill displayed prominently (e.g. "Week 7 of 12", "Audit Ready").
  final Widget? statusPill;

  /// Optional leading widget (e.g. back button or brand glyph).
  final Widget? leading;

  /// Optional trailing action widgets (e.g. quick export or settings).
  final List<Widget>? actions;

  /// Optional hero content embedded inside the visor (e.g. metric readout, graph summary).
  final Widget? content;

  /// Optional bottom widget attached inside the visor before the curved bottom edge.
  final Widget? bottom;

  /// Padding applied to interior content. Defaults to `EdgeInsets.symmetric(horizontal: S.xl, vertical: S.lg)`.
  final EdgeInsetsGeometry? padding;

  /// Background color of the visor. Defaults to `AppColor.surfaceNavy`.
  final Color backgroundColor;

  /// Bottom corner radius. Defaults to `R.sheet` (24.0dp).
  final double bottomRadius;

  const TaxVisorHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.statusPill,
    this.leading,
    this.actions,
    this.content,
    this.bottom,
    this.padding,
    this.backgroundColor = AppColor.surfaceNavy,
    this.bottomRadius = R.sheet,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColor.scrimSoft,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: S.xl,
                  vertical: S.md,
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top control bar: Leading, optional Status Pill, and Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: S.sm),
                    ],
                    if (statusPill != null)
                      Flexible(child: statusPill!)
                    else if (leading == null)
                      const Spacer(),
                    if (statusPill != null && leading != null) const Spacer(),
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(width: S.sm),
                      ...actions!,
                    ],
                  ],
                ),
                const SizedBox(height: S.md),

                // Title & Subtitle
                Text(
                  title,
                  style: AppType.title.copyWith(
                    color: AppColor.onNavy,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: S.xs),
                  Text(
                    subtitle!,
                    style: AppType.secondary.copyWith(
                      color: AppColor.onNavyMuted,
                    ),
                  ),
                ],

                // Optional Hero / Content Area
                if (content != null) ...[
                  const SizedBox(height: S.lg),
                  content!,
                ],
              ],
            ),
          ),

          // Optional Bottom Widget (e.g. tab strip or progress tracker)
          if (bottom != null) ...[
            bottom!,
            const SizedBox(height: S.sm),
          ],
        ],
      ),
    );
  }
}
