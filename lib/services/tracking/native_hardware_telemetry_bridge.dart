import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart bridge to iOS Native [KiloTaxBackgroundEngine]
/// Handles CoreBluetooth State Restoration and low-memory native GPS logging.
class NativeHardwareTelemetryBridge {
  static const MethodChannel _channel =
      MethodChannel('kilotax/hardware_telemetry');

  static final NativeHardwareTelemetryBridge _instance =
      NativeHardwareTelemetryBridge._internal();
  factory NativeHardwareTelemetryBridge() => _instance;
  NativeHardwareTelemetryBridge._internal();

  /// Synchronize the user's primary vehicle Bluetooth device name down to iOS Native
  Future<void> syncTargetBluetoothName(String? bluetoothName) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('setTargetBluetoothName', bluetoothName);
      debugPrint(
          '[NativeTelemetryBridge] Synced vehicle Bluetooth to iOS Native: $bluetoothName');
    } catch (e) {
      debugPrint('[NativeTelemetryBridge] Warning syncing target Bluetooth: $e');
    }
  }

  /// Retrieve any trips that were autonomously logged by the native Swift engine
  /// while the Flutter process was completely dead.
  Future<List<Map<String, dynamic>>> fetchCompletedNativeTrips() async {
    if (!Platform.isIOS) return [];

    try {
      final List<dynamic>? raw =
          await _channel.invokeMethod<List<dynamic>>('getCompletedNativeTrips');
      if (raw == null || raw.isEmpty) return [];

      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('[NativeTelemetryBridge] Error fetching completed native trips: $e');
      return [];
    }
  }
}
