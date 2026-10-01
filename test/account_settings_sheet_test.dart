import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/account_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountSettingsSheet - Data & Backup UI Rendering', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Renders Guest Mode Cloud Shield card and Export Backup Tile',
        (tester) async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AccountSettingsSheet.show(context, appState),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Check Guest Mode UI
      expect(find.text('Guest / Offline Mode'), findsOneWidget);
      expect(find.text('Local Device Only'), findsOneWidget);
      expect(find.text('Protect 5-Year Tax Evidence'), findsOneWidget);
      expect(find.text('Apple ID'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);

      // Check Local File Backup Tile
      expect(find.text('Export Backup to Files'), findsOneWidget);
      expect(find.text('Save .json snapshot to iCloud Drive or Files'),
          findsOneWidget);
      expect(find.text('Reset Local Data'), findsOneWidget);
    });
  });
}
