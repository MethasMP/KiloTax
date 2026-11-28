import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/evidence/evidence_auto_match_engine.dart';

void main() {
  group('ATO 2-Bucket Rule & Trip-to-Receipt Linking (Item 2)', () {
    final now = DateTime(2026, 11, 20, 14, 0);

    final workTripToBunnings = Trip(
      id: 'trip_bunnings_1',
      vehicleId: 'ute_1',
      date: now,
      startOdometer: 10000,
      endOdometer: 10015,
      destinationAddress: 'Bunnings Alexandria, 520 Gardeners Rd',
      purpose: 'Pick up trade supplies and drills',
      classification: TripClassification.business,
    );

    final workTripGeneral = Trip(
      id: 'trip_job_2',
      vehicleId: 'ute_1',
      date: now.subtract(const Duration(hours: 1)),
      startOdometer: 9950,
      endOdometer: 10000,
      destinationAddress: 'Site 44, Surry Hills',
      purpose: 'Electrical rough-in',
      classification: TripClassification.business,
    );

    test('1. Fuel and maintenance expenses are NEVER individual-trip linked (enforces Vehicle Running Pool)', () {
      final fuelExpense = VehicleExpense(
        id: 'exp_fuel_1',
        vehicleId: 'ute_1',
        amount: 110.00,
        category: ExpenseCategory.fuel,
        date: now,
      );

      final serviceExpense = VehicleExpense(
        id: 'exp_service_1',
        vehicleId: 'ute_1',
        amount: 450.00,
        category: ExpenseCategory.maintenanceTyres,
        date: now,
      );

      final fuelMatch = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: fuelExpense,
        candidateTrips: [workTripToBunnings, workTripGeneral],
      );

      final serviceMatch = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: serviceExpense,
        candidateTrips: [workTripToBunnings, workTripGeneral],
      );

      // Invariant: Running costs belong to annual vehicle logbook pool, not single trips
      expect(fuelMatch, isNull);
      expect(serviceMatch, isNull);
    });

    test('2. Tools and Materials expenses CAN match same-day trade hardware stops with high confidence', () {
      final toolsExpense = VehicleExpense(
        id: 'exp_tools_1',
        vehicleId: 'ute_1',
        amount: 320.00,
        category: ExpenseCategory.toolsMaterials,
        date: now.add(const Duration(minutes: 15)),
        notes: 'Dewalt Cordless Hammer Drill Bunnings',
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: toolsExpense,
        candidateTrips: [workTripToBunnings, workTripGeneral],
      );

      expect(match, isNotNull);
      expect(match!.trip.id, equals('trip_bunnings_1'));
      expect(match.isTradeSupplyMatch, isTrue);
      expect(match.confidenceScore, greaterThanOrEqualTo(0.90));
    });

    test('3. Personal trips are blocked by statutory firewall from linking to any expense', () {
      final personalTrip = Trip(
        id: 'trip_personal_1',
        vehicleId: 'ute_1',
        date: now,
        startOdometer: 10050,
        endOdometer: 10060,
        destinationAddress: 'Bunnings Alexandria',
        purpose: 'Weekend DIY personal garden pot',
        classification: TripClassification.personal,
      );

      final toolsExpense = VehicleExpense(
        id: 'exp_tools_2',
        vehicleId: 'ute_1',
        amount: 80.00,
        category: ExpenseCategory.toolsMaterials,
        date: now,
      );

      final match = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: toolsExpense,
        candidateTrips: [personalTrip],
      );

      expect(match, isNull);
    });
  });
}
