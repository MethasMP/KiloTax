import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/logbook/widgets/odometer_gap_review_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TaskHomeBody surfaces OdometerGapReviewCard when pending gaps exist',
      (WidgetTester tester) async {
    final appState = AppState();
    await appState.init();

    // Create a primary vehicle with initial odometer 10,000 km
    final vehicle = Vehicle(
      id: 'test_veh_1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'TRADIE1',
      initialOdometer: 10000.0,
      taxMethod: TaxMethod.centsPerKm,
    );
    await appState.addVehicle(vehicle);

    // Add a trip that starts at 10,050 km (leaving a 50 km gap from baseline 10,000)
    final trip = Trip(
      id: 'trip_1',
      vehicleId: 'test_veh_1',
      startOdometer: 10050.0,
      endOdometer: 10080.0,
      distanceKm: 30.0,
      date: DateTime.now(),
      purpose: 'Job Site Visit',
      classification: TripClassification.business,
      originAddress: 'Depot',
      destinationAddress: 'Site A',
    );
    appState.recordTrip(trip);

    // Verify appState detected the gap
    expect(appState.pendingOdometerGaps.isNotEmpty, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskHomeBody(appState: appState),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down in ListView so lazy children below HomeRecentActivity are built
    await tester.scrollUntilVisible(find.byType(OdometerGapReviewCard), 200);
    await tester.pumpAndSettle();

    // Verify OdometerGapReviewCard is rendered on the screen
    expect(find.byType(OdometerGapReviewCard), findsOneWidget);
    expect(find.textContaining('travel needs review'), findsOneWidget);
    expect(find.text('Review missing travel'), findsOneWidget);
  });
}
