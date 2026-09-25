import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audio_session/audio_session.dart';

/// Real Hardware Bluetooth Discovered Device Representation
class HardwareBluetoothDevice {
  final String id;
  final String name;
  final bool isAudioRoute;
  final int? rssi;

  const HardwareBluetoothDevice({
    required this.id,
    required this.name,
    this.isAudioRoute = false,
    this.rssi,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HardwareBluetoothDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Hardware Bluetooth Discovery & Audio Route Detection Service
/// Combines:
/// 1. AVAudioSession / Android Audio Route inspection (detects connected Car Audio / CarPlay / Handsfree)
/// 2. Hardware Bluetooth Low Energy (BLE) scanning with flutter_blue_plus
class HardwareBluetoothService {
  static final HardwareBluetoothService _instance = HardwareBluetoothService._internal();
  factory HardwareBluetoothService() => _instance;
  HardwareBluetoothService._internal();

  /// Inspect current system audio output devices for connected Car Bluetooth/CarPlay/Headsets
  Future<List<HardwareBluetoothDevice>> getActiveAudioBluetoothDevices() async {
    final List<HardwareBluetoothDevice> audioDevices = [];
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();

      for (final dev in devices) {
        // Look for Bluetooth A2DP, Headset, or Car Audio outputs
        final typeName = dev.type.name.toLowerCase();
        if (typeName.contains('bluetooth') ||
            typeName.contains('car') ||
            typeName.contains('headset') ||
            typeName.contains('a2dp')) {
          final cleanName = dev.name.trim();
          if (cleanName.isNotEmpty) {
            audioDevices.add(
              HardwareBluetoothDevice(
                id: 'audio_${dev.id}',
                name: cleanName,
                isAudioRoute: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Error querying system audio devices: $e');
    }
    return audioDevices;
  }

  /// Start hardware BLE scan and emit discovered devices
  Stream<List<HardwareBluetoothDevice>> scanNearbyDevices({Duration timeout = const Duration(seconds: 4)}) async* {
    final Map<String, HardwareBluetoothDevice> discovered = {};

    // 1. Immediately inject currently connected system audio bluetooth devices
    final activeAudio = await getActiveAudioBluetoothDevices();
    for (final dev in activeAudio) {
      discovered[dev.name] = dev;
    }
    yield discovered.values.toList();

    // 2. Query devices already connected to system by any app
    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (final dev in systemDevices) {
        final name = dev.platformName.isNotEmpty
            ? dev.platformName
            : dev.advName;
        if (name.trim().isNotEmpty) {
          discovered[name] = HardwareBluetoothDevice(
            id: dev.remoteId.str,
            name: name.trim(),
            isAudioRoute: false,
          );
        }
      }
      yield discovered.values.toList();
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Note querying system devices: $e');
    }

    // 3. Perform live BLE scan for nearby advertising devices
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        yield discovered.values.toList();
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        yield discovered.values.toList();
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          if (name.trim().isNotEmpty) {
            discovered[name] = HardwareBluetoothDevice(
              id: r.device.remoteId.str,
              name: name.trim(),
              isAudioRoute: false,
              rssi: r.rssi,
            );
          }
        }
        yield discovered.values.toList();
      }
    } catch (e) {
      debugPrint('[KiloTax Bluetooth] Live scan error or simulator fallback: $e');
    } finally {
      try {
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
      } catch (_) {}
    }

    // 4. Obsidian-Grade Developer & Simulator Emulation:
    // When running in Debug on Simulator where physical radio antenna is absent,
    // inject a real-time responsive Simulated Car Beacon so the entire 1-tap pairing
    // and live tracking lifecycle can be verified end-to-end without touching a keyboard.
    if (kDebugMode && discovered.isEmpty) {
      discovered['Tesla Model Y (Simulated BT)'] = const HardwareBluetoothDevice(
        id: 'sim_ble_tesla_modely',
        name: 'Tesla Model Y (Simulated BT)',
        isAudioRoute: false,
        rssi: -58,
      );
      yield discovered.values.toList();
    }
  }

  /// Stop active scan safely
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }
}
