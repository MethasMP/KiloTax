import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Welcome keeps actions visible at 320x568, text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var starts = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: OnboardingSlidesScreen(onComplete: () => starts++),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final start = find.text('Get started');
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(568));
      await tester.tap(start);
      expect(starts, 1);
      await tester.scrollUntilVisible(
        find.textContaining('Oak St Site'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final destination = find.textContaining('Oak St Site');
      expect(tester.getRect(destination).overlaps(viewport), isTrue);
      expect(find.text('EVIDENCE CHAIN'), findsOneWidget);
      expect(find.text('24.6 km'), findsOneWidget);
      expect(find.text(r'$86.40'), findsOneWidget);
      expect(find.text('Pack ready'), findsOneWidget);
      expect(starts, 1, reason: 'Exploring examples does not start setup');
      expect(tester.takeException(), isNull);
    });
  }
}
