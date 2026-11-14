import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/core/theme/app_typography.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/tax_readiness_card.dart';
import 'package:kilotax/ui/screens/feedback/feedback_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await lucide.load();
    await inter.load();
    await icons.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['DRIVELOG_CAPTURE'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.audit/evidence-handoff/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'review shows actual missing records and remains usable at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
      id: 'render-vehicle',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'DEMO',
      initialOdometer: 10000,
    ));
    final date = DateTime.now();
    state.recordTrip(Trip(
      id: 'render-trip',
      vehicleId: 'render-vehicle',
      date: date,
      purpose: '',
      distanceKm: 12,
      startOdometer: 10000,
      endOdometer: 10012,
      classification: TripClassification.unclassified,
    ));
    state.recordExpense(VehicleExpense(
      id: 'render-expense',
      vehicleId: 'render-vehicle',
      amount: 65,
      category: ExpenseCategory.tollsParking,
      date: date,
    ));
    final key = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
            theme: ThemeData(
                fontFamily: 'Inter',
                colorScheme: AppColor.scheme,
                textTheme: AppType.textTheme,
                scaffoldBackgroundColor: AppColor.canvas,
                useMaterial3: true),
            home: EvidenceReviewScreen(
              appState: state,
              vehicleId: 'render-vehicle',
              financialYear: state.activeTaxRule.financialYear,
            )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
    expect(find.textContaining('2 items need attention'), findsOneWidget);
    expect(find.textContaining('Attach a receipt'), findsOneWidget);
    expect(find.text('Share draft records'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'review-evidence');
  });

  testWidgets('feedback renders preview entry without collecting records',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
          theme: ThemeData(
              fontFamily: 'Inter',
              colorScheme: AppColor.scheme,
              textTheme: AppType.textTheme,
              scaffoldBackgroundColor: AppColor.canvas,
              useMaterial3: true),
          home: const FeedbackScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Preview feedback'), findsOneWidget);
    expect(find.textContaining('No records are attached.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'product-feedback');
  });
  testWidgets(
      'CPK home card routes direct expense review to the evidence queue',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
      id: 'cpk-review',
      make: 'Toyota',
      model: 'Corolla',
      regoPlate: 'TEST',
      initialOdometer: 100,
    ));
    state.recordExpense(VehicleExpense(
      id: 'parking-review',
      vehicleId: 'cpk-review',
      amount: 20,
      category: ExpenseCategory.tollsParking,
      date: DateTime.now(),
    ));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TaxReadinessCard(appState: state),
    )));
    await tester.pumpAndSettle();
    expect(find.text('1 expense needs review'), findsOneWidget);
    await tester.tap(find.text('Review missing details'));
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
    expect(find.textContaining('Attach a receipt'), findsOneWidget);
  });
}
