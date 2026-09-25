import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/compliance/compliance_center_screen.dart';
import 'package:kilotax/ui/screens/cpk/cpk_trip_entry_screen.dart';
import 'package:kilotax/ui/screens/home/widgets/quick_capture_bottom_sheet.dart';
import 'package:kilotax/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kilotax/ui/screens/logbook/logbook_trip_entry_screen.dart';
import 'package:kilotax/ui/screens/tax/tax_summary_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CPK UX & Readiness Compliance Tests', () {
    late AppState appState;

    setUp(() async {
      appState = AppState();
      await appState.addVehicle(
        Vehicle(
          id: 'cpk-veh-1',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'CPK-999',
          initialOdometer: 0.0,
          taxMethod: TaxMethod.centsPerKm,
          isPrimary: true,
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

    testWidgets('QuickCapture opens CpkTripEntryScreen for CPK vehicles on manual log', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => QuickCaptureBottomSheet.show(context, appState),
            child: const Text('Open Quick Capture'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Quick Capture'));
      await tester.pumpAndSettle();

      // Tap on 'Trip' option
      expect(find.text('Trip'), findsOneWidget);
      await tester.tap(find.text('Trip'));
      await tester.pumpAndSettle();

      // Tap 'Log Trip Manually'
      expect(find.text('Log Trip Manually'), findsOneWidget);
      await tester.tap(find.text('Log Trip Manually'));
      await tester.pumpAndSettle();

      // Should open CpkTripEntryScreen (has ATO 5,000 km cap meter & no odometer inputs)
      expect(find.byType(CpkTripEntryScreen), findsOneWidget);
      expect(find.byType(LogbookTripEntryScreen), findsNothing);
      expect(find.textContaining('Review Work Drive (CPK)'), findsOneWidget);
    });

    testWidgets('QuickCapture opens LogbookTripEntryScreen for Logbook vehicles on manual log', (tester) async {
      appState.updatePrimaryVehicleTaxMethod(TaxMethod.logbook);

      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => QuickCaptureBottomSheet.show(context, appState),
            child: const Text('Open Quick Capture'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Quick Capture'));
      await tester.pumpAndSettle();

      // Tap on 'Trip' option
      expect(find.text('Trip'), findsOneWidget);
      await tester.tap(find.text('Trip'));
      await tester.pumpAndSettle();

      // Tap 'Log Trip Manually'
      expect(find.text('Log Trip Manually'), findsOneWidget);
      await tester.tap(find.text('Log Trip Manually'));
      await tester.pumpAndSettle();

      // Should open LogbookTripEntryScreen
      expect(find.byType(LogbookTripEntryScreen), findsOneWidget);
      expect(find.byType(CpkTripEntryScreen), findsNothing);
      expect(find.textContaining('Log Logbook Drive'), findsOneWidget);
    });

    testWidgets('TripsLedgerTab renders exactly 1 clear CTA in Empty State and routes to CPK', (tester) async {
      await tester.pumpWidget(wrap(TripsLedgerTab(appState: appState)));

      // In empty state: Clean view with elevated FloatingActionButton
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap FAB to ensure it routes directly to CpkTripEntryScreen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(CpkTripEntryScreen), findsOneWidget);
    });

    testWidgets('TaxSummaryScreen displays CPK checklist items without penalising for no odometer', (tester) async {
      await tester.pumpWidget(wrap(const TaxSummaryScreen()));

      // Should display CPK specific items
      expect(find.text('Reasonable estimate basis established'), findsOneWidget);
      expect(find.text('Business trips substantiated'), findsOneWidget);
      expect(find.text('Odometer recorded'), findsNothing);

      // Verify ZERO duplicate 'Log Drive →' labels
      expect(find.text('Log Drive →'), findsOneWidget);
      expect(find.text('Awaiting Drives'), findsOneWidget);

      // Readiness score should be exactly 50% (NASA Deterministic: 2 of 4 pillars complete - Vehicle 25% + Tax Method 25%)
      expect(appState.taxReadinessScore, 50);
    });

    testWidgets('ComplianceCenterScreen displays 50% Tax-Ready in setup phase with consistent status chips', (tester) async {
      await tester.pumpWidget(wrap(ComplianceCenterScreen(appState: appState)));

      expect(find.text('50% Tax-Ready'), findsOneWidget);
      expect(find.text('Awaiting Drives'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Statutory Rate'), findsOneWidget);
    });
  });
}


