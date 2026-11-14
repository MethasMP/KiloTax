import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../services/tracking/hardware_bluetooth_service.dart';
import '../../../../state/app_state.dart';

/// Dynamic Hardware Bluetooth Modal Sheet
/// Interacts with real Bluetooth antenna, BLE devices, and connected Audio Routes
class HardwareBluetoothModalSheet extends StatefulWidget {
  final AppState appState;

  const HardwareBluetoothModalSheet({super.key, required this.appState});

  static Future<void> show(BuildContext context, AppState appState) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => HardwareBluetoothModalSheet(appState: appState),
    );
  }

  @override
  State<HardwareBluetoothModalSheet> createState() =>
      _HardwareBluetoothModalSheetState();
}

class _HardwareBluetoothModalSheetState
    extends State<HardwareBluetoothModalSheet> {
  final HardwareBluetoothService _bluetoothService = HardwareBluetoothService();

  List<HardwareBluetoothDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _bluetoothService.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
    });

    _scanSub?.cancel();
    _scanSub = _bluetoothService.scanNearbyDevices().listen(
      (devices) {
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
    );
  }

  void _selectDevice(String deviceName) {
    HapticFeedback.mediumImpact();
    widget.appState.updatePrimaryVehicleBluetoothDevice(deviceName);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.primaryVehicle;
    final currentBt = vehicle?.bluetoothDeviceName ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.workBlueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.bluetooth,
                        color: AppColors.workBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Bluetooth Link',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy),
                        ),
                        Text(
                          'Detects in-car Bluetooth, CarPlay & BLE devices',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.workBlue),
                          )
                        : const Icon(LucideIcons.refreshCw,
                            size: 18, color: AppColors.workBlue),
                    onPressed: _isScanning ? null : _startScan,
                    tooltip: 'Rescan Bluetooth',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Discovered Hardware / Connected Audio Devices
              if (_devices.isNotEmpty) ...[
                const Text(
                  'DETECTED HARDWARE & AUDIO DEVICES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ..._devices.map((d) {
                  final isSelected = currentBt == d.name;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.workBlueLight
                          : AppColor.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.workBlue : AppColors.border,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      leading: Icon(
                        d.isAudioRoute
                            ? LucideIcons.speaker
                            : LucideIcons.bluetooth,
                        size: 18,
                        color: isSelected
                            ? AppColors.workBlue
                            : AppColors.deepNavy,
                      ),
                      title: Text(
                        d.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color:
                              isSelected ? AppColors.workBlue : AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        d.isAudioRoute
                            ? 'Active Connected Audio Route'
                            : 'Bluetooth Low Energy Hardware',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isSelected ? AppColors.workBlue : AppColors.muted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(LucideIcons.checkCircle2,
                              size: 18, color: AppColors.workBlue)
                          : const Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: AppColors.muted),
                      onTap: () => _selectDevice(d.name),
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ] else ...[
                // Empty state when scanning or no hardware in range
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceSunken,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isScanning
                            ? LucideIcons.radar
                            : LucideIcons.bluetoothOff,
                        size: 28,
                        color:
                            _isScanning ? AppColors.workBlue : AppColors.muted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isScanning
                            ? 'Scanning for Car Bluetooth & Audio...'
                            : 'No Bluetooth Devices Found Nearby',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isScanning
                            ? 'Turn on your vehicle ignition or audio system'
                            : 'Ensure Bluetooth is enabled in your device Settings',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (currentBt.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.appState.updatePrimaryVehicleBluetoothDevice(null);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(LucideIcons.unlink,
                      size: 16, color: AppColors.crimson),
                  label: const Text(
                    'Disconnect Bluetooth',
                    style: TextStyle(
                        color: AppColors.crimson, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
