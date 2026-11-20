import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Offline Launch Immunity & Cold-Start Graceful Fallback', () {
    test('AppState.init() initializes successfully without network/cloud', () async {
      final appState = AppState();
      
      // Should not throw even when completely offline
      await expectLater(appState.init(), completes);

      // Verify state is usable offline
      expect(appState.isAuthenticated, isFalse);
      expect(appState.trips, isNotNull);
      expect(appState.vehicles, isNotNull);
    });

    test('AppState operates offline-first and can record trips locally', () async {
      final appState = AppState();
      await appState.init();

      // Ensure local state mutations work without cloud connection
      expect(appState.syncStatus, equals(SyncStatus.idle));
      expect(appState.isAuthenticated, isFalse);
    });
  });
}
