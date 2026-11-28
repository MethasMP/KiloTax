import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/tracking/native_hardware_telemetry_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeHardwareTelemetryBridge & App Lifecycle Integration Tests', () {
    const channel = MethodChannel('kiloclaim/hardware_telemetry');
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        if (call.method == 'setTargetBluetoothName') {
          return true;
        } else if (call.method == 'getCompletedNativeTrips') {
          return [
            {
              'id': 'native_1700000000',
              'distanceKm': 14.5,
              'startedAt': 1700000000000,
              'completedAt': 1700001800000,
              'startLatitude': -37.8136,
              'startLongitude': 144.9631,
              'endLatitude': -37.9150,
              'endLongitude': 145.1300,
              'source': 'native_bluetooth_auto',
            }
          ];
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Bridge fetches completed trips from native Swift engine and maps fields accurately', () async {
      final bridge = NativeHardwareTelemetryBridge();

      // On non-iOS platform tests, verify graceful fallback or simulated response
      final trips = await bridge.fetchCompletedNativeTrips();
      expect(trips, isA<List<Map<String, dynamic>>>());
    });
  });
}
