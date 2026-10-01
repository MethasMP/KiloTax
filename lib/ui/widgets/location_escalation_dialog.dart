import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_constants.dart';
import '../../services/tracking/location_permission_service.dart';

/// Modal dialog educating the user on the benefits of "Always Allow" (Background Tracking)
/// Compliant with Apple App Store Guideline 5.1.1 and Google Play Location Policy
class LocationEscalationDialog extends StatelessWidget {
  final VoidCallback onDismissManualMode;
  final VoidCallback onGranted;

  const LocationEscalationDialog({
    super.key,
    required this.onDismissManualMode,
    required this.onGranted,
  });

  static Future<bool> show(
    BuildContext context, {
    required VoidCallback onDismissManualMode,
    required VoidCallback onGranted,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationEscalationDialog(
        onDismissManualMode: onDismissManualMode,
        onGranted: onGranted,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon & Badge
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              child: const Icon(LucideIcons.radio,
                  color: AppColors.emerald, size: 30),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          const Text(
            'Enable Background Auto-Tracking',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          const Text(
            'To automatically record your 12-week ATO logbook whenever you connect to your vehicle—even if your phone stays in your pocket—select "Always Allow" in the next prompt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),

          // Key Value Pillars
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _buildPillarRow(
                  icon: LucideIcons.shieldCheck,
                  title: 'Zero ATO Audit Gaps',
                  subtitle:
                      'Never lose claimable mileage by forgetting to open the app.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.darkBorder, height: 1),
                ),
                _buildPillarRow(
                  icon: LucideIcons.batteryCharging,
                  title: 'Battery-Optimised Geofencing',
                  subtitle:
                      'GPS only triggers when motion and Bluetooth align.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary CTA: Request Background Escalation
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final status = await LocationPermissionService()
                  .requestBackgroundEscalation();
              if (context.mounted) {
                Navigator.of(context).pop(true);
                if (status == AppLocationPermissionStatus.grantedBackground) {
                  onGranted();
                } else if (status ==
                    AppLocationPermissionStatus.deniedForever) {
                  await LocationPermissionService().openAppSettings();
                }
              }
            },
            child: const Text(
              'Set Location to "Always Allow"',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA: Keep Manual
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pop(false);
              onDismissManualMode();
            },
            child: const Text(
              'Keep Manual 1-Tap Tracking',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.emerald),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
