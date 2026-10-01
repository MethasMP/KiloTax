import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

/// Machined Hardware CTA Button (Raycast / Linear / Apple HIG 2026 Inspiration)
/// Features:
/// 1. Concentric Double-Bezel Architecture (R_inner = R_outer - Padding)
/// 2. Specular Top Edge Rim Light & Tactile Depth Gradient
/// 3. Trailing Nested Icon Chip ("Button-in-Button" affordance)
/// 4. Kinetic Spring Scale Press Physics & Apple Taptic Haptics
/// 5. Adaptive Contrast: Crisp white text on dark surfaces, deep ink on light surfaces
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

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    _pressController.reverse();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null || widget.isLoading) return;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final primaryBg = widget.baseColor ?? AppColors.brandPrimary;

    const double outerRadius = 16.0;
    const double bezelPadding = 2.0;
    const double innerRadius = outerRadius - bezelPadding; // Concentric math

    if (widget.isSecondary) {
      // Secondary Clean Neutral Variant (Soft Slate / Crisp Ink text)
      return ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: isEnabled ? widget.onPressed : null,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(widget.leadingIcon, size: 18, color: AppColors.ink),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Primary High-Tactile Hero Variant (Deep Ultramarine -> Electric Blue with Specular Rim)
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerRadius),
            // Outer Bezel Enclosure: Structural containment ring
            color: isEnabled
                ? primaryBg.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
            border: Border.all(
              color: isEnabled
                  ? primaryBg.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: isEnabled ? AppShadows.buttonElevated : [],
          ),
          padding: const EdgeInsets.all(bezelPadding),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(innerRadius),
              gradient: isEnabled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF2563EB), // Specular light reflection
                        primaryBg,               // Ultramarine foundation
                      ],
                    )
                  : LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                    ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isEnabled ? 0.25 : 0.0),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (widget.leadingIcon != null) ...[
                  Icon(
                    widget.leadingIcon,
                    color: Colors.white,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.trailingIcon != null && !widget.isLoading) ...[
                  const Spacer(),
                  // Trailing Nested Icon Chip ("Button-in-Button")
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      widget.trailingIcon,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
