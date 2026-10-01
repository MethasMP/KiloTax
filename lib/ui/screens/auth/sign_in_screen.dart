import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../state/app_state.dart';
import '../../widgets/legal_document_sheet.dart';
import '../home/main_scaffold_screen.dart';
import '../onboarding/onboarding_flow_screen.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: AppColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: () => _handleContinueAsGuest(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Text(
                'Skip for now',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              label: const Icon(LucideIcons.arrowRight, size: 14),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),

                    // Brand Icon Anchor
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.deepNavy,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepNavy.withValues(alpha: 0.14),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.fileText,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Value Proposition Headline & Subtitle
                    const Text(
                      'Turn work into\ntax-ready evidence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.22,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Track trips, capture receipts, and keep records audit-proof for Australian tradies & sole traders.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Primary Action: Continue with Apple
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.black.withValues(alpha: 0.6),
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
                                final authRes = await appState.signInWithApple();
                                if (!mounted) return;
                                setState(() => _isSigningInApple = false);

                                if (authRes.success) {
                                  if (authRes.user != null && context.mounted) {
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
                            SvgPicture.asset(
                              'apple.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Continue with Apple',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Secondary Action: Continue with Google
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(
                              color: AppColors.border, width: 1.2),
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
                                final authRes = await appState.signInWithGoogle();
                                if (!mounted) return;
                                setState(() => _isSigningInGoogle = false);

                                if (authRes.success) {
                                  if (authRes.user != null && context.mounted) {
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
                            SvgPicture.asset(
                              'google.svg',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OR Divider
                    const Row(
                      children: [
                        Expanded(
                            child: Divider(color: AppColors.border, height: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: AppColors.border, height: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prominent Guest Action (No Account Needed - 100% Local Mode)
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          foregroundColor: AppColors.deepNavy,
                          side: const BorderSide(
                              color: Color(0xFFCBD5E1), width: 1.2),
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
                                size: 18, color: AppColors.deepNavy),
                            SizedBox(width: 10),
                            Text(
                              'Continue as Guest',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                                color: AppColors.deepNavy,
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
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
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
                              color: AppColors.muted,
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
                                color: AppColors.deepNavy,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' and ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
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
                                color: AppColors.deepNavy,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
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
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
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
