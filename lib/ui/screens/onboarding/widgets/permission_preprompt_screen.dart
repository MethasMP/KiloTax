import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../widgets/tactile_primary_button.dart';

class PermissionPrepromptScreen extends StatefulWidget {
  final Future<void> Function() onEnableTracking;
  final VoidCallback onSkipOrManual;

  const PermissionPrepromptScreen({
    super.key,
    required this.onEnableTracking,
    required this.onSkipOrManual,
  });

  @override
  State<PermissionPrepromptScreen> createState() =>
      _PermissionPrepromptScreenState();
}

class _PermissionPrepromptScreenState extends State<PermissionPrepromptScreen> {
  bool _isRequesting = false;

  Future<void> _handleEnable() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    try {
      await widget.onEnableTracking();
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40.0)
                      .clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColor.brand.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 38,
                            color: AppColor.brand,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Automatic Trip Logging',
                        style: AppTextStyles.pageTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Allow location and motion access so KiloClaim records your drives from site to site automatically.',
                        style: AppTextStyles.secondaryMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _buildBullet(
                        icon: Icons.shield_outlined,
                        title: 'Trip records for review',
                        description:
                            'Each trip fills in your distance and route automatically. Tap once to confirm if it was for work.',
                      ),
                      const SizedBox(height: 16),
                      _buildBullet(
                        icon: Icons.directions_car_outlined,
                        title: 'Select "Always Allow"',
                        description:
                            'Lets the app log trips in the background while your phone stays in your pocket.',
                      ),
                      const SizedBox(height: 16),
                      _buildBullet(
                        icon: Icons.battery_charging_full_outlined,
                        title: 'Battery-Optimised Motion Sensors',
                        description:
                            'GPS turns on only when your vehicle moves and turns off when you park.',
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      TactilePrimaryButton(
                        label: _isRequesting
                            ? 'Enabling...'
                            : 'Enable automatic tracking',
                        onPressed: _isRequesting ? null : _handleEnable,
                        trailingIcon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed:
                              _isRequesting ? null : widget.onSkipOrManual,
                          child: const Text(
                            'I’ll log trips manually instead',
                            style: TextStyle(
                              color: AppColor.inkMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColor.line),
          ),
          child: Icon(icon, size: 20, color: AppColor.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColor.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColor.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
