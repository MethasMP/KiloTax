import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/widgets/account_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountSettingsSheet - Data & Backup UI Rendering', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Guest sign-in is separate from local data management',
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

      expect(find.text('Sign in').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Export backup file'), findsNothing);
      await tester.tap(find.byTooltip('Back to Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Backup & sync'), findsNothing);
      expect(find.text('Account & sync'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Reset Local Data'), findsNothing);
      expect(find.text('Export backup file'), findsNothing);
      await tester.tap(find.text('Manage data'));
      await tester.pumpAndSettle();
      expect(find.text('Export backup file'), findsOneWidget);
      expect(find.text('Restore backup file'), findsOneWidget);
      expect(find.text('Include receipt images and pending drafts'),
          findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Reset Local Data'), findsOneWidget);
      await tester.tap(find.text('Reset Local Data'));
      await tester.pumpAndSettle();
      expect(find.text('Erase Everything Anyway'), findsOneWidget);
      await tester.tap(find.text('Keep Data & Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send feedback'));
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Tell us what got in the way'), findsOneWidget);
    });
  });
}
