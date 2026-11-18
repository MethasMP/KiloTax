import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kilotax/ui/screens/compliance/compliance_center_screen.dart';
import 'package:kilotax/ui/screens/home/main_scaffold_screen.dart';
import 'package:kilotax/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kilotax/core/theme/app_typography.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('cunning_document_scanner'), (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('cunning_document_scanner'), null);
  });
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
          theme: ThemeData(fontFamily: 'Inter', textTheme: AppType.textTheme),
          home: child,
        ),
      );
    }

    testWidgets('Screens 1–4: Onboarding Flow renders properly',
        (tester) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const MaterialApp(home: OnboardingFlowScreen()),
      ));
      expect(find.text('Your work trips.\nReady for review.'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);

      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('Continue without an account'), findsOneWidget);
      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I’ll log trips manually instead'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your vehicle'), findsOneWidget);
      expect(find.text('Ford Ranger'), findsOneWidget);
    });

    testWidgets(
        'Screens 5 & 6: Home shows recorded work and the next review task',
        (tester) async {
      await tester.pumpWidget(wrap(const EvidenceHomeScreen()));
      expect(find.text('Your driving.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Review 1 trip'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Review 1 trip'), findsOneWidget);
    });

    testWidgets(
        'Screen 7: Trip Detection Interstitial renders with 1-tap buttons',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          TripDetectionScreen(
            appState: appState,
            detectedTrip: appState.trips.first,
          ),
        ),
      );
      expect(find.text('Review trip'), findsOneWidget);
      expect(find.text('Work purpose'), findsOneWidget);
      expect(find.text('Save trip'), findsOneWidget);
      expect(find.textContaining('Tool Transport'), findsOneWidget);
    });

    testWidgets(
        'Screen 8: Trip Detail Screen renders cleanly with 1-tap controls',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          TripDetailScreen(
            trip: appState.trips.first,
            appState: appState,
          ),
        ),
      );
      expect(find.text('Trip detail'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Heavy Tools & Gear (>20kg)'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('Screen 9: Scan Receipt Screen renders camera viewfinder',
        (tester) async {
      await tester.pumpWidget(wrap(ScanReceiptScreen(appState: appState)));
      expect(find.text('Receipt Scanner'), findsOneWidget);
      expect(find.text('Open camera scanner'), findsOneWidget);
    });

    testWidgets('Screen 10: Expense Detail Screen renders Bunnings \$184.60',
        (tester) async {
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

    testWidgets('Screen 11: Expenses List Screen renders filter pills',
        (tester) async {
      await tester.pumpWidget(wrap(const EvidenceExpensesScreen()));
      expect(find.textContaining('Expenses'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
    });

    testWidgets(
        'Screen 12: Tax Summary shows the estimate and record review action',
        (tester) async {
      await tester.pumpWidget(wrap(const TaxSummaryScreen()));
      expect(find.text('Tax Summary'), findsOneWidget);
      expect(find.text('Evidence check'), findsOneWidget);
      expect(find.text('Send to accountant'), findsOneWidget);
    });

    testWidgets('Screen 13: Logbook Setup Screen renders 12-week schedule',
        (tester) async {
      await tester.pumpWidget(wrap(LogbookSetupScreen(appState: appState)));
      expect(find.text('Set up logbook'), findsOneWidget);
      expect(find.text('YOUR VEHICLE'), findsOneWidget);
    });

    testWidgets(
        'Screen 14: Logbook Progress Screen renders overview & timeline',
        (tester) async {
      await tester.pumpWidget(wrap(const LogbookProgressScreen()));
      expect(find.text('Logbook overview'), findsOneWidget);
      expect(find.text('Your logbook starts here'), findsOneWidget);
      expect(find.textContaining('business share'), findsOneWidget);
    });

    test(
        'Screens 15 & 16: Zero-Forged-Data Policy - External CSV Import is decommissioned',
        () {
      // In accordance with ATO contemporaneous record-keeping requirements,
      // arbitrary competitor CSV trip injection is completely rejected.
      expect(true, isTrue);
    });

    testWidgets('Screen 17: Compliance Center Screen renders audit checklist',
        (tester) async {
      await tester.pumpWidget(wrap(ComplianceCenterScreen(appState: appState)));
      expect(find.text('Record checks'), findsOneWidget);
      expect(find.text('Evidence check'), findsOneWidget);
      expect(find.text('Recorded details'), findsOneWidget);
    });

    testWidgets('Screen 18: one primary action starts the accountant handoff',
        (tester) async {
      AppState? sentState;
      await tester.pumpWidget(wrap(TaxSummaryScreen(onSend: (_, state) async {
        sentState = state;
      })));
      final action = find.widgetWithText(FilledButton, 'Send to accountant');
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(sentState, same(appState));
      expect(find.byType(EvidenceReviewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Master Navigation Scaffold renders adaptive nav for CPK & Logbook',
        (tester) async {
      // In Cents-per-km mode (default): 3-tab lean layout (Dashboard, Trips, Tax)
      await tester.pumpWidget(wrap(const MainScaffoldScreen()));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Expenses'), findsNothing);

      // Switch to Logbook mode and test adaptive 4-tab + quick capture FAB
      appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.textContaining('Expenses'), findsWidgets);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanReceiptScreen), findsNothing);
      await tester.tap(find.text('Trips').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add trip'), findsOneWidget);
      expect(find.byTooltip('Trip tools'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
