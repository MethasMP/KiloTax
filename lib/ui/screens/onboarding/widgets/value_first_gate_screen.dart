import '../../../widgets/adaptive_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../../widgets/legal_document_sheet.dart';
import '../../../../core/theme/app_color.dart';

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
  bool _showBackupOptions = false;
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(
                  child: Icon(LucideIcons.circleCheck,
                      size: 40, color: AppColors.emerald)),
              const SizedBox(height: 20),
              // Hero Value Calculation Headline
              const Text(
                'Vehicle added',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You’re ready to record your first trip.',
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
                child: AdaptiveRow(
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
                        child: Icon(
                          widget.vehicle.vehicleType.iconData,
                          size: 24,
                          color: AppColor.ink,
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
                            '${widget.vehicle.taxMethod.title} · FY ${appState.activeTaxRule.financialYear}',
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

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColor.ink,
                ),
                onPressed: _isSigningInApple || _isSigningInGoogle
                    ? null
                    : () => setState(
                        () => _showBackupOptions = !_showBackupOptions),
                icon: const Icon(LucideIcons.cloud, size: 20),
                label: Text(_showBackupOptions
                    ? 'Hide backup options'
                    : 'Back up your records'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional. Sign in to keep your records across devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: AppColors.muted),
              ),
              if (_showBackupOptions) ...[
                const SizedBox(height: 20),
                // 1-Tap Sign In with Apple
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
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
                    child: AdaptiveRow(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      side:
                          const BorderSide(color: AppColors.border, width: 1.2),
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
                    child: AdaptiveRow(
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
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.ink,
                foregroundColor: AppColor.surface,
                minimumSize: const Size.fromHeight(52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onPressed: _isSigningInApple || _isSigningInGoogle
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await appState.setGuestMode(true);
                      if (!mounted) return;
                      widget.onContinue();
                    },
              child: const Text(
                'Start using DriveLog',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),

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
    );
  }
}
