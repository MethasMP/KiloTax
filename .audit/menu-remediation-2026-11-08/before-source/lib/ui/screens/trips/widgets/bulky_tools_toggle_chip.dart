import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Tactile 1-tap Bulky Tools chip widget.
/// Meets ATO Section 8-1 travel substantiation ergonomics.
///
/// Ergonomic & Motion requirements:
/// - Minimum tap target >= 48x48 pt (vehicle cradle thumb reach).
/// - High contrast AAA: recessed `AppColor.surfaceMuted` -> confident stamped `AppColor.positiveTint`.
/// - Crisp typography: `AppColor.positiveInk` on `AppColor.positiveTint` and `LucideIcons.hammer`.
/// - Mechanical haptics: `AppHaptic.commit()` on ON, `AppHaptic.light()` on OFF.
/// - Dopamine trigger: Micro AnimatedSwitcher / Rolling Number Ticker with organic
///   easing (`AppMotion.release` / `Curves.easeOutCubic`) springing up deduction delta.
class BulkyToolsToggleChip extends StatefulWidget {
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final String activeLabel;
  final String inactiveLabel;
  final String? badgeLabel;
  final String? estimatedDeductionDelta;
  final bool isSuggested;
  final String? suggestionLabel;

  const BulkyToolsToggleChip({
    super.key,
    required this.isSelected,
    required this.onChanged,
    this.activeLabel = 'Tools on Board',
    this.inactiveLabel = 'Bulky Tools',
    this.badgeLabel = 'ATO s 8-1',
    this.estimatedDeductionDelta = r'+$18.20 AUD',
    this.isSuggested = false,
    this.suggestionLabel,
  });

  @override
  State<BulkyToolsToggleChip> createState() => _BulkyToolsToggleChipState();
}

class _BulkyToolsToggleChipState extends State<BulkyToolsToggleChip>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppMotion.press,
      reverseDuration: AppMotion.release,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppMotion.pressScale,
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppMotion.pressIn,
        reverseCurve: AppMotion.settle,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isSuggested) {
      _pulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(BulkyToolsToggleChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSuggested != oldWidget.isSuggested) {
      if (widget.isSuggested) {
        _pulseController.value = 1.0;
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    final nextState = !widget.isSelected;
    if (nextState) {
      AppHaptic.commit();
    } else {
      AppHaptic.light();
    }
    widget.onChanged(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;
    final bool suggested = widget.isSuggested;

    final Color backgroundColor = active
        ? AppColor.positiveTint
        : (suggested ? AppColor.surface : AppColor.surfaceMuted);
    final Color borderColor = active
        ? AppColor.positiveStrong
        : (suggested ? AppColors.deepNavy : AppColor.line);
    final Color iconColor = active
        ? AppColor.positiveInk
        : (suggested ? AppColors.deepNavy : AppColor.inkMuted);
    final Color textColor = active
        ? AppColor.positiveInk
        : AppColor.ink;
    final Color iconContainerColor = active
        ? AppColor.positiveTintStrong
        : (suggested ? AppColor.surfaceSunken : AppColor.surface);

    final String? effectiveBadge = suggested
        ? (widget.suggestionLabel ?? 'Stopped at trade supplier')
        : (active ? widget.badgeLabel : null);

    final String semanticsLabel = active
        ? '${widget.activeLabel}${effectiveBadge != null ? ", $effectiveBadge" : ""}${widget.estimatedDeductionDelta != null ? ", ${widget.estimatedDeductionDelta}" : ""}'
        : (suggested
            ? '${widget.inactiveLabel}, $effectiveBadge'
            : widget.inactiveLabel);

    return Semantics(
      button: true,
      toggled: active,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: AppMotion.state,
            curve: AppMotion.toggle,
            constraints: const BoxConstraints(
              minHeight: 48.0,
              minWidth: 48.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: borderColor,
                width: (active || suggested) ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? AppColor.positiveStrong.withValues(alpha: 0.16)
                      : (suggested
                          ? AppColor.brand.withValues(alpha: 0.14)
                          : AppColor.scrimSoft),
                  blurRadius: (active || suggested) ? 6.0 : 2.0,
                  offset: (active || suggested)
                      ? const Offset(0, 2)
                      : const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32.0,
                  height: 32.0,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.hammer,
                      size: 16.0,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Text(
                  active ? widget.activeLabel : widget.inactiveLabel,
                  style: AppType.cardTitle.copyWith(
                    fontSize: 14.0,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (effectiveBadge != null) ...[
                  const SizedBox(width: 8.0),
                  Flexible(
                    fit: FlexFit.loose,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: suggested ? _pulseAnimation.value : 1.0,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColor.positiveInk : AppColors.deepNavy,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: suggested
                              ? [
                                  BoxShadow(
                                    color: (active
                                            ? AppColor.positiveStrong
                                            : AppColors.deepNavy)
                                        .withValues(alpha: 0.2),
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (suggested) ...[
                              const Icon(
                                LucideIcons.hammer,
                                size: 10.0,
                                color: AppColor.surface,
                              ),
                              const SizedBox(width: 4.0),
                            ],
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                effectiveBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.eyebrow.copyWith(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColor.surface,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                ClipRect(
                  child: AnimatedSwitcher(
                    duration: AppMotion.release,
                    reverseDuration: AppMotion.instant,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.0, 0.6),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: (active &&
                            !suggested &&
                            widget.estimatedDeductionDelta != null &&
                            widget.estimatedDeductionDelta!.isNotEmpty)
                        ? Padding(
                            key: ValueKey<String>(
                              'ticker_${widget.estimatedDeductionDelta}',
                            ),
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColor.surface,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: AppColor.positiveStrong.withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColor.positiveStrong.withValues(alpha: 0.1),
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.estimatedDeductionDelta!,
                                style: AppType.eyebrow.copyWith(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColor.positiveInk,
                                  letterSpacing: 0.2,
                                  fontFeatures: AppType.tabular,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey<String>('ticker_inactive')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
