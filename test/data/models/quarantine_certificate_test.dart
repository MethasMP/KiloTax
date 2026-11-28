import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/quarantine_certificate.dart';

void main() {
  group('QuarantineCertificate', () {
    test('computes quarantine statistics and ensures 100% mathematical integrity', () {
      final cert = QuarantineCertificate(
        vehicleId: 'veh-hilux-1',
        regoPlate: 'TRD-999',
        financialYear: '2024-25',
        totalOdometerKm: 12500.0,
        businessKm: 9375.0,
        quarantinedPrivateKm: 3125.0,
        businessTripsCount: 150,
        quarantinedPrivateTripsCount: 45,
        totalExpensesAud: 6500.00,
        deductibleExpensesAud: 4875.00,
        quarantinedPrivateExpensesAud: 1625.00,
        generatedAt: DateTime(2025, 7, 1, 10, 0),
      );

      expect(cert.businessPercentage, closeTo(75.0, 0.01));
      expect(cert.quarantinedKmPercentage, closeTo(25.0, 0.01));
      expect(cert.totalTripsCount, equals(195));
      expect(cert.isMathematicallySound, isTrue);
      expect(cert.auditHash, isNotEmpty);
      expect(cert.auditHash.length, equals(64)); // SHA-256 hex string
    });

    test('flags inconsistency if businessKm + quarantinedPrivateKm != totalOdometerKm', () {
      final invalidCert = QuarantineCertificate(
        vehicleId: 'veh-hilux-1',
        regoPlate: 'TRD-999',
        financialYear: '2024-25',
        totalOdometerKm: 10000.0,
        businessKm: 8000.0,
        quarantinedPrivateKm: 1000.0, // 8000 + 1000 != 10000
        businessTripsCount: 80,
        quarantinedPrivateTripsCount: 10,
        totalExpensesAud: 1000.0,
        deductibleExpensesAud: 800.0,
        quarantinedPrivateExpensesAud: 200.0,
        generatedAt: DateTime(2025, 7, 1, 10, 0),
      );

      expect(invalidCert.isMathematicallySound, isFalse);
    });
  });
}
