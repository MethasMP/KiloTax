import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../state/app_state.dart';
import '../../widgets/animated_brand_logo.dart';
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
            builder: (_) => const OnboardingFlowScreen(initialStep: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: AppColor.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () => _handleContinueAsGuest(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColor.line, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColor.inkMuted,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 13, color: AppColor.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),

                    // Brand Icon Anchor with clean tactile entrance & press feedback
                    const Center(
                      child: AnimatedBrandLogo(
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ATO Tax Compliance Micro Badge (Financial Anchor)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.28),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.shieldCheck,
                                size: 14, color: AppColors.emerald),
                            SizedBox(width: 6),
                            Text(
                              'ATO COMPLIANT · 100% TAX DEDUCTIBLE LOGBOOK',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Value Proposition Headline & Subtitle
                    const Text(
                      'Turn work into\ntax-ready evidence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColor.ink,
                        height: 1.18,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Track trips, capture receipts, and keep records audit-proof for Australian tradies & sole traders.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColor.inkMuted,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // GESTALT COMMON REGION: Auth Vault Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColor.line, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.anchorGlow,
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary Action: Continue with Apple (Proximity & Similarity)
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepNavy,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.deepNavy.withValues(alpha: 0.6),
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _isSigningInApple || _isSigningInGoogle
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      setState(() => _isSigningInApple = true);
                                      final appState = context.read<AppState>();
                                      bool navigatedOptimistically = false;

                                      final authRes = await appState.signInWithApple(
                                        onLocalSuccess: (optimisticUser) {
                                          navigatedOptimistically = true;
                                          if (mounted) {
                                            setState(() => _isSigningInApple = false);
                                            _onAuthSuccess(context, appState);
                                          }
                                        },
                                      );
                                      if (!mounted || navigatedOptimistically) return;
                                      setState(() => _isSigningInApple = false);

                                      if (authRes.success) {
                                        if (!navigatedOptimistically &&
                                            authRes.user != null &&
                                            context.mounted) {
                                          _onAuthSuccess(context, appState);
                                        }
                                      } else if (context.mounted &&
                                          !_isIgnorable(authRes.errorMessage)) {
                                        _showErrorDialog(
                                            context, authRes.errorMessage ?? '');
                                      }
                                    },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSigningInApple)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  else
                                    SvgPicture.asset(
                                      'apple.svg',
                                      width: 18,
                                      height: 18,
                                      colorFilter: const ColorFilter.mode(
                                          Colors.white, BlendMode.srcIn),
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
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColor.surfaceSunken,
                                foregroundColor: AppColor.ink,
                                side: const BorderSide(
                                    color: AppColor.line, width: 1.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _isSigningInApple || _isSigningInGoogle
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      setState(() => _isSigningInGoogle = true);
                                      final appState = context.read<AppState>();
                                      bool navigatedOptimistically = false;

                                      final authRes = await appState.signInWithGoogle(
                                        onLocalSuccess: (optimisticUser) {
                                          navigatedOptimistically = true;
                                          if (mounted) {
                                            setState(() => _isSigningInGoogle = false);
                                            _onAuthSuccess(context, appState);
                                          }
                                        },
                                      );
                                      if (!mounted || navigatedOptimistically) return;
                                      setState(() => _isSigningInGoogle = false);

                                      if (authRes.success) {
                                        if (!navigatedOptimistically &&
                                            authRes.user != null &&
                                            context.mounted) {
                                          _onAuthSuccess(context, appState);
                                        }
                                      } else if (context.mounted &&
                                          !_isIgnorable(authRes.errorMessage)) {
                                        _showErrorDialog(
                                            context, authRes.errorMessage ?? '');
                                      }
                                    },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSigningInGoogle)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
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

                          // Gestalt Proximity Boundary Divider
                          const Row(
                            children: [
                              Expanded(
                                  child: Divider(color: AppColor.hairline, height: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'OR CONTINUE PRIVATELY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.inkSubtle,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(color: AppColor.hairline, height: 1)),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Prominent Guest Action (Gestalt Common Region sub-group: 100% Local Mode)
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColor.canvas,
                                foregroundColor: AppColor.brand,
                                side: const BorderSide(
                                    color: AppColor.line, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _handleContinueAsGuest(context),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.userCheck,
                                      size: 18, color: AppColor.brand),
                                  SizedBox(width: 10),
                                  Text(
                                    'Continue as Guest',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                      color: AppColor.brand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Trust Reassurance: 100% Local Storage Guarantee
                          const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.shieldCheck,
                                    size: 14, color: AppColors.emerald),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'No account required. Trips saved 100% locally on device.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColor.inkSubtle,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Legal Terms & Privacy Policy Links
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'By continuing, you agree to our ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColor.inkSubtle,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => LegalDocumentSheet.show(
                              context,
                              initialTab: LegalTab.terms,
                            ),
                            child: const Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColor.brand,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' and ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColor.inkSubtle,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => LegalDocumentSheet.show(
                              context,
                              initialTab: LegalTab.privacy,
                            ),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColor.brand,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColor.inkSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
            builder: (_) => const OnboardingFlowScreen(initialStep: 2)),
      );
    }
  }
}
