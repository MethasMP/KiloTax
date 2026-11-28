import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/cpk_export_service.dart';

void main() {
  group('CpkExportService Arithmetic Verification (ITAA 1997 s 28-25)', () {
    test('CPK deduction caps at 5000km', () {
      final result =
          CpkExportService().calculate(businessKm: 6000, ratePerKm: 0.88);
      expect(result.cappedKm, 5000);
      expect(result.deductionAud, closeTo(4400.00, 0.01));
    });

    test('CPK deduction does not cap under 5000km', () {
      final result =
          CpkExportService().calculate(businessKm: 3000, ratePerKm: 0.88);
      expect(result.cappedKm, 3000);
      expect(result.deductionAud, closeTo(2640.00, 0.01));
    });

    test('fuel/maintenance costs not included in CPK deduction', () {
      final result = CpkExportService().calculate(
        businessKm: 3000,
        ratePerKm: 0.88,
        runningCosts: [
          VehicleExpense(
            id: 'exp-fuel-1',
            vehicleId: 'v1',
            date: DateTime(2026, 8, 1),
            amount: 500,
            category: ExpenseCategory.fuel,
          ),
        ],
      );
      expect(result.deductionAud, closeTo(2640.00, 0.01)); // unchanged
    });
  });
}
