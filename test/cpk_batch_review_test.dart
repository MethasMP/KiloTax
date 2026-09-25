import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/engine/purpose_synthesizer_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/trips/widgets/cpk_batch_review_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CPK Prioritized Features Tests', () {
    late AppState appState;
    late Vehicle vehicle;

    setUp(() async {
      appState = AppState();
      vehicle = Vehicle(
        id: 'test_ute_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'VIC-999',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);
    });

    test('Trip model serializes and deserializes jobReference correctly', () {
      final trip = Trip(
        id: 't_job_1',
        vehicleId: 'test_ute_1',
        distanceKm: 25.4,
        date: DateTime(2026, 9, 20),
        purpose: 'Site visit',
        jobReference: 'Job #402',
      );

      final json = trip.toJson();
      expect(json['jobReference'], 'Job #402');

      final reconstructed = Trip.fromJson(json);
      expect(reconstructed.jobReference, 'Job #402');
    });

    test('PurposeSynthesizerService embeds jobReference tag when provided', () {
      final purpose = PurposeSynthesizerService.synthesize(
        selectedPurpose: 'Client Site',
        destination: '74 Richmond Rd',
        jobReference: 'Job #901',
      );

      expect(purpose, contains('[Ref: Job #901]'));
      expect(purpose, contains('TR 95/34'));
    });

    test('batchApproveTrips in AppState updates multiple trips in 1 tap', () {
      final t1 = Trip(
        id: 'trip_batch_1',
        vehicleId: vehicle.id,
        distanceKm: 15.0,
        date: DateTime.now(),
        purpose: '?',
        classification: TripClassification.unclassified,
      );
      final t2 = Trip(
        id: 'trip_batch_2',
        vehicleId: vehicle.id,
        distanceKm: 22.0,
        date: DateTime.now(),
        purpose: '',
        classification: TripClassification.unclassified,
      );

      appState.recordTrip(t1);
      appState.recordTrip(t2);

      expect(appState.missingComplianceTrips.length, 2);

      appState.batchApproveTrips(
        tripIds: ['trip_batch_1', 'trip_batch_2'],
        defaultPurpose: 'Supplies Run',
        jobReference: 'Site Project A',
      );

      expect(appState.missingComplianceTrips.length, 0);

      final approved1 = appState.trips.firstWhere((t) => t.id == 'trip_batch_1');
      final approved2 = appState.trips.firstWhere((t) => t.id == 'trip_batch_2');

      expect(approved1.classification, TripClassification.business);
      expect(approved1.purpose, 'Supplies Run');
      expect(approved1.jobReference, 'Site Project A');

      expect(approved2.classification, TripClassification.business);
      expect(approved2.purpose, 'Supplies Run');
      expect(approved2.jobReference, 'Site Project A');
    });

    testWidgets('CpkBatchReviewSheet renders hero value and allows 1-tap approval', (tester) async {
      final t1 = Trip(
        id: 't_ui_1',
        vehicleId: vehicle.id,
        distanceKm: 20.0,
        // Wednesday at 10:00 AM (weekday trade hours)
        date: DateTime(2026, 9, 23, 10, 0),
        purpose: '?',
        originAddress: 'Warehouse',
        destinationAddress: 'Job Site',
        classification: TripClassification.unclassified,
      );
      appState.recordTrip(t1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CpkBatchReviewSheet(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Trip Verification'), findsOneWidget);
      expect(find.text('BATCH CLAIM VALUE'), findsOneWidget);
      // 20 km * 0.91 = $18.20 appears in hero card and item list
      expect(find.text('+\$18.20'), findsWidgets);
      expect(find.text('Sign-Off (1)'), findsOneWidget);

      await tester.tap(find.text('Sign-Off (1)'));
      await tester.pumpAndSettle();

      expect(appState.missingComplianceTrips.isEmpty, isTrue);
    });
  });
}
