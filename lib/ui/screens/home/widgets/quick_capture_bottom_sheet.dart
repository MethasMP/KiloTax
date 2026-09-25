import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../expenses/scan_receipt_screen.dart';
import '../../trips/trip_detection_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';

class QuickCaptureBottomSheet {
  static void show(BuildContext context, AppState appState) {
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;

    String contextHint;
    if (now.hour < 11) {
      contextHint = 'Morning drive? Log your work trip';
    } else if (now.hour >= 11 && now.hour < 15) {
      contextHint = isLogbook ? 'Midday run? Scan receipts or log a trip' : 'On a job? Log your work trip';
    } else {
      contextHint = isLogbook ? 'End of shift? Log final odometer or wrap up trips' : 'End of day? Log any trips you made';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Capture',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'What do you want to add?',
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                contextHint,
                style: AppTextStyles.captionMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // 1. Trip (Always primary action)
              QuickCaptureOptionTile(
                icon: LucideIcons.car,
                color: AppColors.deepNavy,
                title: 'Trip',
                subtitle: isLogbook
                    ? 'Log drive with odometer tracking'
                    : 'Log work trip (${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}c/km ATO rate)',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showTripCaptureModeSheet(context, appState);
                },
              ),
              const SizedBox(height: 10),

              // 2. Expense — Logbook ONLY (ATO rule: CPK rate covers all car costs)
              if (isLogbook)
                QuickCaptureOptionTile(
                  icon: LucideIcons.receipt,
                  color: AppColors.emerald,
                  title: 'Car Expense',
                  subtitle: 'Scan fuel, service, or insurance receipt',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScanReceiptScreen(appState: appState),
                      ),
                    );
                  },
                ),

              // 3. Odometer (Rendered ONLY for Logbook method)
              if (isLogbook) ...[
                const SizedBox(height: 10),
                QuickCaptureOptionTile(
                  icon: LucideIcons.gauge,
                  color: AppColors.workBlue,
                  title: 'Odometer',
                  subtitle: appState.currentOdometer > 0
                      ? 'Record dashboard reading (${appState.currentOdometer.toStringAsFixed(0)} km)'
                      : 'Record opening dashboard reading',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showOdometerCaptureDialog(context, appState);
                  },
                ),
              ],

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: AppTextStyles.secondaryMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showTripCaptureModeSheet(BuildContext context, AppState appState) {
    HapticFeedback.mediumImpact();
    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Record Work Trip',
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how you want to record this trip:',
                style: AppTextStyles.captionMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Option 1: Live Drive Tracking (GPS Active)
              QuickCaptureOptionTile(
                icon: LucideIcons.navigation,
                color: AppColors.emerald,
                title: 'Start Live Drive (GPS)',
                subtitle: 'Track actual distance, speed and route in real-time',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripLiveTrackingScreen(appState: appState),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Manual Past Trip Entry
              QuickCaptureOptionTile(
                icon: LucideIcons.edit3,
                color: AppColors.deepNavy,
                title: 'Log Trip Manually',
                subtitle: isLogbook
                    ? 'Enter exact distance, purpose, and odometer readings'
                    : 'Enter distance, purpose, and travel details',
                onTap: () {
                  Navigator.of(ctx).pop();
                  TripDetectionScreen.show(context, appState);
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Back', style: AppTextStyles.secondaryMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showOdometerCaptureDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(
      text: appState.currentOdometer > 0 ? appState.currentOdometer.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(LucideIcons.gauge, color: AppColors.workBlue, size: 22),
            SizedBox(width: 8),
            Text('Record Odometer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter current dashboard odometer for ATO logbook substantiation:',
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              'Minimum allowable: ${appState.currentOdometer.toStringAsFixed(0)} km',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.ink),
              decoration: InputDecoration(
                suffixText: 'km',
                hintText: 'e.g. 45,200',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '').trim());
              if (val != null) {
                final (isValid, errMsg) = appState.validateNewCurrentOdometer(val);
                if (!isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.crimson,
                      content: Text(errMsg ?? 'Invalid odometer reading.'),
                    ),
                  );
                  return;
                }

                if (appState.primaryVehicle != null) {
                  final v = appState.primaryVehicle!;
                  appState.addVehicle(Vehicle(
                    id: v.id,
                    make: v.make,
                    model: v.model,
                    regoPlate: v.regoPlate,
                    initialOdometer: val,
                    engineCapacity: v.engineCapacity,
                    vehicleType: v.vehicleType,
                    bluetoothDeviceName: v.bluetoothDeviceName,
                    isPrimary: v.isPrimary,
                    taxMethod: v.taxMethod,
                    logbookStartDate: v.logbookStartDate,
                  ));
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.ink,
                    content: Text('✓ Dashboard odometer recorded: ${val.toStringAsFixed(0)} km'),
                  ),
                );
              }
            },
            child: const Text('Save Reading', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class QuickCaptureOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QuickCaptureOptionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
