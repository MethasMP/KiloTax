import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';

void main() {
  group('TaxCalculatorService - Vault-Only Receipt Exclusion Rules', () {
    final activeExpense1 = VehicleExpense(
      id: 'exp_1',
      vehicleId: 'veh_1',
      amount: 100.0,
      category: ExpenseCategory.fuel,
      date: DateTime(2024, 8, 1),
      isVaultOnly: false,
    );

    final priorYearVaultExpense = VehicleExpense(
      id: 'exp_2',
      vehicleId: 'veh_1',
      amount: 250.0,
      category: ExpenseCategory.fuel,
      date: DateTime(2023, 5, 1),
      isVaultOnly: true, // Saved to Vault Only (Prior Tax Year)
      vaultReason: 'prior_tax_year',
    );

    final directTollsActive = VehicleExpense(
      id: 'exp_3',
      vehicleId: 'veh_1',
      amount: 50.0,
      category: ExpenseCategory.tollsParking,
      date: DateTime(2024, 8, 5),
      isVaultOnly: false,
    );

    final directTollsVault = VehicleExpense(
      id: 'exp_4',
      vehicleId: 'veh_1',
      amount: 40.0,
      category: ExpenseCategory.tollsParking,
      date: DateTime(2023, 3, 2),
      isVaultOnly: true,
      vaultReason: 'prior_tax_year',
    );

    test('calculateLogbookClaim excludes vault-only expenses from claim', () {
      final expenses = [activeExpense1, priorYearVaultExpense, directTollsActive, directTollsVault];
      final claim = TaxCalculatorService.calculateLogbookClaim(
        expenses: expenses,
        businessPercentage: 80.0,
      );

      expect(claim, equals(130.0));
    });

    test('evaluateSummary excludes vault-only expenses from totalRunning and totalDirect', () {
      final trip1 = Trip(
        id: 't1',
        vehicleId: 'veh_1',
        startOdometer: 10000,
        endOdometer: 10800,
        distanceKm: 800,
        classification: TripClassification.business,
        purpose: 'Site visit',
        date: DateTime(2024, 8, 1),
      );
      final trip2 = Trip(
        id: 't2',
        vehicleId: 'veh_1',
        startOdometer: 10800,
        endOdometer: 11000,
        distanceKm: 200,
        classification: TripClassification.personal,
        purpose: 'Personal',
        date: DateTime(2024, 8, 2),
      );

      final expenses = [activeExpense1, priorYearVaultExpense, directTollsActive, directTollsVault];

      final summary = TaxCalculatorService.evaluateSummary(
        trips: [trip1, trip2],
        expenses: expenses,
      );

      expect(summary.totalRunningExpenses, equals(100.0)); // $250 prior year is excluded
      expect(summary.totalDirectDeductions, equals(50.0)); // $40 prior year is excluded
      expect(summary.businessPercentage, equals(80.0));
      expect(summary.logbookClaim, equals(130.0));
    });
  });
}
