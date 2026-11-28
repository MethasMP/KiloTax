import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart bridge to iOS/Android Native background telemetry daemons.
/// Handles Bluetooth State Restoration / ACL BroadcastReceiver and native GPS logging.
class NativeHardwareTelemetryBridge {
  static const MethodChannel _channel =
      MethodChannel('kiloclaim/hardware_telemetry');

  static final NativeHardwareTelemetryBridge _instance =
      NativeHardwareTelemetryBridge._internal();
  factory NativeHardwareTelemetryBridge() => _instance;
  NativeHardwareTelemetryBridge._internal();

  @visibleForTesting
  static bool? testOverrideIsMobileHost;

  bool get _isMobileHost =>
      testOverrideIsMobileHost ??
      (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Synchronize the user's primary vehicle Bluetooth device name/UUID down to Native
  Future<void> syncTargetBluetoothName(String? bluetoothName, {String? bluetoothUuid}) async {
    if (!_isMobileHost) return;

    try {
      if (bluetoothUuid != null && bluetoothUuid.isNotEmpty) {
        await _channel.invokeMethod('setTargetBluetoothTarget', {
          'name': bluetoothName,
          'uuid': bluetoothUuid,
        });
      } else {
        await _channel.invokeMethod('setTargetBluetoothName', bluetoothName);
      }
      debugPrint(
          '[NativeTelemetryBridge] Synced vehicle Bluetooth to Native: $bluetoothName (UUID: $bluetoothUuid)');
    } on MissingPluginException {
      // Graceful fallback during tests, simulator runs, or unattached channels.
      return;
    } catch (e) {
      debugPrint('[NativeTelemetryBridge] Warning syncing target Bluetooth: $e');
    }
  }

  /// Retrieve any trips that were autonomously logged by the native engine
  /// while the Flutter process was completely dead (Non-destructive read).
  Future<List<Map<String, dynamic>>> fetchCompletedNativeTrips() async {
    if (!_isMobileHost) return [];

    try {
      final List<dynamic>? raw =
          await _channel.invokeMethod<List<dynamic>>('getCompletedNativeTrips');
      if (raw == null || raw.isEmpty) return [];

      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on MissingPluginException {
      // Graceful fallback during tests or simulator runs without native host
      return [];
    } catch (e) {
      debugPrint('[NativeTelemetryBridge] Error fetching completed native trips: $e');
      return [];
    }
  }

  /// Two-Phase Commit Acknowledgement: Notifies native engine that Flutter has successfully
  /// persisted the trips, safely removing them from native buffer.
  Future<void> acknowledgeNativeTripsIngested(List<String> tripIds) async {
    if (!_isMobileHost || tripIds.isEmpty) return;

    try {
      await _channel.invokeMethod<bool>('acknowledgeNativeTripsIngested', tripIds);
    } on MissingPluginException {
      return;
    } catch (e) {
      debugPrint('[NativeTelemetryBridge] Error acknowledging native trips: $e');
    }
  }
}
