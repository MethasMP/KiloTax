import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/main_menu_fixtures.dart' as fixtures;

class DriveNavigationState extends fixtures.AuditState {
  bool driving = false;

  @override
  bool get isDriving => driving;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final method in TaxMethod.values) {
    const expectedLabel = 'Capture';
    const expectedIcon = Icons.add;
    testWidgets('Center action exposes $expectedLabel for ${method.name}',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var actionCalls = 0;
      final tabSelections = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ScaffoldBottomNavBar(
            currentIndex: 0,
            taxMethod: method,
            onTabSelected: tabSelections.add,
            onCenterActionTap: () => actionCalls++,
          ),
        ),
      ));
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Capture'), findsOneWidget);
      expect(find.byIcon(expectedIcon), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(expectedLabel)),
        matchesSemantics(
          label: expectedLabel,
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.bySemanticsLabel(expectedLabel));
      expect(actionCalls, 1);
      expect(tabSelections, isEmpty);
      await tester.tap(find.text('Review'));
      expect(actionCalls, 1);
      expect(tabSelections, [1]);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('Trips tools offer starting a drive without replacing Add trip',
      (tester) async {
    final state = DriveNavigationState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: TripsLedgerTab(appState: state)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add trip'), findsOneWidget);
    await tester.tap(find.byTooltip('Trip tools'));
    await tester.pumpAndSettle();
    expect(find.text('Start manually'), findsOneWidget);
    expect(find.text('Open current drive'), findsNothing);
    expect(find.text('Review evidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Trips tools reopen the active drive instead of offering a new one',
      (tester) async {
    final state = DriveNavigationState()..driving = true;
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: TripsLedgerTab(appState: state)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trip tools'));
    await tester.pumpAndSettle();
    expect(find.text('Open current drive'), findsOneWidget);
    expect(find.text('Start manually'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
