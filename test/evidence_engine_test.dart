import 'package:flutter_test/flutter_test.dart';
import '../lib/core/constants/app_constants.dart';
import '../lib/data/models/vehicle.dart';
import '../lib/data/models/trip.dart';
import '../lib/data/models/vehicle_expense.dart';
import '../lib/data/models/tax_summary.dart';
import '../lib/services/engine/evidence_engine.dart';
import '../lib/services/engine/tax_calculator_service.dart';
import '../lib/services/engine/ato_report_service.dart';

void main() {
  group('KiloTax Evidence Engine Architecture Pipeline Tests', () {
    late Vehicle testVehicle;
    late EvidenceEngine engine;

    setUp(() {
      testVehicle = Vehicle(
        id: 'veh_test_1',
        make: 'Toyota',
        model: 'Hilux SR5',
        regoPlate: 'TRD-777 (NSW)',
        initialOdometer: 50000.0,
      );
      engine = EvidenceEngine(vehicle: testVehicle);
    });

    test('Layer 1 (TRIPS): Ingests trips with odometer tracking', () {
      final trip1 = Trip(
        id: 'trip_1',
        vehicleId: testVehicle.id,
        distanceKm: 80.0,
        date: DateTime.now(),
        purpose: 'Site inspection Newcastle',
        startOdometer: 50000.0,
        endOdometer: 50080.0,
        classification: TripClassification.business,
      );
      final trip2 = Trip(
        id: 'trip_2',
        vehicleId: testVehicle.id,
        distanceKm: 20.0,
        date: DateTime.now(),
        purpose: 'Personal shopping',
        startOdometer: 50080.0,
        endOdometer: 50100.0,
        classification: TripClassification.personal,
      );

      engine.recordTrip(trip1);
      engine.recordTrip(trip2);

      expect(engine.trips.length, 2);
      expect(engine.validateOdometerContinuity(), isTrue);
    });

    test('Layer 2 (EXPENSES): Categorizes statutory ATO expenses and direct deductions', () {
      final fuel = VehicleExpense(
        id: 'exp_1',
        vehicleId: testVehicle.id,
        amount: 150.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        receiptPath: '/vault/receipts/fuel_1.jpg',
      );
      final toll = VehicleExpense(
        id: 'exp_2',
        vehicleId: testVehicle.id,
        amount: 22.50,
        category: ExpenseCategory.tollsParking,
        date: DateTime.now(),
        receiptPath: '/vault/receipts/toll_1.jpg',
      );

      engine.recordExpense(fuel);
      engine.recordExpense(toll);

      expect(engine.expenses.length, 2);
      expect(engine.receiptPreservationRate(), 100.0);
      expect(toll.businessPercentage, 100.0); // Direct deduction
    });

    test('Layer 4 (DUAL TAX CALCULATION): Verifies Cents/KM and Logbook % logic', () {
      // 80 km business, 20 km personal = 80.0% business use
      final tripBiz = Trip(
        id: 't_b',
        vehicleId: testVehicle.id,
        distanceKm: 80.0,
        date: DateTime.now(),
        purpose: 'Client job',
        startOdometer: 50000.0,
        endOdometer: 50080.0,
        classification: TripClassification.business,
      );
      final tripPer = Trip(
        id: 't_p',
        vehicleId: testVehicle.id,
        distanceKm: 20.0,
        date: DateTime.now(),
        purpose: 'Personal',
        startOdometer: 50080.0,
        endOdometer: 50100.0,
        classification: TripClassification.personal,
      );

      engine.recordTrip(tripBiz);
      engine.recordTrip(tripPer);

      // Cents per km claim = 80 km * 0.91 = $72.80
      final centsClaim = TaxCalculatorService.calculateCentsPerKm(80.0);
      expect(centsClaim, closeTo(72.80, 0.01));

      // Business % = (80 / 100) * 100 = 80.0%
      final bizPct = TaxCalculatorService.calculateBusinessPercentage(80.0, 100.0);
      expect(bizPct, 80.0);
    });

    test('Layer 5 & 6: Tax Summary evaluation and ATO TR 97/11 CSV generation', () {
      engine.recordTrip(Trip(
        id: 't1',
        vehicleId: testVehicle.id,
        distanceKm: 4000.0,
        date: DateTime.now(),
        purpose: 'Electrical contracting',
        startOdometer: 50000.0,
        endOdometer: 54000.0,
        classification: TripClassification.business,
      ));
      engine.recordTrip(Trip(
        id: 't2',
        vehicleId: testVehicle.id,
        distanceKm: 1000.0,
        date: DateTime.now(),
        purpose: 'Personal commute',
        startOdometer: 54000.0,
        endOdometer: 55000.0,
        classification: TripClassification.personal,
      ));

      // 4000 km / 5000 km = 80% Business %
      // Expenses: $8,000 running costs + $500 direct parking
      engine.recordExpense(VehicleExpense(
        id: 'e1',
        vehicleId: testVehicle.id,
        amount: 8000.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        receiptPath: '/receipts/fuel_total.jpg',
      ));
      engine.recordExpense(VehicleExpense(
        id: 'e2',
        vehicleId: testVehicle.id,
        amount: 500.0,
        category: ExpenseCategory.tollsParking,
        date: DateTime.now(),
        receiptPath: '/receipts/tolls.jpg',
      ));

      final summary = engine.generateTaxSummary();

      // Cents/KM = 4,000 km * $0.91 = $3,640.00
      expect(summary.centsPerKmClaim, closeTo(3640.0, 0.01));

      // Logbook = (8000 * 0.80) + 500 = $6,400 + $500 = $6,900.00
      expect(summary.logbookClaim, closeTo(6900.0, 0.01));

      // Logbook is higher, recommended method must be Logbook
      expect(summary.recommendedMethod, RecommendedMethod.logbook);
      expect(summary.highestClaim, closeTo(6900.0, 0.01));

      // Generate Report (Layer 6)
      final report = AtoReportService.generateAtoAuditCsv(
        vehicle: testVehicle,
        engine: engine,
        summary: summary,
      );

      expect(report.contains('OFFICIAL ATO MOTOR VEHICLE LOGBOOK & EXPENSE SCHEDULE'), isTrue);
      expect(report.contains('SCHEDULE 1: ATO MOTOR VEHICLE LOGBOOK TRIPS'), isTrue);
      expect(report.contains('SCHEDULE 2: ITEMIZED VEHICLE EXPENSES'), isTrue);
      expect(report.contains('Advised ATO Lodgement Figure: \$6,900.00'), isTrue);
    });
  });
}
