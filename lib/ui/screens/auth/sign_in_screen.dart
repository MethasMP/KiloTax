import '../../widgets/adaptive_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../state/app_state.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/legal_document_sheet.dart';
import '../home/main_scaffold_screen.dart';
import '../onboarding/onboarding_flow_screen.dart';
import '../../../core/theme/app_color.dart';

/// Authentication Screen aligned with KiloTax standard design system
class SignInScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final VoidCallback? onContinueAsGuest;

  const SignInScreen({
    super.key,
    this.onAuthSuccess,
    this.onContinueAsGuest,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningInApple = false;
  bool _isSigningInGoogle = false;

  @override
  void initState() {
    super.initState();
    // Warm DNS & TLS socket in background immediately on screen entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().prewarmAuthConnection();
      }
    });
  }

  void _handleContinueAsGuest(BuildContext context) {
    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    appState.setGuestMode(true);

    if (widget.onContinueAsGuest != null) {
      widget.onContinueAsGuest!();
      return;
    }
    if (appState.hasVehicle) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const OnboardingFlowScreen(initialStep: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.canvas,
        appBar: AppBar(
            title: const Text('Sign in'), backgroundColor: AppColor.canvas),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 48)
                                .clamp(0, double.infinity)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Sign in to your records',
                                        style: AppType.title),
                                    SizedBox(height: 12),
                                    Text(
                                        'Use the same Apple or Google account you used before. You can also keep working on this device without an account.',
                                        style: AppType.body),
                                  ]),
                              Padding(
                                  padding: const EdgeInsets.only(top: 32),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Primary Action: Continue with Apple (Proximity & Similarity)
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: 52),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.deepNavy,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: AppColors
                                                  .deepNavy
                                                  .withValues(alpha: 0.6),
                                              disabledForegroundColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.6),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14)),
                                              elevation: 0,
                                            ),
                                            onPressed: _isSigningInApple ||
                                                    _isSigningInGoogle
                                                ? null
                                                : () async {
                                                    HapticFeedback
                                                        .mediumImpact();
                                                    setState(() =>
                                                        _isSigningInApple =
                                                            true);
                                                    final appState = context
                                                        .read<AppState>();
                                                    bool
                                                        navigatedOptimistically =
                                                        false;

                                                    final authRes =
                                                        await appState
                                                            .signInWithApple(
                                                      onLocalSuccess:
                                                          (optimisticUser) {
                                                        navigatedOptimistically =
                                                            true;
                                                        if (mounted) {
                                                          setState(() =>
                                                              _isSigningInApple =
                                                                  false);
                                                          _onAuthSuccess(
                                                              context,
                                                              appState);
                                                        }
                                                      },
                                                    );
                                                    if (!mounted ||
                                                        navigatedOptimistically) {
                                                      return;
                                                    }
                                                    setState(() =>
                                                        _isSigningInApple =
                                                            false);

                                                    if (authRes.success) {
                                                      if (!navigatedOptimistically &&
                                                          authRes.user !=
                                                              null &&
                                                          context.mounted) {
                                                        _onAuthSuccess(
                                                            context, appState);
                                                      }
                                                    } else if (context
                                                            .mounted &&
                                                        !_isIgnorable(authRes
                                                            .errorMessage)) {
                                                      _showErrorDialog(
                                                          context,
                                                          authRes.errorMessage ??
                                                              '');
                                                    }
                                                  },
                                            child: AdaptiveRow(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_isSigningInApple)
                                                  const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                  )
                                                else
                                                  SvgPicture.asset(
                                                    'apple.svg',
                                                    width: 18,
                                                    height: 18,
                                                    colorFilter:
                                                        const ColorFilter.mode(
                                                            Colors.white,
                                                            BlendMode.srcIn),
                                                  ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  _isSigningInApple
                                                      ? 'Connecting Apple...'
                                                      : 'Continue with Apple',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Secondary Action: Continue with Google
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: 52),
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  AppColor.surfaceSunken,
                                              foregroundColor: AppColor.ink,
                                              side: const BorderSide(
                                                  color: AppColor.line,
                                                  width: 1.1),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14)),
                                              elevation: 0,
                                            ),
                                            onPressed: _isSigningInApple ||
                                                    _isSigningInGoogle
                                                ? null
                                                : () async {
                                                    HapticFeedback
                                                        .mediumImpact();
                                                    setState(() =>
                                                        _isSigningInGoogle =
                                                            true);
                                                    final appState = context
                                                        .read<AppState>();
                                                    bool
                                                        navigatedOptimistically =
                                                        false;

                                                    final authRes =
                                                        await appState
                                                            .signInWithGoogle(
                                                      onLocalSuccess:
                                                          (optimisticUser) {
                                                        navigatedOptimistically =
                                                            true;
                                                        if (mounted) {
                                                          setState(() =>
                                                              _isSigningInGoogle =
                                                                  false);
                                                          _onAuthSuccess(
                                                              context,
                                                              appState);
                                                        }
                                                      },
                                                    );
                                                    if (!mounted ||
                                                        navigatedOptimistically) {
                                                      return;
                                                    }
                                                    setState(() =>
                                                        _isSigningInGoogle =
                                                            false);

                                                    if (authRes.success) {
                                                      if (!navigatedOptimistically &&
                                                          authRes.user !=
                                                              null &&
                                                          context.mounted) {
                                                        _onAuthSuccess(
                                                            context, appState);
                                                      }
                                                    } else if (context
                                                            .mounted &&
                                                        !_isIgnorable(authRes
                                                            .errorMessage)) {
                                                      _showErrorDialog(
                                                          context,
                                                          authRes.errorMessage ??
                                                              '');
                                                    }
                                                  },
                                            child: AdaptiveRow(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_isSigningInGoogle)
                                                  const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              AppColor.ink),
                                                    ),
                                                  )
                                                else
                                                  SvgPicture.asset(
                                                    'google.svg',
                                                    width: 18,
                                                    height: 18,
                                                  ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  _isSigningInGoogle
                                                      ? 'Connecting Google...'
                                                      : 'Continue with Google',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    letterSpacing: -0.2,
                                                    color: AppColor.ink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        TextButton(
                                            onPressed: () =>
                                                _handleContinueAsGuest(context),
                                            style: TextButton.styleFrom(
                                                minimumSize:
                                                    const Size(48, 48)),
                                            child: const Text(
                                                'Continue without an account')),
                                        const SizedBox(height: 16),
                                        const Text(
                                            'By continuing, you agree to our Terms of Service and Privacy Policy.',
                                            style: AppType.secondary),
                                        Wrap(spacing: 8, children: [
                                          TextButton(
                                              onPressed: () =>
                                                  LegalDocumentSheet.show(
                                                      context,
                                                      initialTab:
                                                          LegalTab.terms),
                                              child: const Text(
                                                  'Terms of Service')),
                                          TextButton(
                                              onPressed: () =>
                                                  LegalDocumentSheet.show(
                                                      context,
                                                      initialTab:
                                                          LegalTab.privacy),
                                              child:
                                                  const Text('Privacy Policy')),
                                        ]),
                                      ])),
                            ]),
                      ),
                    ))),
      );

  bool _isIgnorable(String? error) {
    if (error == null) return true;
    final lower = error.toLowerCase();
    return lower.contains('cancel') ||
        lower.contains('1001') || // Apple user cancelled
        lower.contains('canceled');
  }

  String _cleanErrorMessage(String? raw) {
    if (raw == null) return 'Unable to sign in right now. Please try again.';
    final lower = raw.toLowerCase();
    if (lower.contains('1000') || lower.contains('unknown')) {
      return 'Apple Sign In is unavailable on this device. Please ensure you are signed into an Apple ID in device Settings.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    return 'Unable to complete sign in. Please try again or use another option.';
  }

  void _showErrorDialog(BuildContext context, String message) {
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Sign In Issue'),
        content: Text(_cleanErrorMessage(message)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleContinueAsGuest(context);
            },
            child: const Text(
              'Continue as Guest',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColor.brand,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _onAuthSuccess(BuildContext context, AppState appState) {
    if (widget.onAuthSuccess != null) {
      widget.onAuthSuccess!();
      return;
    }
    if (appState.hasVehicle) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffoldScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const OnboardingFlowScreen(initialStep: 1)),
      );
    }
  }
}
