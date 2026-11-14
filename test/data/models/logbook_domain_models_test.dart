import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/logbook_period.dart';
import 'package:kilotax/data/models/annual_odometer.dart';

void main() {
  group('LogbookPeriod domain model tests', () {
    test('Calculates isStatutoryDurationMet based on 84-day rule', () {
      final start = DateTime(2025, 7, 1);
      final validEnd = start.add(const Duration(days: 84));
      final shortEnd = start.add(const Duration(days: 83));

      final validPeriod = LogbookPeriod(
        id: 'period-1',
        vehicleId: 'veh-1',
        startDate: start,
        endDate: validEnd,
        startOdometer: 10000.0,
        establishedFinancialYear: '2025-2026',
        validUntilFinancialYear: '2029-2030',
      );
      expect(validPeriod.isStatutoryDurationMet, isTrue);

      final shortPeriod = validPeriod.copyWith(endDate: shortEnd);
      expect(shortPeriod.isStatutoryDurationMet, isFalse);
    });

    test('Serializes to and from JSON cleanly', () {
      final now = DateTime(2025, 7, 1, 9, 0);
      final period = LogbookPeriod(
        id: 'lp-101',
        vehicleId: 'v-101',
        startDate: now,
        endDate: now.add(const Duration(days: 84)),
        startOdometer: 15420.5,
        endOdometer: 19850.2,
        status: LogbookStatus.certifiedValid,
        certifiedBusinessPercentage: 82.4,
        establishedFinancialYear: '2025-2026',
        validUntilFinancialYear: '2029-2030',
        digitalSignatureHash: 'sha256-signature-abc',
        certifiedAt: now.add(const Duration(days: 85)),
      );

      final json = period.toJson();
      final revived = LogbookPeriod.fromJson(json);

      expect(revived.id, period.id);
      expect(revived.vehicleId, period.vehicleId);
      expect(revived.startDate, period.startDate);
      expect(revived.endDate, period.endDate);
      expect(revived.startOdometer, period.startOdometer);
      expect(revived.endOdometer, period.endOdometer);
      expect(revived.status, LogbookStatus.certifiedValid);
      expect(revived.certifiedBusinessPercentage, 82.4);
      expect(revived.establishedFinancialYear, '2025-2026');
      expect(revived.validUntilFinancialYear, '2029-2030');
      expect(revived.digitalSignatureHash, 'sha256-signature-abc');
      expect(revived.certifiedAt, period.certifiedAt);
    });
  });

  group('AnnualVehicleOdometer domain model tests', () {
    test('Calculates totalAnnualKm correctly', () {
      final odo = AnnualVehicleOdometer(
        id: 'odo-1',
        vehicleId: 'v-1',
        financialYear: '2024-2025',
        openingDate: DateTime(2024, 7, 1),
        openingOdometer: 50000.0,
        closingDate: DateTime(2025, 6, 30),
        closingOdometer: 68500.0,
      );

      expect(odo.totalAnnualKm, 18500.0);

      final openOnly = AnnualVehicleOdometer(
        id: 'odo-1',
        vehicleId: 'v-1',
        financialYear: '2024-2025',
        openingDate: DateTime(2024, 7, 1),
        openingOdometer: 50000.0,
      );
      expect(openOnly.totalAnnualKm, isNull);
    });

    test('Serializes to and from JSON cleanly', () {
      final record = AnnualVehicleOdometer(
        id: 'odo-2025',
        vehicleId: 'veh-toyota',
        financialYear: '2024-2025',
        openingDate: DateTime(2024, 7, 1),
        openingOdometer: 42000.0,
        closingDate: DateTime(2025, 6, 30),
        closingOdometer: 57400.0,
      );

      final json = record.toJson();
      final revived = AnnualVehicleOdometer.fromJson(json);

      expect(revived.id, record.id);
      expect(revived.vehicleId, record.vehicleId);
      expect(revived.financialYear, record.financialYear);
      expect(revived.openingOdometer, 42000.0);
      expect(revived.closingOdometer, 57400.0);
      expect(revived.totalAnnualKm, 15400.0);
    });
  });
}
