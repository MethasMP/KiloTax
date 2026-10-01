import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../../widgets/legal_document_sheet.dart';
import '../../../widgets/vehicle_render_widget.dart';

class ValueFirstGateScreen extends StatefulWidget {
  final Vehicle vehicle;
  final VoidCallback onContinue;

  const ValueFirstGateScreen({
    super.key,
    required this.vehicle,
    required this.onContinue,
  });

  @override
  State<ValueFirstGateScreen> createState() => _ValueFirstGateScreenState();
}

class _ValueFirstGateScreenState extends State<ValueFirstGateScreen> {
  bool _isSigningInApple = false;
  bool _isSigningInGoogle = false;

  void _onAuthSuccess() {
    widget.onContinue();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Authentication Error',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(message,
            style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.deepNavy)),
          ),
        ],
      ),
    );
  }

  bool _isIgnorable(String? msg) {
    if (msg == null) return true;
    final lower = msg.toLowerCase();
    return lower.contains('cancel') ||
        lower.contains('dismiss') ||
        lower.contains('1001') ||
        lower.contains('closed');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final maxClaim = appState.activeTaxRule.maxCentsPerKmClaim;
    final rateCents = (appState.activeTaxRule.centsPerKmRate * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Top Trust Badge
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.shieldCheck,
                          size: 14, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'ATO Cents per Km · FY ${appState.activeTaxRule.financialYear}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hero Value Calculation Headline
              const Text(
                'Your Vehicle Is Tax-Ready',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Claim up to \$${maxClaim.toStringAsFixed(0)} at $rateCents¢/km on your tax return.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Selected Vehicle Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: VehicleRenderWidget(
                          vehicleType: widget.vehicle.vehicleType,
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle.displayName,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cap: 5,000 km · Max Claim: \$${maxClaim.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Soft Gate Header
              const Text(
                'Save your records across devices',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect with Apple or Google for automatic cloud backup, or continue as a guest on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // 1-Tap Sign In with Apple
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSigningInApple || _isSigningInGoogle
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          setState(() => _isSigningInApple = true);
                          final authRes = await appState.signInWithApple();
                          if (!mounted) return;
                          setState(() => _isSigningInApple = false);

                          if (authRes.success && authRes.user != null) {
                            _onAuthSuccess();
                          } else if (!_isIgnorable(authRes.errorMessage)) {
                            _showErrorDialog(authRes.errorMessage ?? '');
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Continue with Google
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSigningInApple || _isSigningInGoogle
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          setState(() => _isSigningInGoogle = true);
                          final authRes = await appState.signInWithGoogle();
                          if (!mounted) return;
                          setState(() => _isSigningInGoogle = false);

                          if (authRes.success && authRes.user != null) {
                            _onAuthSuccess();
                          } else if (!_isIgnorable(authRes.errorMessage)) {
                            _showErrorDialog(authRes.errorMessage ?? '');
                          }
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('google.svg', width: 18, height: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.5,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // OR Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border, height: 1)),
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
                  Expanded(child: Divider(color: AppColors.border, height: 1)),
                ],
              ),
              const SizedBox(height: 18),

              // Prominent Guest Escape Hatch (Apple 5.1.1(ii) Compliant)
              SizedBox(
                height: 50,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: AppColors.deepNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await appState.setGuestMode(true);
                    widget.onContinue();
                  },
                  child: const Text(
                    'Continue as Guest (Device Only)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Footer Legal Note
              Center(
                child: TextButton(
                  onPressed: () => LegalDocumentSheet.show(context),
                  child: const Text(
                    'Privacy Policy · Terms of Service',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
