import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/services/engine/evidence_engine.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';
import 'package:kilotax/services/engine/ato_report_service.dart';

void main() {
  group('KiloTax Evidence Graph & Accountant Pack Tests', () {
    final vehicle = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Hilux SR5 4x4',
      regoPlate: 'TRADIE-777 (NSW)',
      initialOdometer: 50000.0,
      taxMethod: TaxMethod.logbook,
    );

    test('Evidence Graph properly links Trip to Expense receipt', () {
      final trip = Trip(
        id: 'trip_101',
        vehicleId: vehicle.id,
        distanceKm: 42.5,
        date: DateTime.now(),
        purpose: 'Drive to client job site via Bunnings Alexandria',
        startOdometer: 50000.0,
        endOdometer: 50042.5,
        linkedExpenseIds: ['exp_201'],
      );

      final expense = VehicleExpense(
        id: 'exp_201',
        vehicleId: vehicle.id,
        amount: 145.80,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        receiptPath: '/vault/receipts/rec_201.jpg',
        linkedTripId: 'trip_101',
      );

      expect(expense.linkedTripId, equals('trip_101'));
      expect(trip.linkedExpenseIds, contains('exp_201'));

      final engine = EvidenceEngine(vehicle: vehicle);
      engine.recordTrip(trip);
      engine.recordExpense(expense);

      final summary = TaxCalculatorService.evaluateSummary(
        trips: engine.trips,
        expenses: engine.expenses,
      );

      final csv = AtoReportService.generateAtoAuditCsv(
        vehicle: vehicle,
        engine: engine,
        summary: summary,
      );

      // Verify that CSV contains Evidence Graph audit link
      expect(csv, contains('Trip: Drive to client job site via Bunnings Alexandria (42.5 km)'));
      expect(csv, contains('trip_101'));

      final emailText = AtoReportService.generateAccountantEmailText(
        vehicle: vehicle,
        summary: summary,
        tripCount: engine.trips.length,
        expenseCount: engine.expenses.length,
      );

      expect(emailText, contains('ATO TAX DEDUCTION CLAIM SUMMARY'));
      expect(emailText, contains('Box D1'));
      expect(emailText, contains('Total Logged Work Trips: 1'));
      expect(emailText, contains('Total Substantiated Receipts: 1'));
    });
  });
}
