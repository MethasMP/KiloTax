import '../../widgets/kiloclaim_brand_lockup.dart';
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

/// Authentication Screen aligned with KiloClaim standard design system
class SignInScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final VoidCallback? onContinueAsGuest;

  const SignInScreen({
    super.key,
    this.onAuthSuccess,
    this.onContinueAsGuest,
  });

  /// Pre-warms SVG assets used on the sign-in screen so the first frame
  /// renders without waiting on asset loading and SVG parsing.
  static Future<void> precacheAssets() async {
    for (final asset in const ['apple.svg', 'google.svg']) {
      final loader = SvgAssetLoader(asset);
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    }
  }

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
    if (_isBusy) return;
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

  bool get _isBusy => _isSigningInApple || _isSigningInGoogle;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColor.canvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
          canPop: !_isBusy,
          child: Scaffold(
            backgroundColor: AppColor.surfaceNavy,
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(context,
                                compact: constraints.maxHeight < 600 ||
                                    MediaQuery.textScalerOf(context).scale(1) >
                                        1.3),
                            Container(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                              decoration: const BoxDecoration(
                                color: AppColor.canvas,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(32)),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Get started with KiloClaim',
                                        style: AppType.titleSmall),
                                    const SizedBox(height: 8),
                                    const Text(
                                        'Back up your trips and receipts.',
                                        style: AppType.secondary),
                                    const SizedBox(height: 24),
                                    ConstrainedBox(
                                      key: const ValueKey('sign-in-apple'),
                                      constraints:
                                          const BoxConstraints(minHeight: 52),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.deepNavy,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                          disabledBackgroundColor: AppColors
                                              .deepNavy
                                              .withValues(alpha: 0.6),
                                          disabledForegroundColor: Colors.white
                                              .withValues(alpha: 0.6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          elevation: 0,
                                        ),
                                        onPressed: _isSigningInApple ||
                                                _isSigningInGoogle
                                            ? null
                                            : () async {
                                                HapticFeedback.mediumImpact();
                                                setState(() =>
                                                    _isSigningInApple = true);
                                                final appState =
                                                    context.read<AppState>();
                                                bool navigatedOptimistically =
                                                    false;

                                                final authRes = await appState
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
                                                          context, appState);
                                                    }
                                                  },
                                                );
                                                if (!mounted ||
                                                    navigatedOptimistically) {
                                                  return;
                                                }
                                                setState(() =>
                                                    _isSigningInApple = false);

                                                if (authRes.success) {
                                                  if (!navigatedOptimistically &&
                                                      authRes.user != null &&
                                                      context.mounted) {
                                                    _onAuthSuccess(
                                                        context, appState);
                                                  }
                                                } else if (context.mounted &&
                                                    !_isIgnorable(
                                                        authRes.errorMessage)) {
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
                                                          Color>(Colors.white),
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
                                            Flexible(
                                                child: Text(
                                              _isSigningInApple
                                                  ? 'Connecting Apple...'
                                                  : 'Continue with Apple',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 52),
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: AppColor.surface,
                                          foregroundColor: AppColor.ink,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                          side: const BorderSide(
                                              color: AppColor.line, width: 1.1),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          elevation: 0,
                                        ),
                                        onPressed: _isSigningInApple ||
                                                _isSigningInGoogle
                                            ? null
                                            : () async {
                                                HapticFeedback.mediumImpact();
                                                setState(() =>
                                                    _isSigningInGoogle = true);
                                                final appState =
                                                    context.read<AppState>();
                                                bool navigatedOptimistically =
                                                    false;

                                                final authRes = await appState
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
                                                          context, appState);
                                                    }
                                                  },
                                                );
                                                if (!mounted ||
                                                    navigatedOptimistically) {
                                                  return;
                                                }
                                                setState(() =>
                                                    _isSigningInGoogle = false);

                                                if (authRes.success) {
                                                  if (!navigatedOptimistically &&
                                                      authRes.user != null &&
                                                      context.mounted) {
                                                    _onAuthSuccess(
                                                        context, appState);
                                                  }
                                                } else if (context.mounted &&
                                                    !_isIgnorable(
                                                        authRes.errorMessage)) {
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
                                                          Color>(AppColor.ink),
                                                ),
                                              )
                                            else
                                              SvgPicture.asset(
                                                'google.svg',
                                                width: 18,
                                                height: 18,
                                              ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                                child: Text(
                                              _isSigningInGoogle
                                                  ? 'Connecting Google...'
                                                  : 'Continue with Google',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                                color: AppColor.ink,
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed:
                                          _isBusy ? null : _showGuestOptions,
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColor.ink,
                                        minimumSize: const Size(48, 48),
                                      ),
                                      child: const Text(
                                          'Continue without an account',
                                          textAlign: TextAlign.center),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                        'By continuing, you agree to our',
                                        textAlign: TextAlign.center,
                                        style: AppType.secondary),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        _legalLink(
                                            'Terms of Service', LegalTab.terms),
                                        _legalLink(
                                            'Privacy Policy', LegalTab.privacy),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildHero(BuildContext context, {required bool compact}) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  color: AppColor.onNavy,
                  onPressed:
                      _isBusy ? null : () => Navigator.of(context).maybePop(),
                  icon: const BackButtonIcon(),
                ),
              const KiloClaimBrandMark(size: 28),
              const SizedBox(width: 8),
              const Text('KiloClaim',
                  style: TextStyle(
                      color: AppColor.onNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ]),
            if (!compact) ...[
              const SizedBox(height: 24),
              const Text('Every trip.\nEvery receipt.\nTogether.',
                  style: TextStyle(
                      color: AppColor.onNavy,
                      fontSize: 34,
                      height: 1.08,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              const ExcludeSemantics(
                  child: SizedBox(
                height: 64,
                width: double.infinity,
                child: CustomPaint(painter: _RecordsIllustration()),
              )),
            ],
          ],
        ),
      );

  void _showGuestOptions() {
    if (_isBusy) return;
    _showEntrySheet(
      title: 'Start on this device',
      description:
          'Your records are saved on this device only. They cannot be recovered if it is lost or the app is deleted. You can sign in later to add backup.',
      action: 'Continue on this device',
      onContinue: () => _handleContinueAsGuest(context),
    );
  }

  void _showEntrySheet(
      {required String title,
      required String description,
      required String action,
      VoidCallback? onContinue}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColor.canvas,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppType.titleSmall),
              const SizedBox(height: 16),
              Text(description, style: AppType.body),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColor.ink,
                    foregroundColor: AppColor.surface,
                    minimumSize: const Size(48, 52),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16)),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onContinue?.call();
                },
                child: Text(action, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalLink(String label, LegalTab tab) => TextButton(
        onPressed: () => LegalDocumentSheet.show(context, initialTab: tab),
        style: TextButton.styleFrom(
          foregroundColor: AppColor.inkMuted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: AppType.secondary.copyWith(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
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
              _showGuestOptions();
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

class _RecordsIllustration extends CustomPainter {
  const _RecordsIllustration();

  @override
  void paint(Canvas canvas, Size size) {
    final route = Paint()
      ..color = AppColor.brandBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final endpoint = size.width - 66;
    final path = Path()
      ..moveTo(8, 44)
      ..lineTo(size.width * .27, 44)
      ..quadraticBezierTo(size.width * .36, 44, size.width * .36, 26)
      ..quadraticBezierTo(size.width * .36, 12, size.width * .46, 12)
      ..lineTo(endpoint, 12);
    canvas.drawPath(path, route);
    canvas.drawCircle(
        const Offset(8, 44), 6, Paint()..color = AppColor.brandBright);
    canvas.drawCircle(
        const Offset(8, 44), 2, Paint()..color = AppColor.surfaceNavy);
    final receipt = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 54, 0, 48, 60), const Radius.circular(8));
    canvas.drawRRect(receipt, Paint()..color = AppColor.canvas);
    final line = Paint()
      ..color = AppColor.line
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final y in [17.0, 27.0, 37.0]) {
      canvas.drawLine(Offset(size.width - 43, y),
          Offset(size.width - (y == 37 ? 27 : 17), y), line);
    }
    canvas.drawLine(
        Offset(size.width - 43, 48), Offset(size.width - 31, 48), route);
  }

  @override
  bool shouldRepaint(covariant _RecordsIllustration oldDelegate) => false;
}
