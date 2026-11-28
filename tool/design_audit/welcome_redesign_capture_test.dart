import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, name: 'phone'),
    (size: const Size(320, 568), scale: 2.0, name: 'compact_text2'),
    (size: const Size(844, 390), scale: 2.0, name: 'landscape_text2'),
  ]) {
    testWidgets('Welcome rendered ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            textScaler: TextScaler.linear(scenario.scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('welcome-capture'),
          child: OnboardingSlidesScreen(onComplete: () {}),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = tester.getRect(find.text('Get started'));
      expect(action.bottom, lessThan(scenario.size.height - 34));
      await expectLater(find.byKey(const ValueKey('welcome-capture')),
          matchesGoldenFile('welcome_redesign/${scenario.name}.png'));
      await tester.ensureVisible(find.text('Receipt'));
      await tester.tap(find.text('Receipt'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('EXAMPLE RECEIPT'), findsOneWidget);
      if (scenario.scale == 1) {
        await expectLater(find.byKey(const ValueKey('welcome-capture')),
            matchesGoldenFile('welcome_redesign/receipt.png'));
      }
    });
  }
}
