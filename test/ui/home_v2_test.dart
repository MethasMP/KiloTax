import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/core/theme/app_typography.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/evidence_review_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/models/home_record_summary.dart';
import 'package:kilotax/ui/screens/dashboard/task_home_body.dart';
import 'package:kilotax/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kilotax/ui/screens/home/widgets/quick_capture_bottom_sheet.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/home_record_hero.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const rule = AtoTaxRule(
    financialYear: '2026-27',
    centsPerKmRate: .91,
    centsPerKmMaxKm: 5000,
    carDepreciationLimit: 69674);
final now = DateTime(2026, 11, 11);
Vehicle vehicle({TaxMethod method = TaxMethod.logbook, DateTime? start}) =>
    Vehicle(
        id: 'home-car',
        make: 'Toyota',
        model: 'Corolla',
        initialOdometer: 42000,
        taxMethod: method,
        logbookStartDate: start);
Trip trip(String id, double km,
        {TripClassification classification = TripClassification.business}) =>
    Trip(
        id: id,
        vehicleId: 'home-car',
        date: now,
        purpose: 'Install kitchen at client site',
        distanceKm: km,
        startOdometer: 42000,
        endOdometer: 42000 + km,
        classification: classification);
VehicleExpense expense(String id, double amount) => VehicleExpense(
    id: id,
    vehicleId: 'home-car',
    date: now,
    category: ExpenseCategory.fuel,
    amount: amount,
    receiptPath: '/receipt.jpg',
    receiptAudit: ReceiptAuditTrail(
        reviewStatus: ReceiptReviewStatus.confirmed,
        capturedAt: now,
        reviewedAt: now));

HomeRecordSummary summary(
        {TaxMethod method = TaxMethod.logbook,
        DateTime? start,
        List<Trip> trips = const [],
        List<VehicleExpense> expenses = const [],
        List<EvidenceReviewItem> items = const []}) =>
    HomeRecordSummary.fromReport(
        EvidenceReviewReport(
            vehicle: vehicle(method: method, start: start),
            financialYear: '2026-27',
            trips: trips,
            expenses: expenses,
            items: items),
        taxRule: rule,
        now: now);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle
              .load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });

  test('CPK estimate excludes unresolved trips and respects financial-year cap',
      () {
    final data = summary(method: TaxMethod.centsPerKm, trips: [
      trip('checked', 6000),
      trip('pending', 200, classification: TripClassification.unclassified)
    ], expenses: [
      expense('fuel', 1000)
    ], items: [
      const TripReviewItem(
          tripId: 'pending', reasons: [TripReviewReason.classification])
    ]);
    expect(data.reviewed.businessKm, 6000);
    expect(data.deduction, 4550);
    expect(data.reviewedTripCount, 1);
  });

  test('logbook excludes unresolved details but distinguishes file inspection',
      () {
    final data = summary(start: DateTime(2026, 10, 20), trips: [
      trip('work', 75),
      trip('personal', 25, classification: TripClassification.personal)
    ], expenses: [
      expense('checked', 200),
      expense('pending', 800)
    ], items: [
      const ExpenseReviewItem(
          expenseId: 'checked', reasons: [ExpenseReviewReason.uncheckedPhoto]),
      const ExpenseReviewItem(
          expenseId: 'pending',
          reasons: [ExpenseReviewReason.unconfirmedDetails]),
    ]);
    expect(data.reviewed.businessPercentage, 75);
    expect(data.deduction, 150);
    expect(data.reviewedExpenseCount, 1);
    expect(
        data.pendingItems
            .whereType<ExpenseReviewItem>()
            .map((item) => item.expenseId),
        ['pending']);
    expect(data.elapsedDays, 23);
  });

  test('missing logbook setup or costs does not present a claim', () {
    expect(
        summary(trips: [trip('work', 50)], expenses: [expense('fuel', 100)])
            .deduction,
        isNull);
    expect(summary(start: now, trips: [trip('work', 50)]).deduction, isNull);
    expect(summary(start: DateTime(2027)).elapsedDays, 0);
    expect(summary(start: DateTime(2025)).elapsedDays, 84);
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['DRIVELOG_CAPTURE'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.audit/home-v2/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> pumpHome(WidgetTester tester, AppState state, GlobalKey key,
      {double scale = 1, double width = 390}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                    fontFamily: 'Inter',
                    colorScheme: AppColor.scheme,
                    textTheme: AppType.textTheme,
                    scaffoldBackgroundColor: AppColor.canvas,
                    useMaterial3: true),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: Builder(
                    builder: (context) => Scaffold(
                        bottomNavigationBar: ScaffoldBottomNavBar(
                          currentIndex: 0,
                          taxMethod: state.primaryVehicle!.taxMethod,
                          onTabSelected: (_) {},
                          onCenterActionTap: () =>
                              QuickCaptureBottomSheet.show(context, state),
                        ),
                        body: SafeArea(
                            child: TaskHomeBody(appState: state))))))));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }

  testWidgets('first day offers real capture and does not invent a balance',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(vehicle(start: DateTime.now()));
    final key = GlobalKey();
    await pumpHome(tester, state, key);
    expect(find.text('Your driving.'), findsOneWidget);
    expect(find.text('Every trip.\nEvery receipt.\nOne clear record.'),
        findsOneWidget);
    expect(find.text('Estimated deduction'), findsNothing);
    expect(find.text('Add your first trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'first-day');
    await tester.tap(find.text('Add your first trip'));
    await tester.pumpAndSettle();
    expect(find.text('Add a past trip'), findsOneWidget);
  });

  testWidgets(
      'recorded Home shows true ledger source and explains estimate basis',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(
        vehicle(start: DateTime.now().subtract(const Duration(days: 22))));
    state.recordTrip(trip('recorded', 50).copyWith(date: DateTime.now()));
    state.recordExpense(
        expense('checked-fuel', 200).copyWith(date: DateTime.now()));
    final key = GlobalKey();
    await pumpHome(tester, state, key);
    expect(find.byType(HomeRecordHero), findsOneWidget);
    expect(find.text(r'$200.00'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('Trip ledger odometer'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Trip ledger odometer'), findsOneWidget);
    expect(find.textContaining('Last odometer photo'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'daily-home');
    await tester.scrollUntilVisible(find.text('View basis ↗'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View basis ↗'));
    await tester.pumpAndSettle();
    expect(find.text('Your estimate basis'), findsOneWidget);
    expect(
        find.textContaining('Receipt file availability is checked separately'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CPK welcome focuses on trip evidence instead of receipt capture',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(vehicle(method: TaxMethod.centsPerKm));
    await pumpHome(tester, state, GlobalKey());
    expect(find.text('Every trip.\nEvery purpose.\nOne clear record.'),
        findsOneWidget);
    expect(find.textContaining('Scan receipts'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home remains scrollable at 320 width and double text',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(vehicle(start: DateTime.now()));
    state.recordTrip(trip('recorded', 50).copyWith(date: DateTime.now()));
    final key = GlobalKey();
    await pumpHome(tester, state, key, width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
