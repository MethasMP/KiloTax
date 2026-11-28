import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle
              .load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });

  Future<void> pump(WidgetTester tester, Size size, double scale,
      {VoidCallback? cancel}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('vehicle-capture'),
        child: VehicleSetupFlow(onVehicleCreated: (_) {}, onCancel: cancel),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, name: 'phone'),
    (size: const Size(320, 568), scale: 2.0, name: 'compact_text2'),
  ]) {
    testWidgets('Vehicle selection ${scenario.name}', (tester) async {
      var cancelled = 0;
      await pump(tester, scenario.size, scenario.scale,
          cancel: () => cancelled++);
      expect(find.text('Choose your vehicle'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsNothing);
      expect(find.text('Common work vehicles'), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.systemOverlayStyle, SystemUiOverlayStyle.dark);
      final firstTile = find.ancestor(
          of: find.text('Ford Ranger'), matching: find.byType(ListTile));
      expect(tester.getSize(firstTile).height, greaterThanOrEqualTo(48));
      if (scenario.scale == 1) {
        expect(tester.getSize(firstTile).height, lessThanOrEqualTo(76));
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('vehicle-capture')),
          matchesGoldenFile('goldens/vehicle_selection/${scenario.name}.png'));
      await tester.ensureVisible(find.text('Enter vehicle manually'));
      await tester.tap(find.text('Enter vehicle manually'));
      await tester.pumpAndSettle();
      expect(find.text('Make (Brand)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Make (Brand)'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      expect(cancelled, 1);
    });
  }

  testWidgets('No search matches keeps manual entry and clear-search recovery',
      (tester) async {
    await pump(tester, const Size(320, 568), 1);
    await tester.enterText(find.byType(TextField), 'zzzz-no-such-car');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching vehicles.'), findsOneWidget);
    expect(find.text('Ford Ranger'), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enter vehicle manually'));
    expect(find.text('Enter vehicle manually').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Clear search'));
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Common work vehicles'), findsOneWidget);
    expect(find.text('Ford Ranger'), findsOneWidget);
    await tester.tap(find.text('Ford Ranger'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
