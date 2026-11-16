import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../state/app_state.dart';
import 'driving_live_ticker.dart';
import 'hardware_bluetooth_modal_sheet.dart';
import 'rescued_trip_banner.dart';

export 'driving_live_ticker.dart';
export 'hardware_bluetooth_modal_sheet.dart';

/// Ambient Telemetry & Dynamic Drive Capsule
/// Provides subconscious peace of mind to tradies:
/// 1. Armed State: Shows Bluetooth link & Auto-Detect readiness with subtle glowing beacon.
/// 2. Driving State: High-visibility live tracker showing real-time km and tax deduction ($) ticker.
class HomeTelemetryCapsule extends StatelessWidget {
  final AppState appState;

  const HomeTelemetryCapsule({super.key, required this.appState});

  void _showBluetoothPickerSheet(BuildContext context) {
    HardwareBluetoothModalSheet.show(context, appState);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final isDriving = appState.isDriving;
        final vehicle = appState.primaryVehicle;
        final isBtLinked = appState.isBluetoothLinked;
        final orphanedTrip = appState.orphanedInFlightTrip;

        final String? btName = vehicle?.bluetoothDeviceName?.isNotEmpty == true
            ? vehicle!.bluetoothDeviceName!
            : null;

        Widget capsule;
        if (isDriving) {
          capsule = DrivingLiveTicker(appState: appState);
        } else {
          capsule = _buildArmedState(context, btName, isBtLinked);
        }

        if (orphanedTrip != null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RescuedTripBanner(
                appState: appState,
                orphanedTrip: orphanedTrip,
              ),
              capsule,
            ],
          );
        }

        return capsule;
      },
    );
  }

  /// Armed & Ready State: Dynamic Ergonomics (Unconfigured Prompt vs Ambient Peace-of-Mind)
  Widget _buildArmedState(
      BuildContext context, String? btName, bool isBtLinked) {
    final hasBtConfigured = btName != null && btName.isNotEmpty;

    // State A: Unconfigured Bluetooth (Clean, Quiet Setup Prompt)
    if (!hasBtConfigured) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColor.line,
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColor.scrimSoft,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label:
                "Auto-Track Trips. Connect to your car's Bluetooth to set up automatic tracking.",
            child: InkWell(
              onTap: () => _showBluetoothPickerSheet(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColor.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColor.hairline,
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.bluetooth,
                            size: 18,
                            color: AppColor.brand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Auto-Track Trips',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 1.5),
                          Text(
                            "Connect to your car's Bluetooth",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: AppColors.muted,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Set up',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColor.brand,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: AppColor.navy400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final semanticLabel = isBtLinked
        ? 'Auto-Track Armed. Linked to $btName. Tap to manage Bluetooth.'
        : 'Bluetooth Disconnected. $btName not in range. Tap to manage Bluetooth.';

    // State B: Configured (Reflect real linked state vs standby/manual)
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: InkWell(
            onTap: () => _showBluetoothPickerSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Status Beacon (British Racing Green if linked, Cognac Amber if disconnected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBtLinked ? AppColors.emerald : AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Ambient Status Typography
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          isBtLinked
                              ? 'Auto-Track Armed'
                              : 'Bluetooth Disconnected',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isBtLinked
                                ? 'Linked to $btName'
                                : '$btName not in range • Tap to start',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(
                    isBtLinked ? LucideIcons.bluetooth : LucideIcons.bluetoothOff,
                    size: 13,
                    color: isBtLinked ? AppColors.emerald : AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
