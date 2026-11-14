import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/core/theme/app_theme.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/account_settings_sheet.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter-Regular.ttf',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      'packages/lucide_icons_flutter/Lucide':
          '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(
                File(entry.value).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Settings navigation at text scale $scale', (t) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final state = AppState();
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: TextButton(
                        onPressed: () =>
                            AccountSettingsSheet.show(context, state),
                        child: const Text('Open settings'))))),
      ));
      await t.tap(find.text('Open settings'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Reset Local Data'), findsNothing);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('settings_refined/settings_${scale.toInt()}.png'));
      expect(find.text('Account & sync'), findsNothing);
      expect(find.text('Backup & sync'), findsNothing);
      await t.ensureVisible(find.text('Sign in'));
      await t.tap(find.text('Sign in'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('settings_refined/backup_${scale.toInt()}.png'));
      await t.ensureVisible(find.text('Continue with Google'));
      await t.pumpAndSettle();
      expect(find.text('Continue with Google').hitTestable(), findsOneWidget);
      await t.ensureVisible(find.byTooltip('Back to Settings'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back to Settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Manage data'));
      await t.tap(find.text('Manage data'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Reset Local Data').hitTestable(), findsOneWidget);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('settings_refined/data_${scale.toInt()}.png'));
      await t.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
