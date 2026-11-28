import 'package:flutter/material.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/kiloclaim_brand_lockup.dart';
import '../../widgets/tactile_primary_button.dart';
import 'widgets/welcome_trip_preview.dart';

/// A brief, explorable introduction before account and vehicle setup.
class OnboardingSlidesScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingSlidesScreen({super.key, required this.onComplete});

  @override
  State<OnboardingSlidesScreen> createState() => _OnboardingSlidesScreenState();
}

class _OnboardingSlidesScreenState extends State<OnboardingSlidesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.welcome,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _entrance.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _entrance.forward();
    }
  }

  Widget _reveal(Widget child, double start) => AnimatedBuilder(
        animation: _entrance,
        child: child,
        builder: (context, child) {
          final value = Interval(start, 1, curve: AppMotion.enterCurve)
              .transform(_entrance.value);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset:
                  Offset(0, AppMotion.reduced(context) ? 0 : 8 * (1 - value)),
              child: child,
            ),
          );
        },
      );

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            S.xl, S.xl, S.xl, S.lg),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - S.xl - S.lg,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                KiloClaimBrandLockup(
                                    compact: false, markProgress: _entrance),
                                SizedBox(
                                    height:
                                        MediaQuery.textScalerOf(context)
                                                    .scale(1) >
                                                1.3
                                            ? S.lg
                                            : S.xxxl),
                                _reveal(
                                  Text(
                                    'Drives logged automatically.\nReceipts linked in one tap.',
                                    style: AppType.title,
                                  ),
                                  0.1,
                                ),
                                const SizedBox(height: S.sm),
                                _reveal(
                                  Text(
                                    'KiloClaim records your site trips in the background and keeps every receipt with the job.',
                                    style: AppType.body
                                        .copyWith(color: AppColor.inkMuted),
                                  ),
                                  0.15,
                                ),
                                const SizedBox(height: S.xxl),
                                Expanded(
                                  child: _reveal(
                                    WelcomeTripPreview(progress: _entrance),
                                    0.22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(S.xl, S.sm, S.xl, S.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TactilePrimaryButton(
                          label: 'Get started',
                          baseColor: AppColor.brand,
                          onPressed: widget.onComplete,
                          trailingIcon: AppIcons.forward,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
