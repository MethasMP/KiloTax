import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/trip_review_sheet.dart';
import 'package:kiloclaim/ui/screens/trips/trip_live_tracking_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('CPK vs Logbook Journey Decoupling & Isolation Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('1. LiveDrive HUD renders Claim Accumulating for CPK and Logbook Badge for Logbook',
        (tester) async {
      // Set vehicle to Logbook
      final logbookVeh = Vehicle(
        id: 'v_logbook',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'LB-999',
        initialOdometer: 20000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(logbookVeh);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: TripLiveTrackingScreen(appState: appState),
          ),
        ),
      );
      await tester.pump();

      // Logbook should display 'Logbook Substantiation Drive' instead of Claim Accumulating dollar
      expect(find.text('Logbook Substantiation Drive'), findsOneWidget);
      expect(find.textContaining('Claim Accumulating:'), findsNothing);
    });

    testWidgets('2. TripReviewSheet hides CpkBatchReview button for Logbook vehicles',
        (tester) async {
      final logbookVeh = Vehicle(
        id: 'v_logbook_2',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'LB-123',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(logbookVeh);

      // Add a missing compliance trip
      appState.recordTrip(
        Trip(
          id: 't_missing_1',
          vehicleId: logbookVeh.id,
          distanceKm: 25.0,
          date: DateTime.now(),
          purpose: '',
          classification: TripClassification.unclassified,
          taxMethod: TaxMethod.logbook,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => TripReviewSheet.show(context, appState),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Batch button should NOT appear for Logbook to prevent CPK calculation pollution
      expect(find.text('Batch'), findsNothing);
    });
  });
}
