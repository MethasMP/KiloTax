import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';

void main() {
  const customRule = AtoTaxRule(
    financialYear: '2026-27',
    centsPerKmRate: 0.91,
    centsPerKmMaxKm: 5000.0,
    carDepreciationLimit: 69674.0,
  );

  group('TaxCalculatorService Multi-Vehicle Independent Cap Allocator', () {
    test(
        '2 vehicles under cap: Vehicle 1 (4,500 km), Vehicle 2 (3,000 km) are not capped at 5,000 km total',
        () {
      final tripV1 = Trip(
        id: 't1',
        vehicleId: 'veh_ute',
        distanceKm: 4500.0,
        classification: TripClassification.business,
        purpose: 'Trade deliveries',
        date: DateTime(2026, 8, 10),
      );

      final tripV2 = Trip(
        id: 't2',
        vehicleId: 'veh_van',
        distanceKm: 3000.0,
        classification: TripClassification.business,
        purpose: 'Site maintenance',
        date: DateTime(2026, 8, 11),
      );

      final totalClaim = TaxCalculatorService.calculateMultiVehicleCentsPerKm(
        trips: [tripV1, tripV2],
        taxRule: customRule,
      );

      // (4500 * 0.91) + (3000 * 0.91) = 4095 + 2730 = 6825.0
      expect(totalClaim, equals(4500.0 * 0.91 + 3000.0 * 0.91));
      expect(totalClaim, equals(6825.0));

      final breakdown = TaxCalculatorService.calculatePerVehicleBreakdown(
        trips: [tripV1, tripV2],
        taxRule: customRule,
      );

      expect(breakdown['veh_ute'], equals(4095.0));
      expect(breakdown['veh_van'], equals(2730.0));
    });

    test(
        '1 vehicle over cap: Vehicle 1 (6,200 km capped at 5,000 km), Vehicle 2 (2,000 km claim 2,000 km)',
        () {
      final tripV1Part1 = Trip(
        id: 't1',
        vehicleId: 'veh_1',
        distanceKm: 4000.0,
        classification: TripClassification.business,
        purpose: 'Contract work 1',
        date: DateTime(2026, 9, 1),
      );
      final tripV1Part2 = Trip(
        id: 't2',
        vehicleId: 'veh_1',
        distanceKm: 2200.0,
        classification: TripClassification.business,
        purpose: 'Contract work 2',
        date: DateTime(2026, 9, 2),
      );
      final tripV2 = Trip(
        id: 't3',
        vehicleId: 'veh_2',
        distanceKm: 2000.0,
        classification: TripClassification.business,
        purpose: 'Supplier runs',
        date: DateTime(2026, 9, 3),
      );

      final totalClaim = TaxCalculatorService.calculateMultiVehicleCentsPerKm(
        trips: [tripV1Part1, tripV1Part2, tripV2],
        taxRule: customRule,
      );

      // Vehicle 1 has 6,200 km -> capped at 5,000 km (5,000 * 0.91 = 4,550.0)
      // Vehicle 2 has 2,000 km -> 2,000 km (2,000 * 0.91 = 1,820.0)
      // Total claim = 4,550.0 + 1,820.0 = 6,370.0
      expect(totalClaim, equals(6370.0));

      final breakdown = TaxCalculatorService.calculatePerVehicleBreakdown(
        trips: [tripV1Part1, tripV1Part2, tripV2],
        taxRule: customRule,
      );

      expect(breakdown['veh_1'], equals(4550.0));
      expect(breakdown['veh_2'], equals(1820.0));
    });

    test('evaluateSummary calculates multi-vehicle independent cap correctly', () {
      final tripV1 = Trip(
        id: 't1',
        vehicleId: 'veh_1',
        distanceKm: 6000.0,
        classification: TripClassification.business,
        purpose: 'Business 1',
        date: DateTime(2026, 8, 1),
      );
      final tripV2 = Trip(
        id: 't2',
        vehicleId: 'veh_2',
        distanceKm: 3000.0,
        classification: TripClassification.business,
        purpose: 'Business 2',
        date: DateTime(2026, 8, 2),
      );
      final tripPersonal = Trip(
        id: 't3',
        vehicleId: 'veh_1',
        distanceKm: 1000.0,
        classification: TripClassification.personal,
        purpose: 'Personal trip',
        date: DateTime(2026, 8, 3),
      );

      final summary = TaxCalculatorService.evaluateSummary(
        trips: [tripV1, tripV2, tripPersonal],
        expenses: <VehicleExpense>[],
        taxRule: customRule,
        multiVehicle: true,
      );

      // Business km = 9000, Total km = 10000
      expect(summary.businessKm, equals(9000.0));
      expect(summary.totalKm, equals(10000.0));
      // Multi-vehicle CPK claim: veh_1 (5000 * 0.91) + veh_2 (3000 * 0.91) = 4550 + 2730 = 7280.0
      expect(summary.centsPerKmClaim, equals(7280.0));
    });
  });
}
