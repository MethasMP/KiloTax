import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/trip.dart';
import '../../../../services/tracking/hardware_bluetooth_service.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_detection_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';

/// Frontier Ambient Telemetry & Dynamic Drive Capsule
/// Inspired by Apple Dynamic Island & Tesla in-car telemetry.
/// Provides subconscious peace of mind to tradies:
/// 1. Armed State: Shows Bluetooth link & Auto-Detect readiness with subtle glowing beacon.
/// 2. Driving State: High-visibility live tracker showing real-time km and tax deduction ($) ticker.
class HomeTelemetryCapsule extends StatelessWidget {
  final AppState appState;

  const HomeTelemetryCapsule({super.key, required this.appState});

  void _onCapsuleTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripLiveTrackingScreen(appState: appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final isDriving = appState.isDriving;
        final vehicle = appState.primaryVehicle;
        final isBtLinked = appState.isBluetoothLinked;

        final String? btName = vehicle?.bluetoothDeviceName?.isNotEmpty == true
            ? vehicle!.bluetoothDeviceName!
            : null;

        if (isDriving) {
          return _buildDrivingState(context);
        } else {
          return _buildArmedState(context, btName, isBtLinked);
        }
      },
    );
  }

  void _onStopDrive(BuildContext context) {
    HapticFeedback.heavyImpact();
    final finalDistance = double.parse(appState.activeDriveDistanceKm.toStringAsFixed(2));
    final lastOdo = appState.currentOdometer;

    final detectedTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: appState.primaryVehicle?.id ?? 'default_vehicle',
      distanceKm: finalDistance > 0 ? finalDistance : 0.1,
      date: DateTime.now(),
      purpose: 'Client / Job',
      startOdometer: lastOdo,
      endOdometer: lastOdo + (finalDistance > 0 ? finalDistance : 0.1),
      originAddress: 'Current Location',
      destinationAddress: 'Destination Site',
    );

    appState.endLiveDrive();

    TripDetectionScreen.show(context, appState, trip: detectedTrip);
  }

  /// 1. Active Driving State: Spotify-Inspired Telemetry Mini-Player (降维打击)
  /// Clean white card, animated signal/sound wave equalizer, live money ticker,
  /// and standard media controls (Pause, Stop & Save, Expand HUD).
  Widget _buildDrivingState(BuildContext context) {
    final distance = appState.activeDriveDistanceKm;
    final taxSaved = appState.activeDriveTaxSavedAud;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCapsuleTap(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Animated Equalizer Bars (Universal sign of active background process)
                const _EqualizerBars(),
                const SizedBox(width: 10),

                // Metrics: Live Ticker & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+\$${taxSaved.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Recording in background',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Media Control: Stop & Log Drive (Square icon)
                GestureDetector(
                  onTap: () => _onStopDrive(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.square, size: 11, color: AppColors.crimson),
                        SizedBox(width: 4),
                        Text(
                          'Stop',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.crimson,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Media Control: View Full HUD (Expand icon)
                GestureDetector(
                  onTap: () => _onCapsuleTap(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      LucideIcons.maximize2,
                      size: 13,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. Armed & Ready State: Sun Tzu Dynamic Ergonomics (Unconfigured Prompt vs Ambient Peace-of-Mind)
  Widget _buildArmedState(BuildContext context, String? btName, bool isBtLinked) {
    final hasBtConfigured = btName != null && btName.isNotEmpty;

    // State A: Unconfigured Bluetooth (One-time Setup Prompt)
    if (!hasBtConfigured) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBluetoothPickerSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(
                      LucideIcons.bluetooth,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pair Vehicle Bluetooth',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Auto-log drives in background',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.deepNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pair Now',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // State B: Configured & Armed (Ultra-clean, zero button clutter, pure ambient confidence)
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
        child: InkWell(
          onTap: () => _showBluetoothPickerSheet(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Glowing Emerald Armed Beacon
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Ambient Status Typography
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Auto-Track Armed',
                        style: TextStyle(
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
                          'Linked to $btName',
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
                const Icon(
                  LucideIcons.bluetooth,
                  size: 13,
                  color: AppColors.emerald,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBluetoothPickerSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _HardwareBluetoothModalSheet(appState: appState),
    );
  }
}

/// Dynamic Hardware Bluetooth Modal Sheet
/// Interacts with real Bluetooth antenna, BLE devices, and connected Audio Routes
class _HardwareBluetoothModalSheet extends StatefulWidget {
  final AppState appState;

  const _HardwareBluetoothModalSheet({required this.appState});

  @override
  State<_HardwareBluetoothModalSheet> createState() => _HardwareBluetoothModalSheetState();
}

class _HardwareBluetoothModalSheetState extends State<_HardwareBluetoothModalSheet> {
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
                    child: const Icon(LucideIcons.bluetooth, color: AppColors.workBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Bluetooth Link',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                        ),
                        Text(
                          'Detects in-car Bluetooth, CarPlay & BLE devices',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.workBlue),
                          )
                        : const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.workBlue),
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
                      color: isSelected ? AppColors.workBlueLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.workBlue : AppColors.border,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Icon(
                        d.isAudioRoute ? LucideIcons.speaker : LucideIcons.bluetooth,
                        size: 18,
                        color: isSelected ? AppColors.workBlue : AppColors.deepNavy,
                      ),
                      title: Text(
                        d.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.workBlue : AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        d.isAudioRoute ? 'Active Connected Audio Route' : 'Bluetooth Low Energy Hardware',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColors.workBlue : AppColors.muted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(LucideIcons.checkCircle2, size: 18, color: AppColors.workBlue)
                          : const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
                      onTap: () => _selectDevice(d.name),
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ] else ...[
                // Empty state when scanning or no hardware in range
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isScanning ? LucideIcons.radar : LucideIcons.bluetoothOff,
                        size: 28,
                        color: _isScanning ? AppColors.workBlue : AppColors.muted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isScanning ? 'Scanning for Car Bluetooth & Audio...' : 'No Bluetooth Devices Found Nearby',
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
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
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
                  icon: const Icon(LucideIcons.unlink, size: 16, color: AppColors.crimson),
                  label: const Text(
                    'Disconnect Bluetooth',
                    style: TextStyle(color: AppColors.crimson, fontWeight: FontWeight.w700),
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

/// Spotify-style animated 3-bar sound/signal equalizer
/// Indicates live background tracking smoothly without flashing lights or battery drain.
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 3 out-of-phase equalizer bars (like Spotify playback indicator)
          final h1 = 6.0 + (t * 10.0);
          final h2 = 14.0 - (t * 8.0);
          final h3 = 8.0 + ((1.0 - t) * 8.0);

          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBar(h1),
                const SizedBox(width: 2.5),
                _buildBar(h2),
                const SizedBox(width: 2.5),
                _buildBar(h3),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
