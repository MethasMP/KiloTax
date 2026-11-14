import 'package:kilotax/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/trips/trip_detail_screen.dart';
import 'package:kilotax/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/account_settings_sheet.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/core/theme/app_theme.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/home/main_scaffold_screen.dart';
import 'package:kilotax/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:kilotax/ui/screens/auth/sign_in_screen.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';
import 'package:kilotax/ui/screens/expenses/evidence_expenses_screen.dart';
import 'package:kilotax/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kilotax/ui/screens/logbook/logbook_trip_entry_screen.dart';
import 'package:kilotax/ui/screens/tracking/tracking_setup_screen.dart';

Future<AppState> stateFor(TaxMethod method, {bool records = true}) async {
  final s = AppState();
  s.addVehicle(
    Vehicle(
      id: 'veh_cpk',
      make: 'Ford',
      model: 'Ranger 2024',
      regoPlate: '1GTF892',
      initialOdometer: 42150.0,
      vehicleType: VehicleType.ute,
      taxMethod: method,
    ),
  );
  if (!records) return s;
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

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    for (final e in {
      'Inter': 'assets/fonts/Inter-Regular.ttf',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      'packages/lucide_icons_flutter/Lucide':
          '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets/lucide.ttf'
    }.entries) {
      final loader = FontLoader(e.key)
        ..addFont(File(e.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'Journey layout at ${scale == 1 ? 390 : 320}pt / ${scale * 100}% text',
        (t) async {
      t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final cpk = await stateFor(TaxMethod.centsPerKm);
      final logbook = await stateFor(TaxMethod.logbook);
      final empty = await stateFor(TaxMethod.centsPerKm, records: false);
      final screens = <String, (AppState, Widget)>{
        '01_welcome': (empty, OnboardingSlidesScreen(onComplete: () {})),
        '02_vehicle': (empty, VehicleSetupFlow(onVehicleCreated: (_) {})),
        '02_vehicle_details': (
          empty,
          VehicleSetupFlow(
              initialStage: VehicleSetupStage.confirmVehicle,
              includeBluetoothSetup: false,
              onVehicleCreated: (_) {})
        ),
        '03_method': (
          empty,
          VehicleSetupFlow(
              initialStage: VehicleSetupStage.taxMethod,
              includeBluetoothSetup: false,
              onVehicleCreated: (_) {})
        ),
        '04_sign_in': (empty, const SignInScreen()),
        '05_home_cpk': (cpk, const MainScaffoldScreen()),
        '06_home_empty': (empty, const MainScaffoldScreen()),
        '07_home_logbook': (logbook, const MainScaffoldScreen()),
        '08_trips': (cpk, TripsLedgerTab(appState: cpk)),
        '09_tax': (cpk, const TaxSummaryScreen()),
        '10_expenses': (logbook, const EvidenceExpensesScreen()),
        '11_add_cpk_trip': (cpk, CpkTripEntryScreen(appState: cpk)),
        '12_add_logbook_trip': (
          logbook,
          LogbookTripEntryScreen(appState: logbook)
        ),
        '13_tracking': (cpk, const TrackingSetupScreen()),
        '14_trip_detail': (
          cpk,
          TripDetailScreen(trip: cpk.trips.first, appState: cpk)
        ),
        '15_receipt_capture': (logbook, ScanReceiptScreen(appState: logbook)),
        '16_expense_entry': (
          logbook,
          ExpenseDetailScreen(appState: logbook, receiptDate: DateTime.now())
        ),
        '17_record_review': (
          cpk,
          EvidenceReviewScreen(
              appState: cpk,
              vehicleId: cpk.primaryVehicle?.id,
              financialYear: cpk.activeTaxRule.financialYear)
        ),
      };
      for (final e in screens.entries) {
        await t.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: e.value.$1,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true),
                  child: child!),
              home: RepaintBoundary(key: ValueKey(e.key), child: e.value.$2),
            )));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: e.key);
        await expectLater(
            find.byKey(ValueKey(e.key)),
            matchesGoldenFile(
                'user_centric/after/${e.key}_${scale == 1 ? 'standard' : 'large'}.png'));
        if (e.key == '05_home_cpk') {
          final context = t.element(find.byType(MainScaffoldScreen));
          AccountSettingsSheet.show(context, e.value.$1);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'Settings / $scale');
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'user_centric/after/18_settings_${scale == 1 ? 'standard' : 'large'}.png'));
          Navigator.of(context).pop();
          await t.pumpAndSettle();
        }

        if (e.key == '10_expenses') {
          final context = t.element(find.byType(EvidenceExpensesScreen));
          await t.tap(find.byTooltip('Filter & Sort'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'Expense filters / $scale');
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'user_centric/after/19_expense_filters_${scale == 1 ? 'standard' : 'large'}.png'));
          Navigator.of(context).pop();
          await t.pumpAndSettle();
          await t.tap(find.text('Add Expense'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: 'Expense capture choices / $scale');
          Navigator.of(context).pop();
          await t.pumpAndSettle();
        }
        if (e.key == '05_home_cpk') {
          final context = t.element(find.byType(MainScaffoldScreen));
          await t.tap(find.text('Add trip'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: 'Trip capture choices / $scale');
          Navigator.of(context).pop();
          await t.pumpAndSettle();
        }
        if (e.key == '09_tax') {
          await t.scrollUntilVisible(
              find.text('Record checklist').hitTestable(), 200,
              scrollable: find.byType(Scrollable).first);
          await t.tap(find.text('Record checklist'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: 'Expanded tax checklist / $scale');
        }
        if (e.key == '02_vehicle_details') {
          await t.tap(find.text('Registration & odometer (optional)'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: 'Optional vehicle details / $scale');
        }
      }
    });
  }
}
