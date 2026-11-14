// DESIGN AUDIT CAPTURE HARNESS — not part of the product test suite.
//
// Renders real app screens off-device into PNGs so the visual design can be
// reviewed without a simulator.
//
// Run:  flutter test tool/design_audit/ui_capture_test.dart --update-goldens
// Out:  tool/design_audit/captures/*.png   (390x844 pt @ 3x = 1170x2532 px)
//
// This file writes images only. It changes no product code.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/auth/sign_in_screen.dart';
import 'package:kilotax/ui/screens/compliance/compliance_center_screen.dart';
import 'package:kilotax/ui/screens/dashboard/evidence_home_screen.dart';
import 'package:kilotax/ui/screens/expenses/evidence_expenses_screen.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/home/main_scaffold_screen.dart';
import 'package:kilotax/ui/screens/home/widgets/quick_capture_bottom_sheet.dart';
import 'package:kilotax/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kilotax/ui/screens/logbook/logbook_progress_screen.dart';
import 'package:kilotax/ui/screens/logbook/logbook_setup_screen.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';
import 'package:kilotax/ui/screens/trips/trip_detail_screen.dart';

const String _captureDir = 'tool/design_audit/captures';
const String _fontCache =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
const String _lucideCache =
    '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets';

// iPhone 14 logical size, rendered at 3x.
const Size _logicalSize = Size(390, 844);
const double _dpr = 3.0;

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async {
    final data = await File(path).readAsBytes();
    return ByteData.view(Uint8List.fromList(data).buffer);
  }

  Future<void> register(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(bytes(f));
    }
    await loader.load();
  }

  const sans = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ];

  // The app now bundles Inter (assets/fonts) — load the real thing so these
  // renders match what ships, including the 400/500/600/700/800/900 cuts.
  await register(
    'Inter',
    ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']
        .map((w) => 'assets/fonts/Inter-$w.ttf')
        .toList(),
  );
  await register('Roboto', sans.map((f) => '$_fontCache/$f').toList());
  await register('MaterialIcons', ['$_fontCache/MaterialIcons-Regular.otf']);
  await register(
      'packages/lucide_icons_flutter/Lucide', ['$_lucideCache/lucide.ttf']);
  await register('Lucide', ['$_lucideCache/lucide.ttf']);
}


AppState _seedCpk() {
  final s = AppState();
  s.addVehicle(
    Vehicle(
      id: 'veh_cpk',
      make: 'Ford',
      model: 'Ranger 2024',
      regoPlate: '1GTF892',
      initialOdometer: 42150.0,
      vehicleType: VehicleType.ute,
      taxMethod: TaxMethod.centsPerKm,
    ),
  );
  s.recordTrip(Trip(
    id: 't1',
    vehicleId: 'veh_cpk',
    distanceKm: 18.4,
    date: DateTime(2026, 9, 22, 7, 12),
    purpose: 'Collect timber & fixings',
    startOdometer: 42150.0,
    endOdometer: 42168.4,
    classification: TripClassification.business,
    originAddress: 'Bunnings Trade, Alexandria NSW',
    destinationAddress: 'Bondi Residential Reno, Bondi NSW',
  ));
  s.recordTrip(Trip(
    id: 't2',
    vehicleId: 'veh_cpk',
    distanceKm: 24.2,
    date: DateTime(2026, 9, 22, 14, 35),
    purpose: 'Site inspection',
    startOdometer: 42168.4,
    endOdometer: 42192.6,
    classification: TripClassification.business,
    originAddress: 'North Sydney Office Fitout',
    destinationAddress: 'Alexandria Depot',
  ));
  s.recordTrip(Trip(
    id: 't3',
    vehicleId: 'veh_cpk',
    distanceKm: 9.8,
    date: DateTime(2026, 9, 23, 6, 5),
    purpose: 'Unclassified drive',
    startOdometer: 42192.6,
    endOdometer: 42202.4,
    classification: TripClassification.unclassified,
    originAddress: 'Bondi NSW',
    destinationAddress: 'Bondi NSW',
  ));
  s.recordExpense(VehicleExpense(
    id: 'e1',
    vehicleId: 'veh_cpk',
    amount: 184.60,
    category: ExpenseCategory.toolsMaterials,
    date: DateTime(2026, 9, 12),
    notes: 'Bunnings',
  ));
  s.recordExpense(VehicleExpense(
    id: 'e2',
    vehicleId: 'veh_cpk',
    amount: 96.35,
    category: ExpenseCategory.fuel,
    date: DateTime(2026, 9, 10),
    notes: 'Caltex',
  ));
  return s;
}

AppState _empty() => AppState();

Widget _wrap(AppState state, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B132B),
          surface: const Color(0xFFF4F6FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

/// Swallow layout/assertion noise (genuine product bugs the harness surfaces —
/// logged separately) so the capture itself still gets written.
void _drain(WidgetTester tester) {
  var guard = 0;
  while (tester.takeException() != null && guard++ < 50) {}
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  AppState state,
  Widget screen,
) async {
  tester.view.physicalSize =
      Size(_logicalSize.width * _dpr, _logicalSize.height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(state, screen));
  await tester.pump(const Duration(milliseconds: 400));
  _drain(tester);

  Directory(_captureDir).createSync(recursive: true);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('captures/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  setUp(() {
    // flutter_test disables shadows by default; elevation is core to the look.
    debugDisableShadows = false;
  });

  testWidgets('01 onboarding slides', (t) async =>
      _capture(t, '01_onboarding_slides', _empty(), const OnboardingFlowScreen()));

  testWidgets('02 onboarding vehicle', (t) async => _capture(
      t, '02_onboarding_vehicle', _empty(),
      const OnboardingFlowScreen(initialStep: 1)));

  testWidgets('03 onboarding tax method', (t) async => _capture(
      t, '03_onboarding_tax_method', _empty(),
      const OnboardingFlowScreen(initialStep: 2)));

  testWidgets('04 sign in', (t) async =>
      _capture(t, '04_sign_in', _empty(), const SignInScreen()));

  testWidgets('05 home cpk', (t) async =>
      _capture(t, '05_home_cpk', _seedCpk(), const MainScaffoldScreen()));

  testWidgets('06 home empty state', (t) async =>
      _capture(t, '06_home_empty', _empty(), const MainScaffoldScreen()));

  testWidgets('07 trips ledger', (t) async {
    final s = _seedCpk();
    await _capture(t, '07_trips_ledger', s, TripsLedgerTab(appState: s));
  });

  testWidgets('08 trip detail', (t) async {
    final s = _seedCpk();
    await _capture(t, '08_trip_detail', s,
        TripDetailScreen(trip: s.trips.first, appState: s));
  });

  testWidgets('09 expenses list', (t) async => _capture(
      t, '09_expenses_list', _seedCpk(), const EvidenceExpensesScreen()));

  testWidgets('10 expense detail', (t) async {
    final s = _seedCpk();
    await _capture(
      t,
      '10_expense_detail',
      s,
      ExpenseDetailScreen(
        appState: s,
        merchant: 'Bunnings',
        amount: 184.60,
        categoryName: 'Materials',
        receiptDate: DateTime(2026, 9, 12),
      ),
    );
  });

  testWidgets('11 tax summary', (t) async =>
      _capture(t, '11_tax_summary', _seedCpk(), const TaxSummaryScreen()));

  testWidgets('12 logbook setup', (t) async {
    final s = _seedCpk();
    await _capture(t, '12_logbook_setup', s, LogbookSetupScreen(appState: s));
  });

  testWidgets('13 logbook progress', (t) async => _capture(
      t, '13_logbook_progress', _seedCpk(), const LogbookProgressScreen()));

  testWidgets('14 compliance center', (t) async {
    final s = _seedCpk();
    await _capture(t, '14_compliance', s, ComplianceCenterScreen(appState: s));
  });

  testWidgets('16 quick capture sheet', (t) async {
    final s = _seedCpk();
    t.view.physicalSize =
        Size(_logicalSize.width * _dpr, _logicalSize.height * _dpr);
    t.view.devicePixelRatio = _dpr;
    t.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    t.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(t.view.reset);

    await t.pumpWidget(_wrap(
      s,
      Builder(
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          body: Center(
            child: TextButton(
              onPressed: () => QuickCaptureBottomSheet.show(ctx, s),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    _drain(t);
    Directory(_captureDir).createSync(recursive: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/16_quick_capture_sheet.png'),
    );
  });

  testWidgets('17 evidence home body', (t) async => _capture(
      t, '17_evidence_home_body', _seedCpk(), const EvidenceHomeScreen()));
}
