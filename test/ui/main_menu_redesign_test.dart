import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import '../support/main_menu_fixtures.dart' as fixtures;

void main() {
  setUpAll(() async {
    for (final entry in {
      'Inter': [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-Medium.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf'
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
      'packages/lucide_icons_flutter/Lucide': [
        'packages/lucide_icons_flutter/assets/lucide.ttf'
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['DRIVELOG_MENU_CAPTURE'];
    if (output == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget wrap(AppState state, GlobalKey key, {double scale = 1}) =>
      ChangeNotifierProvider.value(
        value: state,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const MainScaffoldScreen(),
          ),
        ),
      );

  for (final method in TaxMethod.values) {
    testWidgets(
        '${method.name} menus render and Home opens the review-filtered Trips tab',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = await fixtures.seed(method);
      addTearDown(state.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(wrap(state, key));
      await tester.pumpAndSettle();
      expect(find.text('Review trips').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, '${method.name}-home');

      await tester.tap(find.text('Review trips').hitTestable());
      await tester.pumpAndSettle();
      final ledger = tester.widget<TripsLedgerTab>(find.byType(TripsLedgerTab));
      expect(ledger.initialFilter, 'Needs review');
      expect(ledger.initialVehicleId, state.primaryVehicle!.id);
      expect(ledger.financialYear, state.activeTaxRule.financialYear);
      expect(find.byType(ScaffoldBottomNavBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, '${method.name}-trips-review');

      await tester.tap(find.text('All').hitTestable());
      await tester.pumpAndSettle();
      await capture(tester, key, '${method.name}-trips');
      await tester.tap(find.text('Tax').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, '${method.name}-tax');

      await tester.tap(find.text('Home').hitTestable());
      await tester.pumpAndSettle();
      final summary = find.text('View tax summary →');
      await tester.scrollUntilVisible(summary, 280,
          scrollable: find
              .descendant(
                  of: find.byType(TaskHomeBody),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(summary);
      await tester.pumpAndSettle();
      expect(find.byType(ScaffoldBottomNavBar), findsOneWidget,
          reason: 'Tax summary stays in the main navigation.');
      final nav = tester
          .widget<ScaffoldBottomNavBar>(find.byType(ScaffoldBottomNavBar));
      expect(nav.currentIndex, method == TaxMethod.centsPerKm ? 2 : 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${method.name} main menus support large text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = await fixtures.seed(method);
      addTearDown(state.dispose);
      await tester.pumpWidget(wrap(state, GlobalKey(), scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Home at 200% text size');
      for (final label in ['Trips', 'Tax']) {
        await tester.tap(find.text(label).hitTestable().last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$label at 200% text size');
      }
    });
  }
  testWidgets(
      'Changing the primary vehicle clears a previous Home review scope',
      (tester) async {
    final state = await fixtures.seed(TaxMethod.logbook);
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'second',
        make: 'Ford',
        model: 'Ranger',
        taxMethod: TaxMethod.logbook,
        isPrimary: false));
    state.selectVehicle('audit');
    await tester.pumpWidget(wrap(state, GlobalKey()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review trips').hitTestable());
    await tester.pumpAndSettle();
    state.selectVehicle('second');
    await tester.pumpAndSettle();
    final ledger = tester.widget<TripsLedgerTab>(find.byType(TripsLedgerTab));
    expect(ledger.initialVehicleId, isNull);
    expect(ledger.initialFilter, 'All');
    expect(find.text('No trips yet').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
