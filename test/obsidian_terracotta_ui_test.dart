import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/cpk/cpk_home_body.dart';
import 'package:kilotax/ui/screens/logbook/logbook_home_body.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/tax_readiness_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final entry in {
      'Inter': [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf'
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
      'packages/lucide_icons_flutter/Lucide': [
        'packages/lucide_icons_flutter/assets/lucide.ttf'
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  test('action, content and semantic text pairs meet AA', () {
    final scheme = AppColor.scheme;
    for (final pair in [
      [scheme.onPrimary, scheme.primary],
      [scheme.onPrimaryContainer, scheme.primaryContainer],
      [scheme.onSecondary, scheme.secondary],
      [scheme.onSecondaryContainer, scheme.secondaryContainer],
      [AppColor.ink, AppColor.canvas],
      [AppColor.inkMuted, AppColor.surface],
      [AppColor.brand, AppColor.surface],
      [AppColor.attentionStrong, AppColor.surface],
    ]) {
      expect(contrast(pair[0], pair[1]), greaterThanOrEqualTo(4.5),
          reason: '$pair');
    }
    expect(AppColors.background, AppColor.canvas);
    expect(AppColors.brandPrimary, AppColor.brand);
    expect(AppColors.deepNavy, AppColor.surfaceNavy);
  });

  Future<AppState> seed(
      {bool records = true,
      bool missing = true,
      TaxMethod method = TaxMethod.centsPerKm}) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'ui',
        taxMethod: method,
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'DEMO',
        initialOdometer: 10000));
    if (records) {
      state.recordTrip(Trip(
          id: 'trip',
          vehicleId: 'ui',
          date: DateTime.now(),
          purpose: missing ? '' : 'Deliver timber to Smith renovation',
          distanceKm: 12,
          classification: missing
              ? TripClassification.unclassified
              : TripClassification.business));
    }
    return state;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['DRIVELOG_CAPTURE'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.audit/obsidian-terracotta/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<GlobalKey> render(WidgetTester tester, AppState state,
      {double width = 390,
      double scale = 1,
      bool home = false,
      bool logbook = false}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'Inter',
                  colorScheme: AppColor.scheme,
                  scaffoldBackgroundColor: AppColor.canvas,
                  useMaterial3: true),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: home
                      ? (logbook
                          ? LogbookHomeBody(appState: state)
                          : CpkHomeBody(appState: state))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: TaxReadinessCard(appState: state))),
            ))));
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('missing evidence stays actionable at 320px and 200% text',
      (tester) async {
    final state = await seed();
    final key = await render(tester, state, width: 320, scale: 2);
    expect(find.text('1 item needs attention'), findsOneWidget);
    expect(find.text('Review missing details'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'evidence-large-text');
    await tester.tap(find.text('Review missing details'));
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
  });

  testWidgets('empty records never imply readiness', (tester) async {
    final state = await seed(records: false);
    final key = await render(tester, state);
    expect(find.text('Your evidence starts here'), findsOneWidget);
    expect(find.text('Send to accountant'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'evidence-empty');
  });

  testWidgets('clear queue offers review rather than ATO approval',
      (tester) async {
    final state = await seed(missing: false);
    final key = await render(tester, state);
    expect(find.text('Review before sharing'), findsOneWidget);
    expect(find.text('Send to accountant'), findsOneWidget);
    expect(find.textContaining('ATO'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'evidence-review');
  });

  testWidgets(
      'CPK home prioritizes trip review and keeps expense evidence accessible',
      (tester) async {
    final state = await seed();
    state.recordExpense(VehicleExpense(
        id: 'expense',
        vehicleId: 'ui',
        amount: 20,
        date: DateTime.now(),
        category: ExpenseCategory.tollsParking));
    final key = await render(tester, state, home: true);
    expect(find.byKey(const ValueKey('home-next-task')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('home-next-task')),
            matching: find.text('Review 1 trip')),
        findsOneWidget);
    await tester.ensureVisible(find.text('Review trips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review trips').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
    expect(find.textContaining('Attach a receipt'), findsOneWidget);
    expect(find.text('ATO COMPLIANT'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'home-cpk');
  });
  testWidgets('logbook home shows the same evidence next step', (tester) async {
    final state = await seed(method: TaxMethod.logbook);
    final key = await render(tester, state, home: true, logbook: true);
    expect(find.byKey(const ValueKey('home-next-task')), findsOneWidget);
    await tester.ensureVisible(find.text('Review trips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review trips').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'home-logbook');
  });
}
