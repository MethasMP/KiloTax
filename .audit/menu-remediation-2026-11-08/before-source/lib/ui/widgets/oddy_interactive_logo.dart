import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../core/theme/app_color.dart';

class OddyInteractiveLogo extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const OddyInteractiveLogo({
    super.key,
    this.size = 80,
    this.onTap,
  });

  @override
  State<OddyInteractiveLogo> createState() => _OddyInteractiveLogoState();
}

class _OddyInteractiveLogoState extends State<OddyInteractiveLogo>
    with TickerProviderStateMixin {
  // 3D Tilt Coordinates
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Animation Controllers
  late final AnimationController _sheenController;
  late final AnimationController _resetController;
  late final AnimationController _scaleController;

  late final Animation<double> _sheenProgress;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _sheenProgress = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(parent: _sheenController, curve: Curves.easeInOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _sheenController.forward(from: -1.2);
    });

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 280),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _sheenController.dispose();
    _resetController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final half = widget.size / 2;
    final dx = (details.localPosition.dx - half).clamp(-half, half) / half;
    final dy = (details.localPosition.dy - half).clamp(-half, half) / half;

    setState(() {
      _tiltX = -dy * 0.28; // Radians pitch
      _tiltY = dx * 0.28;  // Radians yaw
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _scaleController.reverse();
    _animateBackToCenter();
  }

  void _onPanCancel() {
    _scaleController.reverse();
    _animateBackToCenter();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _scaleController.forward();

    final half = widget.size / 2;
    final dx = (details.localPosition.dx - half).clamp(-half, half) / half;
    final dy = (details.localPosition.dy - half).clamp(-half, half) / half;

    setState(() {
      _tiltX = -dy * 0.22;
      _tiltY = dx * 0.22;
    });
  }

  void _onTapUp(TapUpDetails _) {
    HapticFeedback.selectionClick();
    _scaleController.reverse();
    _animateBackToCenter();

    // Trigger specular flash on tap
    _sheenController.forward(from: -1.2);
    widget.onTap?.call();
  }

  void _animateBackToCenter() {
    final startX = _tiltX;
    final startY = _tiltY;

    final anim = CurvedAnimation(
      parent: _resetController,
      curve: Curves.elasticOut,
    );

    anim.addListener(() {
      setState(() {
        _tiltX = startX * (1.0 - anim.value);
        _tiltY = startY * (1.0 - anim.value);
      });
    });

    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.size * 0.28);

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _sheenProgress]),
      builder: (context, child) {
        // Perspective 3D Matrix Transform (Viktor Oddy standard)
        final scale = _scaleAnimation.value;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0018) // Depth perspective
          ..rotateX(_tiltX)
          ..rotateY(_tiltY)
          ..scaleByDouble(scale, scale, scale, 1.0);

        return GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          behavior: HitTestBehavior.opaque,
          child: Transform(
            transform: transform,
            alignment: FractionalOffset.center,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  // Dynamic cast shadow shifted by tilt
                  BoxShadow(
                    color: AppColors.deepNavy.withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: -2,
                    offset: Offset(_tiltY * 30, 10 + (-_tiltX * 25)),
                  ),
                  // Ambient chromatic glow
                  BoxShadow(
                    color: AppColor.attentionStrong.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: Image.asset(
                      'assets/icon_master.png',
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Transform.translate(
                        offset: Offset(
                          _sheenProgress.value * widget.size,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: Container(
                            width: widget.size * 0.45,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.28),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
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
          ),
        );
      },
    );
  }
}
