import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/evidence/evidence_auto_match_engine.dart';

void main() {
  group('EvidenceAutoMatchEngine Tests (Evidence Graph Async Linking)', () {
    final now = DateTime(2026, 10, 28, 14, 0); // 2:00 PM

    final workTrip = Trip(
      id: 'trip_work_1',
      vehicleId: 'veh_ute_1',
      date: now.subtract(const Duration(minutes: 30)), // 1:30 PM
      distanceKm: 4.5,
      purpose: 'Client Consultation',
    );

    test('Correlates direct travel expense captured 30 minutes after trip near destination', () {
      final tollExpense = VehicleExpense(
        id: 'exp_toll_1',
        vehicleId: 'veh_ute_1',
        amount: 14.50,
        category: ExpenseCategory.tollsParking,
        date: now, // 2:00 PM (30 mins after trip)
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: tollExpense,
        candidateTrips: [workTrip],
        receiptLatitude: -33.8570, // Parking near destination (~200m away)
        receiptLongitude: 151.2150,
        tripLatitude: -33.8568,
        tripLongitude: 151.2153,
      );

      expect(match, isNotNull);
      expect(match!.trip.id, equals('trip_work_1'));
      expect(match.confidenceScore, greaterThanOrEqualTo(0.85));
      expect(match.matchReason, contains('Matched work trip'));
    });

    test('Enforces ATO 2-Bucket Rule by keeping pooled fuel expenses unlinked', () {
      final fuelExpense = VehicleExpense(
        id: 'exp_fuel_1',
        vehicleId: 'veh_ute_1',
        amount: 85.50,
        category: ExpenseCategory.fuel,
        date: now,
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: fuelExpense,
        candidateTrips: [workTrip],
        receiptLatitude: -33.8570,
        receiptLongitude: 151.2150,
        tripLatitude: -33.8568,
        tripLongitude: 151.2153,
      );

      expect(match, isNull);
    });

    test('Rejects match when time difference exceeds 4 hours', () {
      final oldExpense = VehicleExpense(
        id: 'exp_toll_old',
        vehicleId: 'veh_ute_1',
        amount: 50.0,
        category: ExpenseCategory.tollsParking,
        date: now.subtract(const Duration(hours: 6)),
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: oldExpense,
        candidateTrips: [workTrip],
      );

      expect(match, isNull);
    });

    test('Rejects match when vehicleId does not match', () {
      final differentVehicleExpense = VehicleExpense(
        id: 'exp_toll_other',
        vehicleId: 'veh_personal_sedan',
        amount: 90.0,
        category: ExpenseCategory.tollsParking,
        date: now,
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: differentVehicleExpense,
        candidateTrips: [workTrip],
      );

      expect(match, isNull);
    });
  });
}
