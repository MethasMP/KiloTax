import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/auth/sign_in_screen.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(File('assets/fonts/Inter-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    }
    await inter.load();
    for (final family in {
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(family.key)
        ..addFont(File(family.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  testWidgets('Capture one-shot welcome entrance frames', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'Inter',
          colorScheme: AppColor.scheme,
          useMaterial3: true),
      home: RepaintBoundary(
          key: const ValueKey('frame'),
          child: OnboardingSlidesScreen(onComplete: () {})),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const ValueKey('frame')),
        matchesGoldenFile('brand_captures/welcome.png'));
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Capture branded entry and home at normal and large text',
      (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    addTearDown(state.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 2.0]) {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      for (final entry in <String, Widget>{
        'sign_in': const SignInScreen(),
        'home': Scaffold(body: SafeArea(child: TaskHomeBody(appState: state))),
      }.entries) {
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
                key: const ValueKey('branded-screen'), child: entry.value),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $scale');
        await expectLater(
            find.byKey(const ValueKey('branded-screen')),
            matchesGoldenFile(
                'brand_captures/${entry.key}_${scale.toInt()}.png'));
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
