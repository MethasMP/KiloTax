import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<AppState> setup(WidgetTester tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'a',
        make: 'Toyota',
        model: 'HiAce',
        initialOdometer: 1000,
        taxMethod: TaxMethod.centsPerKm));
    await state.addVehicle(Vehicle(
        id: 'b',
        make: 'Ford',
        model: 'Ranger',
        isPrimary: false,
        initialOdometer: 1000,
        taxMethod: TaxMethod.centsPerKm));
    final current =
        int.parse(state.activeTaxRule.financialYear.substring(0, 4));
    for (final entry in [
      (id: 'a-current', car: 'a', year: current, km: 10.0),
      (id: 'b-current', car: 'b', year: current, km: 30.0),
      (id: 'b-prior', car: 'b', year: current - 1, km: 20.0)
    ]) {
      state.recordTrip(Trip(
          id: entry.id,
          vehicleId: entry.car,
          date: DateTime(entry.year, 8, 1),
          distanceKm: entry.km,
          startOdometer: 1000,
          endOdometer: 1000 + entry.km,
          purpose: 'Deliver building materials',
          classification: TripClassification.business));
    }
    state.recordExpense(VehicleExpense(
        id: 'expense-only',
        vehicleId: 'b',
        date: DateTime(2024, 8, 1),
        amount: 20,
        category: ExpenseCategory.tollsParking));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
            theme: AppTheme.light,
            home: TaxSummaryScreen(onSend: (_, __) async {}))));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> chooseVehicle(WidgetTester tester) async {
    final picker = find.byKey(const ValueKey('export-vehicle-a'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ford Ranger').last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseYear(
      WidgetTester tester, String current, String next) async {
    final picker = find.byKey(ValueKey('export-year-$current'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FY $next').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Pack retargets only on explicit scope request', (tester) async {
    final state = await setup(tester);
    final active = state.activeTaxRule.financialYear;
    await chooseVehicle(tester);
    await chooseYear(tester, active, '2025-26');
    Future<void> rebuild(int request) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
              theme: AppTheme.light,
              home: TaxSummaryScreen(
                  initialVehicleId: 'a',
                  initialFinancialYear: active,
                  scopeRequest: request,
                  onSend: (_, __) async {}))));
      await tester.pumpAndSettle();
    }

    await rebuild(0);
    expect(find.byKey(const ValueKey('export-vehicle-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-year-2025-26')), findsOneWidget);
    await rebuild(1);
    expect(find.byKey(const ValueKey('export-vehicle-a')), findsOneWidget);
    expect(find.byKey(ValueKey('export-year-$active')), findsOneWidget);
  });

  testWidgets('Pack temporary Review returns to existing vehicle and year',
      (tester) async {
    final state = await setup(tester);
    final active = state.activeTaxRule.financialYear;
    await chooseVehicle(tester);
    await chooseYear(tester, active, '2025-26');
    await tester.ensureVisible(find.text('Review records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review records'));
    await tester.pumpAndSettle();
    final review =
        tester.widget<EvidenceReviewScreen>(find.byType(EvidenceReviewScreen));
    expect(review.vehicleId, 'b');
    expect(review.financialYear, '2025-26');
    await tester.ensureVisible(find.text('Open accountant pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open accountant pack'));
    await tester.pumpAndSettle();
    expect(find.byType(EvidenceReviewScreen), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('export-vehicle-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-year-2025-26')), findsOneWidget);
    expect(state.primaryVehicle!.id, 'a');
    expect(state.activeTaxRule.financialYear, active);
  });

  testWidgets(
      'Report vehicle/year change leaves primary scope intact and uses historical rate',
      (tester) async {
    final state = await setup(tester);
    final active = state.activeTaxRule.financialYear;
    await chooseVehicle(tester);
    await chooseYear(tester, active, '2025-26');
    expect(state.primaryVehicle!.id, 'a');
    expect(state.activeTaxRule.financialYear, active);
    final estimate = find.text('Estimated deduction');
    await tester.scrollUntilVisible(estimate, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(estimate);
    await tester.pumpAndSettle();
    expect(find.text(r'$17.60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Expense-only scope can prepare while empty year stays disabled and opens matching ledger',
      (tester) async {
    final state = await setup(tester);
    await chooseVehicle(tester);
    await chooseYear(tester, state.activeTaxRule.financialYear, '2024-25');
    final action = find.byKey(const ValueKey('tax-primary-action'));
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    await chooseYear(tester, '2024-25', '2023-24');
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(find.text('Add your first trip'), findsNothing);
    await tester.ensureVisible(find.text('View records'));
    await tester.tap(find.text('View records'));
    await tester.pumpAndSettle();
    final ledger = tester.widget<TripsLedgerTab>(find.byType(TripsLedgerTab));
    expect(ledger.initialVehicleId, 'b');
    expect(ledger.financialYear, '2023-24');
    expect(state.primaryVehicle!.id, 'a');
    expect(tester.takeException(), isNull);
  });
}
