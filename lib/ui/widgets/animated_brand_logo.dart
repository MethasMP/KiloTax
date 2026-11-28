import 'kiloclaim_brand_lockup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

class AnimatedBrandLogo extends StatefulWidget {
  final double size;
  final bool autoEntrance;
  final VoidCallback? onTap;

  const AnimatedBrandLogo({
    super.key,
    this.size = 72,
    this.autoEntrance = true,
    this.onTap,
  });

  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pressController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _entranceScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _pressScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );

    if (widget.autoEntrance) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.size * 0.28);

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _pressController]),
      builder: (context, child) {
        final currentScale = _entranceScale.value * _pressScale.value;
        final currentOpacity = _entranceOpacity.value;

        return Opacity(
          opacity: currentOpacity,
          child: Transform.scale(
            scale: currentScale,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.brandElectric.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: KiloClaimBrandMark(size: widget.size, tile: true),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
