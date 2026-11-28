import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/cpk_batch_review_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'EvidenceBatchReviewSheet supports Logbook vehicles with km impact and 1-tap Approve All',
      (tester) async {
    final appState = AppState();
    addTearDown(appState.dispose);

    final vehicle = Vehicle(
      id: 'v_logbook_1',
      make: 'Isuzu',
      model: 'D-MAX',
      regoPlate: 'LOG-101',
      initialOdometer: 20000.0,
      taxMethod: TaxMethod.logbook,
    );
    await appState.addVehicle(vehicle);

    appState.recordExpense(
      VehicleExpense(
        id: 'exp_log_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 9, 23, 10, 15),
        amount: 95.0,
        category: ExpenseCategory.fuel,
        supplier: 'BP Connect',
      ),
    );

    final trip = Trip(
      id: 't_log_1',
      vehicleId: vehicle.id,
      distanceKm: 34.5,
      date: DateTime(2026, 9, 23, 10, 0),
      purpose: '?',
      originAddress: '45 King St',
      destinationAddress: 'BP Connect',
      linkedExpenseIds: const ['exp_log_1'],
      classification: TripClassification.unclassified,
    );
    appState.recordTrip(trip);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceBatchReviewSheet(appState: appState),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOGBOOK BATCH IMPACT'), findsOneWidget);
    expect(find.text('+35 km'), findsOneWidget);
    expect(find.text('Approve All (1)'), findsOneWidget);

    await tester.tap(find.text('Approve All (1)'));
    await tester.pumpAndSettle();

    final approved = appState.trips.firstWhere((t) => t.id == 't_log_1');
    expect(approved.classification, TripClassification.business);
    expect(appState.missingComplianceTrips, isEmpty);
  });
}
