import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';

import '../test/ui/release_main_journey_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // This manual-entry test must not drain the user's pending native trips or
  // replace their car pairing when reconstructing the test AppState.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('kiloclaim/hardware_telemetry'),
    (call) async => switch (call.method) {
      'getCompletedNativeTrips' => <dynamic>[],
      'setTargetBluetoothName' => null,
      _ => throw UnsupportedError(call.method),
    },
  );
  journey.main(nativeStorage: true);
}
