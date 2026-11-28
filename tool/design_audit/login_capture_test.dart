import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/auth/sign_in_screen.dart';

class _CaptureState extends AppState {
  @override
  void prewarmAuthConnection() {}
}

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(File('assets/fonts/Inter-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    }
    await inter.load();
  });
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, name: 'login_390x844'),
    (size: const Size(320, 568), scale: 2.0, name: 'login_320x568_text2'),
  ]) {
    testWidgets('Capture improved login ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = _CaptureState();
      addTearDown(state.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('login-capture'),
            child: SignInScreen(onContinueAsGuest: () {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('login-capture')),
          matchesGoldenFile('login_captures/${scenario.name}.png'));
    });
  }
}
