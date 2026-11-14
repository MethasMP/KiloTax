import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../services/tracking/location_permission_service.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/hardware_bluetooth_modal_sheet.dart';

/// Checks actual permission again after returning from system settings.
class TrackingSetupScreen extends StatefulWidget {
  const TrackingSetupScreen({super.key});
  @override
  State<TrackingSetupScreen> createState() => _TrackingSetupScreenState();
}

class _TrackingSetupScreenState extends State<TrackingSetupScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      await context.read<AppState>().refreshLocationPermission();
    } catch (_) {
      // Keep the last known status when the platform is unavailable.
    }
  }

  Future<void> _request(bool background) async {
    setState(() => _busy = true);
    final service = LocationPermissionService();
    try {
      final status = await service.checkStatus();
      if (status == AppLocationPermissionStatus.serviceDisabled) {
        await service.openLocationSettings();
      } else if (status == AppLocationPermissionStatus.deniedForever ||
          background) {
        // Background access is a separate, explicit settings action. The OS
        // may not offer a second runtime prompt on all supported versions.
        await service.openAppSettings();
      } else {
        await service.requestForegroundPermission();
      }
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not check location. You can keep adding trips manually.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = state.locationPermissionStatus;
    final background = status == AppLocationPermissionStatus.grantedBackground;
    final foreground =
        background || status == AppLocationPermissionStatus.grantedForeground;
    final paired =
        state.primaryVehicle?.bluetoothDeviceName?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic trip setup')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Record trips when you drive',
            style: AppTextStyles.pageTitle),
        const SizedBox(height: 12),
        const Text(
            'Automatic detection uses your location, including when the app is not open, and your selected car’s Bluetooth connection. Review detected trips and add their purpose before relying on your records.',
            style: AppTextStyles.secondaryMedium),
        const SizedBox(height: 16),
        const Text(
            'You can add trips manually without location access. You can change location access in your phone’s Settings at any time.',
            style: AppTextStyles.secondaryMedium),
        const SizedBox(height: 24),
        _step(
            '1. Location access',
            foreground
                ? 'Location access granted'
                : status == AppLocationPermissionStatus.serviceDisabled
                    ? 'Location services are switched off'
                    : 'Not granted',
            FilledButton(
                onPressed: _busy || foreground ? null : () => _request(false),
                child: Text(foreground
                    ? 'Granted'
                    : status == AppLocationPermissionStatus.serviceDisabled
                        ? 'Open location settings'
                        : 'Continue to location access'))),
        const SizedBox(height: 16),
        _step(
            '2. Background location',
            background
                ? 'Background access granted'
                : 'For detection while the app is not open. In Settings, choose Always or Allow all the time if available.',
            OutlinedButton(
                onPressed: _busy || !foreground || background
                    ? null
                    : () => _request(true),
                child: Text(background ? 'Granted' : 'Open app settings'))),
        const SizedBox(height: 16),
        _step(
            '3. Connect your car',
            paired
                ? state.primaryVehicle!.bluetoothDeviceName!
                : 'Choose your car’s Bluetooth device while you are parked. Bluetooth access may be requested.',
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await HardwareBluetoothModalSheet.show(context, state);
                        await _refresh();
                      },
                child: Text(paired
                    ? 'Change car connection'
                    : 'Choose car Bluetooth'))),
        const SizedBox(height: 24),
        Text(
            background && paired
                ? 'Location access and car selection are configured. Detection also depends on your car connection and phone settings.'
                : 'Automatic setup is incomplete. You can still add trips manually.',
            style: AppTextStyles.secondaryMedium),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Home')),
      ])),
    );
  }

  Widget _step(String title, String description, Widget action) => Card(
        margin: EdgeInsets.zero,
        color: AppColor.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColor.hairline)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 12),
                action
              ],
            )),
      );
}
