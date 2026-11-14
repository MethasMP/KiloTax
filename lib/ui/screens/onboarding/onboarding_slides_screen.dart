import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import 'widgets/welcome_journey_illustration.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../widgets/tactile_primary_button.dart';
import '../auth/sign_in_screen.dart';

/// A single welcome screen, with a direct return path for existing users.
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
  late final CurvedAnimation _route = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 0.85, curve: AppMotion.enterCurve),
  );
  bool _started = false;

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
    _route.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.canvas,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          const Text('KiloTax',
                              style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 32),
                          WelcomeJourneyIllustration(progress: _route),
                          const SizedBox(height: 24),
                          _reveal(
                              const Text('Your work trips.\nReady for review.',
                                  style: AppTextStyles.pageTitle),
                              0.1),
                          const SizedBox(height: 16),
                          _reveal(
                              const Text(
                                  'Keep kilometres, trip purposes and supporting records together for your accountant.',
                                  style: AppTextStyles.secondaryMedium),
                              0.2),
                          const SizedBox(height: 24),
                          const Text(
                              'Start with your vehicle. Choose how to record trips when you’re ready.',
                              style: AppTextStyles.secondaryMedium),
                        ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TactilePrimaryButton(
                                label: 'Get started',
                                onPressed: widget.onComplete,
                                trailingIcon: Icons.arrow_forward),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                builder: (routeContext) => SignInScreen(
                                  onContinueAsGuest: () =>
                                      Navigator.of(routeContext).pop(),
                                  onAuthSuccess: () =>
                                      Navigator.of(routeContext).pop(),
                                ),
                              )),
                              child: const Text(
                                  'Already have an account? Sign in'),
                            ),
                          ]),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
}
