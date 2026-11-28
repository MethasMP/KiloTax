import 'dart:io';
import 'dart:ui' as ui;
// Executable contracts for the menu remediation.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kiloclaim/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kiloclaim/ui/screens/tax/pre_flight_review_screen.dart';
import 'package:kiloclaim/services/scanner/document_scanner_service.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_setup_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kiloclaim/ui/screens/expenses/evidence_expenses_screen.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/widgets/tactile_primary_button.dart';
import 'package:kiloclaim/ui/screens/logbook/widgets/logbook_design.dart';
import '../tool/design_audit/menu_audit_test.dart' as fixtures;

class AuditScanner extends DocumentScannerService {
  int calls = 0;
  @override
  Future<List<String>> scanBatchDocuments(
      {int maxPages = 20, bool allowFallbackToCamera = true}) async {
    calls++;
    return [];
  }
}

Widget wrap(AppState s, Widget child) => ChangeNotifierProvider<AppState>.value(
    value: s,
    child: MaterialApp(
        theme: ThemeData(fontFamily: 'Inter', colorScheme: AppColor.scheme),
        home: child));

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    await font.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('UX-01 Needs review includes business-purpose placeholders',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.centsPerKm, empty: true);
    addTearDown(s.dispose);
    s.recordTrip(Trip(
        id: 'placeholder',
        vehicleId: 'audit',
        date: DateTime.now(),
        distanceKm: 10,
        classification: TripClassification.business,
        purpose: 'Business'));
    expect(s.missingComplianceTrips.length, 1,
        reason: 'Canonical evidence queue flags this record');
    await tester.pumpWidget(wrap(s, TripsLedgerTab(appState: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs review'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget,
        reason: 'The same record must remain visible in the review filter');
  });

  testWidgets('UX-02 View recorded drives must not open a blank add-trip form',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(s.dispose);
    await tester.pumpWidget(wrap(s, const TaxSummaryScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record checklist'));
    await tester.tap(find.text('Record checklist'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View').first);
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.byType(TripsLedgerTab), findsOneWidget);
    expect(find.byType(CpkTripEntryScreen), findsNothing,
        reason: 'View promises existing records, not creation');
  });

  testWidgets(
      'UX-03 vehicle switch must not silently reinterpret Expenses as Tax',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await fixtures.seed(TaxMethod.logbook);
    addTearDown(s.dispose);
    await s.addVehicle(Vehicle(
        id: 'cpk',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'OTHER',
        initialOdometer: 100,
        taxMethod: TaxMethod.centsPerKm,
        isPrimary: false));
    s.selectVehicle('audit');
    await tester.pumpWidget(wrap(s, const MainScaffoldScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses').hitTestable().last);
    await tester.pumpAndSettle();
    expect(find.byType(EvidenceExpensesScreen).hitTestable(), findsOneWidget);
    s.selectVehicle('cpk');
    await tester.pumpAndSettle();
    expect(find.text('Tax Summary').hitTestable(), findsNothing,
        reason: 'Restore a meaningful destination instead of reusing index 2');
  });

  testWidgets('UX-04 primary capture button exposes a button role',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TactilePrimaryButton(
                label: 'Save evidence', onPressed: () {}))));
    final semantics = tester.getSemantics(find.text('Save evidence'));
    expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
        semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    handle.dispose();
  });
  testWidgets(
      'UX-05 logbook footer label must retain AA contrast after palette changes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar:
                LogbookFooter(label: 'Save trip', onPressed: () {}))));
    final text = tester.widget<Text>(find.text('Save trip'));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final a = text.style!.color!.computeLuminance();
    final b = button.style!.backgroundColor!.resolve({})!.computeLuminance();
    final ratio = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
    expect(ratio, greaterThanOrEqualTo(4.5),
        reason:
            'Normal 17px text must remain readable on the new terracotta background');
  });
  testWidgets(
      'pending evidence never becomes a green percentage-ready headline',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(s.dispose);
    await tester.pumpWidget(wrap(s, const TaxSummaryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('3 items need attention'), findsOneWidget);
    expect(find.text('Details up to date'), findsNothing);
    expect(find.text('92%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'an entered amount does not assert receipt readiness or invent payment method',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.logbook);
    addTearDown(s.dispose);
    final expense = s.expenses.first;
    await tester.pumpWidget(wrap(
        s,
        ExpenseDetailScreen(
            appState: s,
            receiptDate: expense.date,
            existingExpense: expense,
            amount: expense.amount,
            merchant: 'Wilson Parking')));
    await tester.pumpAndSettle();
    expect(find.text('Ready for tax'), findsNothing);
    expect(find.text('Amount entered'), findsOneWidget);
    expect(find.text('Business Account'), findsNothing);
    expect(find.text('Not specified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense ledger uses the active vehicle and financial year',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.logbook);
    addTearDown(s.dispose);
    s.recordExpense(VehicleExpense(
        id: 'other',
        vehicleId: 'other-vehicle',
        date: DateTime.now(),
        amount: 999,
        category: ExpenseCategory.fuel,
        notes: 'Other vehicle expense'));
    s.recordExpense(VehicleExpense(
        id: 'old',
        vehicleId: 'audit',
        date: DateTime(2020, 8, 3),
        amount: 888,
        category: ExpenseCategory.fuel,
        notes: 'Old year expense'));
    await tester.pumpWidget(wrap(s, const EvidenceExpensesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Wilson Parking'), findsOneWidget);
    expect(find.text('Other vehicle expense'), findsNothing);
    expect(find.text('Old year expense'), findsNothing);
    expect(find.text('Recorded expenses in this filter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preflight calls incomplete records a draft', (tester) async {
    final s = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(s.dispose);
    final dir = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('kiloclaim-ui-package-');
      await File('${dir.path}/fixture-Tax_Report.pdf')
          .writeAsString('visual fixture');
      await File('${dir.path}/fixture-Trip_Ledger.csv')
          .writeAsString('Date,Distance');
      return dir;
    });
    addTearDown(() => dir!.delete(recursive: true));
    await tester.pumpWidget(wrap(
        s,
        PreFlightReviewScreen(
            appState: s,
            initialPackage: fixtures.package(s, directory: dir!.path))));
    await tester.pumpAndSettle();
    expect(find.text('Share draft for review'), findsOneWidget);
    expect(find.text('Send to Accountant'), findsNothing);
  });

  testWidgets(
      'scanner opens native capture explicitly and has no cosmetic flash control',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.logbook);
    addTearDown(s.dispose);
    final scanner = AuditScanner();
    await tester.pumpWidget(
        wrap(s, ScanReceiptScreen(appState: s, documentScanner: scanner)));
    await tester.pumpAndSettle();
    expect(find.text('Position receipt within frame'), findsNothing);
    expect(find.bySemanticsLabel('Turn flash on'), findsNothing);
    await tester.tap(find.text('Open camera scanner'));
    await tester.pumpAndSettle();
    expect(scanner.calls, 1);
  });
  testWidgets(
      'add-trip control stays accessible above the floating navigation bar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(s.dispose);
    await tester.pumpWidget(wrap(s, const MainScaffoldScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips').hitTestable());
    await tester.pumpAndSettle();
    final add = find.byTooltip('Add trip').hitTestable();
    expect(add, findsOneWidget);
    expect(tester.getBottomRight(add).dy,
        lessThan(tester.getTopLeft(find.byType(ScaffoldBottomNavBar)).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('logbook back control stays legible on a light toolbar',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.logbook, empty: true);
    addTearDown(s.dispose);
    await tester.pumpWidget(wrap(
        s,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => LogbookSetupScreen(appState: s))),
                    child: const Text('Open logbook'))))));
    await tester.tap(find.text('Open logbook'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    final a = bar.foregroundColor!.computeLuminance();
    final b = bar.backgroundColor!.computeLuminance();
    expect(((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open logbook'), findsOneWidget);
  });
  testWidgets(
      'large logbook navigation keeps complete labels readable and destinations tappable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? selected;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Inter', colorScheme: AppColor.scheme),
      home: MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 844), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            bottomNavigationBar: ScaffoldBottomNavBar(
                currentIndex: 0,
                taxMethod: TaxMethod.logbook,
                onTabSelected: (index) => selected = index,
                onCenterActionTap: () {}),
          )),
    ));
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Trips', 'Expenses', 'Tax']) {
      final finder = find.text(label).hitTestable();
      expect(finder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length));
      expect(boxes, isNotEmpty, reason: label);
      for (final box in boxes) {
        expect(box.left, greaterThanOrEqualTo(-.01), reason: label);
        expect(box.right, lessThanOrEqualTo(paragraph.size.width + .01),
            reason: label);
        expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + .01),
            reason: label);
      }
      await tester.tap(finder);
      expect(selected, ['Home', 'Trips', 'Expenses', 'Tax'].indexOf(label));
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a standalone trip ledger refreshes review state after records change',
      (tester) async {
    final s = await fixtures.seed(TaxMethod.centsPerKm);
    addTearDown(s.dispose);
    await tester.pumpWidget(wrap(s, TripsLedgerTab(appState: s)));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    s.resolveTripPurpose('pending', 'Deliver materials to Smith renovation');
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsNothing);
    expect(find.text('Unclassified trip'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
