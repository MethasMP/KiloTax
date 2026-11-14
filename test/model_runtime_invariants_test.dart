import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';

void main() {
  group('PR-08: Model Runtime Invariants Clamping', () {
    test('Trip distanceKm clamps negative value to 0.0 at runtime in constructor', () {
      final trip = Trip(
        id: 't_neg',
        vehicleId: 'v1',
        distanceKm: -12.5,
        date: DateTime.now(),
        purpose: 'Test negative distance',
      );
      expect(trip.distanceKm, equals(0.0));
    });

    test('Trip distanceKm clamps negative value to 0.0 in fromJson deserialization', () {
      final trip = Trip.fromJson({
        'id': 't_neg_json',
        'vehicleId': 'v1',
        'distanceKm': -42.8,
        'date': DateTime.now().toIso8601String(),
        'purpose': 'Negative in JSON',
      });
      expect(trip.distanceKm, equals(0.0));
    });

    test('VehicleExpense businessPercentage clamps values outside 0.0..100.0', () {
      final overExpense = VehicleExpense(
        id: 'e_over',
        vehicleId: 'v1',
        amount: 200.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        businessPercentage: 150.0,
      );
      expect(overExpense.businessPercentage, equals(100.0));

      final underExpense = VehicleExpense(
        id: 'e_under',
        vehicleId: 'v1',
        amount: 200.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        businessPercentage: -25.0,
      );
      expect(underExpense.businessPercentage, equals(0.0));
    });

    test('VehicleExpense fromJson clamps businessPercentage outside 0.0..100.0', () {
      final overJson = VehicleExpense.fromJson({
        'id': 'e_over_json',
        'vehicleId': 'v1',
        'amount': 100.0,
        'category': 'fuel',
        'date': DateTime.now().toIso8601String(),
        'businessPercentage': 500.0,
      });
      expect(overJson.businessPercentage, equals(100.0));

      final underJson = VehicleExpense.fromJson({
        'id': 'e_under_json',
        'vehicleId': 'v1',
        'amount': 100.0,
        'category': 'fuel',
        'date': DateTime.now().toIso8601String(),
        'businessPercentage': -50.0,
      });
      expect(underJson.businessPercentage, equals(0.0));
    });

    test('Positive values within bounds are preserved accurately', () {
      final trip = Trip(
        id: 't_valid',
        vehicleId: 'v1',
        distanceKm: 28.4,
        date: DateTime.now(),
        purpose: 'Valid trip',
      );
      expect(trip.distanceKm, equals(28.4));

      final expense = VehicleExpense(
        id: 'e_valid',
        vehicleId: 'v1',
        amount: 85.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        businessPercentage: 75.0,
      );
      expect(expense.businessPercentage, equals(75.0));
      expect(expense.deductibleAmount, equals(85.0 * 0.75));
    });
  });
}
