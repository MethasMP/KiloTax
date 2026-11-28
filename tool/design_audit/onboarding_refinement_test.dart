import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:kiloclaim/ui/screens/onboarding/widgets/value_first_gate_screen.dart';

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
    testWidgets('Onboarding remains usable at text scale $scale', (t) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final state = AppState();
      final screens = <String, Widget>{
        'vehicle': VehicleSetupFlow(onVehicleCreated: (_) {}, onCancel: () {}),
        'method': VehicleSetupFlow(
            initialStage: VehicleSetupStage.taxMethod,
            includeBluetoothSetup: false,
            onVehicleCreated: (_) {}),
        'success': ValueFirstGateScreen(
            vehicle: Vehicle(id: 'preview', make: 'Ford', model: 'Ranger'),
            onContinue: () {}),
      };
      for (final entry in screens.entries) {
        await t.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(key: ValueKey(entry.key), child: entry.value),
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${entry.key} / $scale');
        await expectLater(
            find.byKey(ValueKey(entry.key)),
            matchesGoldenFile(
                'onboarding_refined/${entry.key}_${scale.toInt()}.png'));
        if (entry.key == 'success') {
          expect(
              find.text('Start using DriveLog').hitTestable(), findsOneWidget);
          await t.ensureVisible(find.text('Back up your records'));
          await t.tap(find.text('Back up your records'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('Continue with Google'));
          await t.pumpAndSettle();
          expect(
              find.text('Continue with Google').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
          await expectLater(
              find.byKey(ValueKey(entry.key)),
              matchesGoldenFile(
                  'onboarding_refined/backup_${scale.toInt()}.png'));
        }
      }
      await t.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
