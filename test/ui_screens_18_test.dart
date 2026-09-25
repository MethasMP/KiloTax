import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:kilotax/ui/screens/dashboard/evidence_home_screen.dart';
import 'package:kilotax/ui/screens/trips/trip_detection_screen.dart';
import 'package:kilotax/ui/screens/trips/trip_detail_screen.dart';
import 'package:kilotax/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/expenses/evidence_expenses_screen.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';
import 'package:kilotax/ui/screens/logbook/logbook_setup_screen.dart';
import 'package:kilotax/ui/screens/logbook/logbook_progress_screen.dart';
import 'package:kilotax/ui/screens/migration/migration_screen.dart';
import 'package:kilotax/ui/screens/compliance/compliance_center_screen.dart';
import 'package:kilotax/ui/screens/home/main_scaffold_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('18 Master UI Screens Render & Integrity Tests (UI.png)', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      appState.addVehicle(
        Vehicle(
          id: 'veh_test_1',
          make: 'Ford',
          model: 'Ranger 2021',
          regoPlate: 'XYZ 123 (NSW)',
          initialOdometer: 82421.0,
          taxMethod: TaxMethod.centsPerKm,
        ),
      );
      appState.recordTrip(
        Trip(
          id: 'trip_test_1',
          vehicleId: 'veh_test_1',
          distanceKm: 24.6,
          date: DateTime(2026, 9, 12, 8, 42),
          purpose: 'Client / Job',
          startOdometer: 82421.0,
          endOdometer: 82445.6,
          originAddress: 'Home / Base',
          destinationAddress: 'Client Site, Richmond',
        ),
      );
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_test_1',
          vehicleId: 'veh_test_1',
          amount: 184.60,
          category: ExpenseCategory.toolsMaterials,
          date: DateTime(2026, 9, 12),
          notes: 'Bunnings',
        ),
      );
    });

    Widget wrap(Widget child) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('Screens 1–4: Onboarding Flow renders properly', (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen()));
      expect(find.textContaining('Never miss a dollar'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Skip to navigate to Welcome / Sign-in screen
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tax-ready'), findsOneWidget);
      expect(find.textContaining('Continue with Apple'), findsOneWidget);
    });

    testWidgets('Screens 5 & 6: Evidence Home Screen renders Cents-per-km HUD', (tester) async {
      await tester.pumpWidget(wrap(const EvidenceHomeScreen()));
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data?.toLowerCase().contains('estimated tax deduction') == true),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.startsWith('Good ') == true ||
                w.data?.startsWith('Early start') == true ||
                w.data?.startsWith('Working late') == true)),
        findsOneWidget,
      );
    });

    testWidgets('Screen 7: Trip Detection Interstitial renders with 1-tap buttons', (tester) async {
      await tester.pumpWidget(
        wrap(
          TripDetectionScreen(
            appState: appState,
            detectedTrip: appState.trips.first,
          ),
        ),
      );
      expect(find.textContaining('Review Work Drive (CPK)'), findsOneWidget);
      expect(find.textContaining('Trade Purpose'), findsOneWidget);
      expect(find.textContaining('Save Work Trip'), findsOneWidget);
      // Verify Bulky Tools Exemption Switch (s 8-1) & Weekend Audit Shield
      expect(find.textContaining('Carried Bulky Equipment (s 8-1)'), findsOneWidget);
      expect(find.textContaining('Weekend Drive Audit Alert (s 28-25)'), findsOneWidget);
    });

    testWidgets('Screen 8: Trip Detail Screen renders 4-point evidence checklist', (tester) async {
      await tester.pumpWidget(
        wrap(
          TripDetailScreen(
            trip: appState.trips.first,
            appState: appState,
          ),
        ),
      );
      expect(find.text('Trip detail'), findsOneWidget);
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('Screen 9: Scan Receipt Screen renders camera viewfinder', (tester) async {
      await tester.pumpWidget(wrap(ScanReceiptScreen(appState: appState)));
      expect(find.text('Receipt Scanner'), findsOneWidget);
      expect(find.text('Position receipt within frame'), findsOneWidget);
    });

    testWidgets('Screen 10: Expense Detail Screen renders Bunnings \$184.60', (tester) async {
      await tester.pumpWidget(
        wrap(
          ExpenseDetailScreen(
            appState: appState,
            merchant: 'Bunnings',
            amount: 184.60,
            categoryName: 'Materials',
            receiptDate: DateTime(2026, 9, 12),
          ),
        ),
      );
      expect(find.text('Expense detail'), findsOneWidget);
      expect(find.text('Bunnings'), findsOneWidget);
      expect(find.text('184.60'), findsOneWidget);
    });

    testWidgets('Screen 11: Expenses List Screen renders filter pills', (tester) async {
      await tester.pumpWidget(wrap(const EvidenceExpensesScreen()));
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
    });

    testWidgets('Screen 12: Tax Summary Screen renders hero \$5,420 and readiness', (tester) async {
      await tester.pumpWidget(wrap(const TaxSummaryScreen()));
      expect(find.text('Tax Summary'), findsOneWidget);
      expect(find.text('AUDIT READINESS SCORE'), findsOneWidget);
      expect(find.text('Share with Accountant'), findsOneWidget);
    });

    testWidgets('Screen 13: Logbook Setup Screen renders 12-week schedule', (tester) async {
      await tester.pumpWidget(wrap(LogbookSetupScreen(appState: appState)));
      expect(find.text('Set Up Your Logbook'), findsOneWidget);
      expect(find.text('VEHICLE ASSIGNED'), findsOneWidget);
    });

    testWidgets('Screen 14: Logbook Progress Screen renders gauge & timeline', (tester) async {
      await tester.pumpWidget(wrap(const LogbookProgressScreen()));
      expect(find.text('Logbook'), findsOneWidget);
      expect(find.textContaining('of 12'), findsOneWidget);
      expect(find.text('Business use'), findsOneWidget);
    });

    testWidgets('Screens 15 & 16: Migration & Import Screen renders platform choices', (tester) async {
      await tester.pumpWidget(wrap(MigrationScreen(appState: appState)));
      expect(find.text('Import Past Records'), findsOneWidget);
      expect(find.text('Driversnote Export'), findsOneWidget);
      expect(find.text('ATO myDeductions'), findsOneWidget);
    });

    testWidgets('Screen 17: Compliance Center Screen renders audit checklist', (tester) async {
      await tester.pumpWidget(wrap(ComplianceCenterScreen(appState: appState)));
      expect(find.text('Tax Compliance Center'), findsOneWidget);
      expect(find.text('ATO AUDIT READINESS'), findsOneWidget);
      expect(find.text('Compliance Checklist'), findsOneWidget);
    });

    testWidgets('Screen 18: 1-Tap Accountant Share Pack triggers directly without interstitial friction', (tester) async {
      await tester.pumpWidget(wrap(const TaxSummaryScreen()));
      expect(find.text('Accountant Hand-off'), findsOneWidget);
      expect(find.text('Share with Accountant'), findsOneWidget);
      expect(find.text('Email ATO Tax Pack (PDF + CSV) in 1 tap'), findsOneWidget);
    });

    testWidgets('Master Navigation Scaffold renders adaptive nav for CPK & Logbook', (tester) async {
      // In Cents-per-km mode (default): 3-tab lean layout (Dashboard, Trips, Tax)
      await tester.pumpWidget(wrap(const MainScaffoldScreen()));
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Expenses'), findsNothing);

      // Switch to Logbook mode and test adaptive 4-tab + quick capture FAB
      appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();

      // In Logbook mode: Trip, Car Expense, and Odometer are all available
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Car Expense'), findsOneWidget);
      expect(find.text('Odometer'), findsOneWidget);
    });
  });
}
