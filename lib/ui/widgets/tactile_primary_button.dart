import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_color.dart';

/// Shared action button with Material semantics, focus and disabled states.
/// The minimum height grows to accommodate large text and wrapped labels.
class TactilePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final double height;
  final Color? baseColor;
  final bool isSecondary;

  const TactilePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.height = 54.0,
    this.baseColor,
    this.isSecondary = false,
  });

  @override
  State<TactilePrimaryButton> createState() => _TactilePrimaryButtonState();
}

class _TactilePrimaryButtonState extends State<TactilePrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.972).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final background = widget.isSecondary
        ? AppColor.surfaceMuted
        : (widget.baseColor ?? AppColor.ink);
    final foreground = widget.isSecondary ? AppColor.ink : AppColor.onNavy;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Semantics(
        liveRegion: widget.isLoading,
        child: FilledButton(
          onPressed: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            minimumSize: Size.fromHeight(widget.height),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: foreground)),
                const SizedBox(width: 12),
              ] else if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                  child: Text(
                      widget.isLoading ? '${widget.label}…' : widget.label,
                      textAlign: TextAlign.center)),
              if (widget.trailingIcon != null && !widget.isLoading) ...[
                const SizedBox(width: 8),
                Icon(widget.trailingIcon, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
