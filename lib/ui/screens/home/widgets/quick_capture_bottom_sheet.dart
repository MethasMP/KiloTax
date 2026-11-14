import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../state/app_state.dart';
import '../../cpk/cpk_trip_entry_screen.dart';
import '../../expenses/scan_receipt_screen.dart';
import '../../logbook/logbook_trip_entry_screen.dart';
import '../../logbook/logbook_progress_screen.dart';
import '../../logbook/logbook_setup_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';

class QuickCaptureBottomSheet {
  static void show(BuildContext context, AppState appState) {
    HapticFeedback.mediumImpact();

    final isLogbook = appState.primaryVehicle?.taxMethod == TaxMethod.logbook;

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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CAPTURE',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.muted,
                    letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Capture a record',
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                isLogbook
                    ? 'Scan receipts or record a drive. Review the details before sharing.'
                    : 'Record a drive or add a past trip. Review its work purpose.',
                style: AppTextStyles.captionMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (isLogbook) ...[
                QuickCaptureOptionTile(
                  icon: Icons.document_scanner_outlined,
                  color: AppColors.emerald,
                  title: 'Scan a receipt',
                  subtitle:
                      'Read merchant, total and date, then check the details',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScanReceiptScreen.show(context, appState);
                  },
                ),
                const SizedBox(height: 10),
              ],
              QuickCaptureOptionTile(
                icon: LucideIcons.navigation,
                color: AppColors.deepNavy,
                title: appState.isDriving
                    ? 'Open current drive'
                    : 'Record with GPS',
                subtitle: appState.isDriving
                    ? 'Return to your recording and finish when parked'
                    : 'Start a drive, then review its purpose when parked',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TripLiveTrackingScreen(appState: appState),
                  ));
                },
              ),
              const SizedBox(height: 10),
              QuickCaptureOptionTile(
                icon: AppIcons.edit,
                color: AppColors.deepNavy,
                title: 'Add a past trip',
                subtitle: 'Enter the details without location access',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => isLogbook
                        ? LogbookTripEntryScreen(appState: appState)
                        : CpkTripEntryScreen(appState: appState),
                  ));
                },
              ),
              if (isLogbook) ...[
                const SizedBox(height: 10),
                QuickCaptureOptionTile(
                  icon: AppIcons.odometer,
                  color: AppColors.workBlue,
                  title: 'Odometer',
                  subtitle: 'Review logbook readings and odometer photos',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          appState.primaryVehicle?.logbookStartDate == null
                              ? LogbookSetupScreen(appState: appState)
                              : const LogbookProgressScreen(),
                    ));
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child:
                    const Text('Cancel', style: AppTextStyles.secondaryMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showTripCaptureModeSheet(
      BuildContext context, AppState appState) {
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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
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
                title: 'Record with GPS',
                subtitle: 'Start and stop a drive. Location access is needed.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TripLiveTrackingScreen(appState: appState),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Manual Past Trip Entry
              QuickCaptureOptionTile(
                icon: AppIcons.edit,
                color: AppColors.deepNavy,
                title: 'Add a past trip',
                subtitle: isLogbook
                    ? 'Enter exact distance, purpose, and odometer readings'
                    : 'Enter the date, distance and work purpose. No location access needed.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (isLogbook) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LogbookTripEntryScreen(appState: appState),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CpkTripEntryScreen(appState: appState),
                      ),
                    );
                  }
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
                child: Icon(icon, color: color, size: AppIconSize.control),
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
              const Icon(AppIcons.next,
                  size: AppIconSize.inline, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
