import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/tracking/location_permission_service.dart';
import '../../../../state/app_state.dart';
import '../../tracking/tracking_setup_screen.dart';
import 'driving_live_ticker.dart';
import 'rescued_trip_banner.dart';

export 'driving_live_ticker.dart';
export 'hardware_bluetooth_modal_sheet.dart';

class HomeTelemetryCapsule extends StatelessWidget {
  final AppState appState;
  const HomeTelemetryCapsule({super.key, required this.appState});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final orphaned = appState.orphanedInFlightTrip;
          final car = appState.primaryVehicle?.bluetoothDeviceName;
          final configured = car != null && car.isNotEmpty;
          final background = appState.locationPermissionStatus ==
              AppLocationPermissionStatus.grantedBackground;
          final connected = configured && appState.isBluetoothLinked;
          final available = background && connected;
          final title = !configured
              ? 'Automatic recording is off'
              : !background
                  ? 'Location setup incomplete'
                  : connected
                      ? 'Car connected'
                      : 'Waiting for car connection';
          final detail = !configured
              ? "Connect to your car's Bluetooth"
              : !background
                  ? 'Background location access is needed'
                  : connected
                      ? 'Review detected trips after driving'
                      : '$car not connected';
          return Column(mainAxisSize: MainAxisSize.min, children: [
            if (orphaned != null)
              RescuedTripBanner(appState: appState, orphanedTrip: orphaned),
            if (appState.isDriving)
              DrivingLiveTicker(appState: appState)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color:
                      available ? AppColor.positiveTint : AppColor.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Icon(
                        connected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: available
                            ? AppColor.positiveStrong
                            : AppColor.brand),
                    title: Text(title, style: AppType.bodyStrong),
                    subtitle: Text(detail, style: AppType.secondary),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const TrackingSetupScreen())),
                  ),
                ),
              ),
          ]);
        },
      );
}
