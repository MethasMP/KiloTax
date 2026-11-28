import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_typography.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';

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
        final semantics = t.ensureSemantics();
        try {
          expect(t.takeException(), isNull);
          for (final label in ['Home', 'Review', 'Records', 'Pack']) {
            expect(find.text(label), findsOneWidget);
            final bounds = t.getRect(find.text(label));
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(width));
            expect(bounds.bottom, lessThanOrEqualTo(844));
          }
          final centerAction = find.bySemanticsLabel('Capture');
          expect(centerAction, findsOneWidget);
          final centerBounds = t.getRect(centerAction);
          expect(centerBounds.left, greaterThanOrEqualTo(0));
          expect(centerBounds.right, lessThanOrEqualTo(width));
          expect(centerBounds.bottom, lessThanOrEqualTo(844));
          await t.tap(find.text('Records'));
          expect(tapped, isTrue);
          await t.tap(centerAction);
          expect(captured, isTrue);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
  testWidgets(
      'CPK has five balanced slots and preserves Pack and Capture actions',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var selected = -1;
    var added = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ScaffoldBottomNavBar(
          currentIndex: 0,
          onTabSelected: (index) => selected = index,
          onCenterActionTap: () => added++,
        ),
      ),
    ));
    final labels = ['Home', 'Review', 'Capture', 'Records', 'Pack'];
    final centers =
        labels.map((label) => t.getCenter(find.text(label)).dx).toList();
    final spacing = centers[1] - centers[0];
    expect(centers[2] - centers[1], closeTo(spacing, 1));
    expect(centers[3] - centers[2], closeTo(spacing, 1));
    expect(centers[4] - centers[3], closeTo(spacing, 1));
    await t.tap(find.text('Pack'));
    expect(selected, 3);
    await t.tap(find.text('Capture'));
    expect(added, 1);
    expect(t.takeException(), isNull);
  });
}
