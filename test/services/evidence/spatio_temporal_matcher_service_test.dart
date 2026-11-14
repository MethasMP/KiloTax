import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/evidence/evidence_auto_match_engine.dart';

void main() {
  group('SpatioTemporalMatcherService Tests (Phase 2 Auto-Matcher Criteria)', () {
    final now = DateTime(2026, 11, 8, 14, 0); // 2:00 PM

    final workTrip = Trip(
      id: 'trip_site_1',
      vehicleId: 'veh_hilux_01',
      date: DateTime(2026, 11, 8, 13, 0), // 1:00 PM
      distanceKm: 25.0,
      purpose: 'HVAC Installation at Barangaroo',
      originAddress: '78 Trade Park, Alexandria NSW',
      destinationAddress: '200 Barangaroo Ave, Sydney NSW',
    );

    group('Criterion (a): Fuel stops', () {
      test('Matches fuel stop when trip end is within 300m of expense GPS', () {
        // Destination is Sydney CBD (-33.8640, 151.2010)
        // Fuel stop is 180m away at (-33.8655, 151.2015)
        final fuelExpense = VehicleExpense(
          id: 'exp_fuel_gps',
          vehicleId: 'veh_hilux_01',
          amount: 110.00,
          category: ExpenseCategory.fuel,
          date: now, // 1 hour after trip start
        );

        final match = SpatioTemporalMatcherService.findBestMatchingTrip(
          expense: fuelExpense,
          candidateTrips: [workTrip],
          receiptLatitude: -33.8655,
          receiptLongitude: 151.2015,
          tripLatitude: -33.8640,
          tripLongitude: 151.2010,
        );

        expect(match, isNotNull);
        expect(match!.trip.id, equals('trip_site_1'));
        expect(match.confidenceScore, greaterThanOrEqualTo(0.90));
        expect(match.matchReason.toLowerCase(), contains('fuel stop location verified'));
      });

      test('Matches fuel stop when expense timestamp is within +/- 30 minutes of trip start/end', () {
        // Expense captured at 1:20 PM (20 mins after 1:00 PM trip start)
        final fuelExpense = VehicleExpense(
          id: 'exp_fuel_time',
          vehicleId: 'veh_hilux_01',
          amount: 95.00,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 11, 8, 13, 20),
        );

        final match = SpatioTemporalMatcherService.findBestMatchingTrip(
          expense: fuelExpense,
          candidateTrips: [workTrip],
        );

        expect(match, isNotNull);
        expect(match!.trip.id, equals('trip_site_1'));
        expect(match.confidenceScore, greaterThanOrEqualTo(0.90));
        expect(match.matchReason.toLowerCase(), contains('fuel stop timestamp matched within'));
      });
    });

    group('Criterion (b): Bunnings / Trade Supply stops', () {
      test('Automatically links expense when trip destination is Bunnings Warehouse', () {
        final bunningsTrip = Trip(
          id: 'trip_bunnings_run',
          vehicleId: 'veh_hilux_01',
          date: now,
          distanceKm: 8.5,
          purpose: 'Materials Run',
          destinationAddress: 'Bunnings Warehouse Alexandria, Euston Rd',
        );

        final bunningsExpense = VehicleExpense(
          id: 'exp_bunnings_tools',
          vehicleId: 'veh_hilux_01',
          amount: 284.50,
          category: ExpenseCategory.toolsMaterials,
          date: now.add(const Duration(minutes: 15)),
          notes: 'PVC conduit, copper fittings, drill bits',
        );

        final match = SpatioTemporalMatcherService.findBestMatchingTrip(
          expense: bunningsExpense,
          candidateTrips: [bunningsTrip],
        );

        expect(match, isNotNull);
        expect(match!.trip.id, equals('trip_bunnings_run'));
        expect(match.isTradeSupplyMatch, isTrue);
        expect(match.confidenceScore, equals(0.98));
        expect(match.matchReason, contains('Bunnings Warehouse'));
      });

      test('Automatically links expense when trip destination is Reece Plumbing', () {
        final reeceTrip = Trip(
          id: 'trip_reece_run',
          vehicleId: 'veh_hilux_01',
          date: now,
          distanceKm: 6.0,
          purpose: 'Supplies Run',
          destinationAddress: 'Reece Plumbing Brookvale',
        );

        final reeceExpense = VehicleExpense(
          id: 'exp_reece_valves',
          vehicleId: 'veh_hilux_01',
          amount: 340.00,
          category: ExpenseCategory.toolsMaterials,
          date: now.add(const Duration(minutes: 10)),
          notes: 'Reece trade account brass valves',
        );

        final match = SpatioTemporalMatcherService.findBestMatchingTrip(
          expense: reeceExpense,
          candidateTrips: [reeceTrip],
        );

        expect(match, isNotNull);
        expect(match!.trip.id, equals('trip_reece_run'));
        expect(match.isTradeSupplyMatch, isTrue);
        expect(match.matchReason, contains('Reece Plumbing'));
      });
    });

    group('Criterion (c): Bidirectional linking immutability', () {
      test('linkBidirectionally sets expense.linkedTripId and adds expense.id to trip.linkedExpenseIds', () {
        final expense = VehicleExpense(
          id: 'exp_mat_456',
          vehicleId: 'veh_hilux_01',
          amount: 150.0,
          category: ExpenseCategory.toolsMaterials,
          date: now,
        );

        final trip = Trip(
          id: 'trip_client_88',
          vehicleId: 'veh_hilux_01',
          date: now,
          distanceKm: 14.0,
          purpose: 'Site Framing',
          linkedExpenseIds: ['existing_exp_1'],
        );

        final linked = SpatioTemporalMatcherService.linkBidirectionally(
          expense: expense,
          trip: trip,
        );

        expect(linked.updatedExpense.linkedTripId, equals('trip_client_88'));
        expect(linked.updatedTrip.linkedExpenseIds, contains('exp_mat_456'));
        expect(linked.updatedTrip.linkedExpenseIds, contains('existing_exp_1'));
        expect(linked.updatedTrip.linkedExpenseIds.length, equals(2));

        // Test idempotency: re-linking doesn't duplicate IDs
        final reLinked = SpatioTemporalMatcherService.linkBidirectionally(
          expense: linked.updatedExpense,
          trip: linked.updatedTrip,
        );
        expect(reLinked.updatedTrip.linkedExpenseIds.length, equals(2));
      });

      test('unlinkBidirectionally clears expense.linkedTripId and removes expense.id from trip', () {
        final expense = VehicleExpense(
          id: 'exp_mat_456',
          vehicleId: 'veh_hilux_01',
          amount: 150.0,
          category: ExpenseCategory.toolsMaterials,
          date: now,
          linkedTripId: 'trip_client_88',
        );

        final trip = Trip(
          id: 'trip_client_88',
          vehicleId: 'veh_hilux_01',
          date: now,
          distanceKm: 14.0,
          purpose: 'Site Framing',
          linkedExpenseIds: ['existing_exp_1', 'exp_mat_456'],
        );

        final unlinked = SpatioTemporalMatcherService.unlinkBidirectionally(
          expense: expense,
          trip: trip,
        );

        expect(unlinked.updatedExpense.linkedTripId, isNull);
        expect(unlinked.updatedTrip.linkedExpenseIds, isNot(contains('exp_mat_456')));
        expect(unlinked.updatedTrip.linkedExpenseIds, contains('existing_exp_1'));
        expect(unlinked.updatedTrip.linkedExpenseIds.length, equals(1));
      });
    });
  });
}
