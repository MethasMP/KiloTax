import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/ui/screens/logbook/widgets/tax_exemption_streak_hero.dart';

void main() {
  testWidgets(
      'TaxExemptionStreakHero renders cleanly without overflow on standard mobile width (375px)',
      (WidgetTester tester) async {
    // Set screen size to standard iPhone width (375x812)
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TaxExemptionStreakHero(
                currentDay: 1,
                currentWeek: 1,
                atRiskAmount: 12400.0,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify there are no flutter render overflow errors
    final exception = tester.takeException();
    if (exception != null) {
      if (exception is FlutterError) {
        debugPrint('DUMP_START');
        debugPrint(
            exception.diagnostics.map((d) => d.toStringDeep()).join('\n---\n'));
        debugPrint('DUMP_END');
      }
    }
    expect(exception, isNull);

    // Verify key elements are rendered clearly in the clean single-card layout
    expect(find.textContaining('12-WEEK'), findsOneWidget);
    expect(find.text('Week 1 of 12'), findsOneWidget);
    expect(find.text('Vehicle Odometer'), findsOneWidget);
    expect(find.textContaining('business'), findsOneWidget);
    expect(find.text('Keep reviewing trips as you go.'), findsOneWidget);
  });
}
