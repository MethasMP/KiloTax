import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/theme/app_typography.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final weight in ['Regular', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await loader.load();
  });
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Navigation remains readable at $width / $scale', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var tapped = false;
        var captured = false;
        await t.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Inter', textTheme: AppType.textTheme),
          home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 844), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              bottomNavigationBar: ScaffoldBottomNavBar(
                currentIndex: 0,
                taxMethod: TaxMethod.logbook,
                onTabSelected: (index) => tapped = index == 2,
                onCenterActionTap: () => captured = true,
              ),
            ),
          ),
        ));
        expect(t.takeException(), isNull);
        for (final label in ['Home', 'Trips', 'Capture', 'Expenses', 'Tax']) {
          expect(find.text(label), findsOneWidget);
          final bounds = t.getRect(find.text(label));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
          expect(bounds.bottom, lessThanOrEqualTo(844));
        }
        await t.tap(find.text('Expenses'));
        expect(tapped, isTrue);
        await t.tap(find.text('Capture'));
        expect(captured, isTrue);
      });
    }
  }
}
