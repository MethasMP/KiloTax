import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/evidence_home_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/cpk_batch_review_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prominent 1-Tap Batch Review (>5 Pending Trips)', () {
    late AppState appState;
    late Vehicle vehicle;

    setUp(() async {
      appState = AppState();
      vehicle = Vehicle(
        id: 'v_hilux',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TT222 (NSW)',
        initialOdometer: 15000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);
    });

    Widget wrap(Widget child) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    void addPendingTrips(int count) {
      for (int i = 1; i <= count; i++) {
        appState.recordTrip(
          Trip(
            id: 'pending_trip_$i',
            vehicleId: 'v_hilux',
            distanceKm: 12.0 + i,
            date: DateTime(2026, 11, 20).subtract(Duration(days: i)),
            purpose: '', // Empty purpose triggers TripReviewItem
            startOdometer: 15000.0 + (i * 20),
            endOdometer: 15012.0 + (i * 20) + i,
            classification: TripClassification.unclassified,
            originAddress: 'Job Site $i',
            destinationAddress: 'Supplier Depot $i',
            taxMethod: TaxMethod.centsPerKm,
          ),
        );
      }
    }

    testWidgets(
        'TripsLedgerTab shows standard review banner when pending trips <= 5',
        (tester) async {
      addPendingTrips(3);
      await tester.pumpWidget(wrap(TripsLedgerTab(appState: appState)));
      await tester.pumpAndSettle();

      expect(find.text('3 trips to review'), findsOneWidget);
      expect(find.text('Review next'), findsOneWidget);
      expect(find.byKey(const ValueKey('prominent-batch-review-card')),
          findsNothing);
      expect(find.byKey(const ValueKey('btn-1tap-batch-review')), findsNothing);
    });

    testWidgets(
        'TripsLedgerTab displays prominent 1-Tap Batch Review card when pending trips > 5',
        (tester) async {
      addPendingTrips(7);
      await tester.pumpWidget(wrap(TripsLedgerTab(appState: appState)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('prominent-batch-review-card')),
          findsOneWidget);
      expect(find.text('7 Trips Pending Review'), findsOneWidget);
      expect(find.text('Approve high-confidence work drives with 1 tap.'),
          findsOneWidget);

      final batchBtn = find.byKey(const ValueKey('btn-1tap-batch-review'));
      expect(batchBtn, findsOneWidget);
      expect(find.text('1-Tap Batch Review'), findsOneWidget);
      expect(find.text('One by one'), findsOneWidget);

      // Tap 1-Tap Batch Review and verify CpkBatchReviewSheet opens
      await tester.tap(batchBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CpkBatchReviewSheet), findsOneWidget);
      expect(find.text('Smart Trip Verification'), findsOneWidget);
    });

    testWidgets(
        'EvidenceHomeScreen shows unified Review records CTA when pending trips <= 5',
        (tester) async {
      addPendingTrips(3);
      await tester.pumpWidget(wrap(const EvidenceHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Review records'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-1tap-batch-review-btn')),
          findsNothing);
    });

    testWidgets(
        'EvidenceHomeScreen keeps clean Review records CTA when pending trips > 5',
        (tester) async {
      addPendingTrips(8);
      await tester.pumpWidget(wrap(const EvidenceHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Review records'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-1tap-batch-review-btn')),
          findsNothing);
    });
  });
}
