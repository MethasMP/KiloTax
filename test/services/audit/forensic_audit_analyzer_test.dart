import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/audit/forensic_audit_analyzer.dart';

void main() {
  group('ForensicAuditAnalyzer (The 102 Value Engine) TDD Tests', () {
    late ForensicAuditAnalyzer analyzer;

    setUp(() {
      analyzer = ForensicAuditAnalyzer();
    });

    test('Detects dangerous Odometer Gaps between sequential trips (> 5km threshold)', () {
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'veh_1',
          date: DateTime(2026, 10, 1),
          startOdometer: 10000.0,
          endOdometer: 10050.0,
          distanceKm: 50.0,
          purpose: 'Site A',
        ),
        Trip(
          id: 't2',
          vehicleId: 'veh_1',
          date: DateTime(2026, 10, 2),
          startOdometer: 10090.0, // 40 km unevidenced gap!
          endOdometer: 10120.0,
          distanceKm: 30.0,
          purpose: 'Site B',
        ),
      ];

      final report = analyzer.analyze(trips: trips, expenses: []);

      expect(report.odometerGaps.length, 1);
      expect(report.odometerGaps.first.gapKm, 40.0);
      expect(report.auditRiskScore, greaterThan(25.0)); // High risk flag
      expect(report.recommendations, anyElement(contains('Unevidenced odometer gap of 40.0 km')));
    });

    test('Identifies unlinked expenses and calculates missed deduction arbitrage', () {
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'veh_1',
          date: DateTime(2026, 10, 1, 8, 0),
          startOdometer: 10000.0,
          endOdometer: 10050.0,
          distanceKm: 50.0,
          purpose: 'Bunnings & Site Work',
          classification: TripClassification.business,
        ),
      ];

      final List<VehicleExpense> expenses = [
        VehicleExpense(
          id: 'exp_1',
          vehicleId: 'veh_1',
          date: DateTime(2026, 10, 1, 8, 30),
          amount: 245.50,
          category: ExpenseCategory.toolsMaterials,
          notes: 'Bunnings Port Melbourne',
          receiptPath: '/storage/bunnings.jpg',
        ),
        VehicleExpense(
          id: 'exp_2',
          vehicleId: 'veh_1',
          date: DateTime(2026, 10, 15),
          amount: 120.00,
          category: ExpenseCategory.fuel,
          notes: 'BP Service Station',
          receiptPath: null, // Missing receipt!
        ),
      ];

      final report = analyzer.analyze(trips: trips, expenses: expenses);

      expect(report.unlinkedExpenses.length, 2);
      expect(report.missingReceiptExpenses.length, 1);
      expect(report.totalSubstantiatedExpenseDeduction, 245.50);
      expect(report.atRiskExpenseAmount, 120.00);
      expect(report.estimatedMissedTaxDeductionDollars, greaterThan(0));
    });

    test('Evaluates ATO 12-Week Logbook compliance validity', () {
      // Create trips covering only 4 weeks
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'veh_1',
          date: DateTime(2026, 7, 1),
          startOdometer: 10000.0,
          endOdometer: 10050.0,
          distanceKm: 50.0,
          purpose: 'Job 1',
        ),
        Trip(
          id: 't2',
          vehicleId: 'veh_1',
          date: DateTime(2026, 7, 29),
          startOdometer: 10050.0,
          endOdometer: 10100.0,
          distanceKm: 50.0,
          purpose: 'Job 2',
        ),
      ];

      final report = analyzer.analyze(trips: trips, expenses: []);

      expect(report.isAto12WeekPeriodComplete, false);
      expect(report.completedConsecutiveWeeks, 4);
      expect(report.auditStatus, AuditRiskStatus.incompletePeriod);
    });
  });
}
