import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test/support/main_menu_fixtures.dart';

void main() {
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle
              .load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });
  for (final scenario in [
    (
      name: 'cpk_populated',
      method: TaxMethod.centsPerKm,
      empty: false,
      size: const Size(390, 844),
      scale: 1.0,
      noVehicle: false
    ),
    (
      name: 'logbook_empty',
      method: TaxMethod.logbook,
      empty: true,
      size: const Size(390, 844),
      scale: 1.0,
      noVehicle: false
    ),
    (
      name: 'cpk_compact_text2',
      method: TaxMethod.centsPerKm,
      empty: false,
      size: const Size(320, 568),
      scale: 2.0,
      noVehicle: false
    ),
    (
      name: 'no_vehicle',
      method: TaxMethod.centsPerKm,
      empty: true,
      size: const Size(390, 844),
      scale: 1.0,
      noVehicle: true
    ),
  ]) {
    testWidgets('Home capture ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = scenario.noVehicle
          ? AuditState()
          : await seed(scenario.method, empty: scenario.empty);
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
            key: const ValueKey('home-capture'),
            child: Scaffold(
              bottomNavigationBar: ScaffoldBottomNavBar(
                currentIndex: 0,
                taxMethod: scenario.method,
                onTabSelected: (_) {},
                onCenterActionTap: () {},
              ),
              body: SafeArea(child: TaskHomeBody(appState: state)),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: scenario.name);
      await expectLater(find.byKey(const ValueKey('home-capture')),
          matchesGoldenFile('home_captures/${scenario.name}.png'));
      if (scenario.noVehicle) {
        expect(find.text('Add your vehicle'), findsOneWidget);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: '${scenario.name} after scrolling');
    });
  }
}
