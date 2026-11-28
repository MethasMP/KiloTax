import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/vehicle/vehicle_classification_engine.dart';
import 'package:kiloclaim/data/models/vehicle.dart';

void main() {
  group('VehicleClassificationEngine Tests', () {
    test('correctly identifies commercial vehicles with payload over 1000kg', () {
      final uteOver1T = Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'HiLux Single Cab',
        year: 2024,
        payloadKg: 1105,
        taxMethod: TaxMethod.actualExpenses,
      );
      expect(VehicleClassificationEngine.isOverOneTonnePayload(uteOver1T), isTrue);
      expect(VehicleClassificationEngine.isEligibleForCpk(uteOver1T), isFalse);
      expect(VehicleClassificationEngine.isCarForTaxPurposes(uteOver1T), isFalse);
      expect(VehicleClassificationEngine.allowedTaxMethods(uteOver1T), equals([TaxMethod.actualExpenses]));
    });

    test('correctly identifies standard passenger cars under 1000kg payload', () {
      final passengerCar = Vehicle(
        id: 'v2',
        make: 'Toyota',
        model: 'Corolla',
        year: 2023,
        payloadKg: 450,
        taxMethod: TaxMethod.centsPerKm,
      );
      expect(VehicleClassificationEngine.isOverOneTonnePayload(passengerCar), isFalse);
      expect(VehicleClassificationEngine.isEligibleForCpk(passengerCar), isTrue);
      expect(VehicleClassificationEngine.isCarForTaxPurposes(passengerCar), isTrue);
      expect(
        VehicleClassificationEngine.allowedTaxMethods(passengerCar),
        containsAll([TaxMethod.centsPerKm, TaxMethod.logbook]),
      );
    });

    test('classifies vehicle exactly at 1000kg payload as commercial vehicle (>1t cap under ITAA 1997 s 995-1)', () {
      final boundaryUte = Vehicle(
        id: 'v3',
        make: 'Ford',
        model: 'Ranger Super Cab',
        year: 2024,
        payloadKg: 1000,
        taxMethod: TaxMethod.actualExpenses,
      );
      expect(VehicleClassificationEngine.isOverOneTonnePayload(boundaryUte), isTrue);
      expect(VehicleClassificationEngine.isEligibleForCpk(boundaryUte), isFalse);
      expect(VehicleClassificationEngine.isCarForTaxPurposes(boundaryUte), isFalse);
      expect(VehicleClassificationEngine.disqualificationReason(boundaryUte), contains('1,000 kg'));
    });

    test('treats vehicle with 9 or more passenger seating capacity as non-car', () {
      final miniBus = Vehicle(
        id: 'v4',
        make: 'Toyota',
        model: 'HiAce Commuter',
        year: 2022,
        seatingCapacity: 12,
        payloadKg: 950,
        taxMethod: TaxMethod.actualExpenses,
      );
      expect(VehicleClassificationEngine.isCarForTaxPurposes(miniBus), isFalse);
      expect(VehicleClassificationEngine.isEligibleForCpk(miniBus), isFalse);
      expect(VehicleClassificationEngine.disqualificationReason(miniBus), contains('9 or more passengers'));
    });

    test('handles vehicles with null payload and seating capacity gracefully based on vehicleType fallback', () {
      final truck = Vehicle(
        id: 'v5',
        make: 'Isuzu',
        model: 'N-Series',
        year: 2021,
        vehicleType: VehicleType.truck,
      );
      expect(VehicleClassificationEngine.isEligibleForCpk(truck), isFalse);
      expect(VehicleClassificationEngine.isCarForTaxPurposes(truck), isFalse);

      final carDefault = Vehicle(
        id: 'v6',
        make: 'Mazda',
        model: '3',
        year: 2022,
      );
      expect(VehicleClassificationEngine.isEligibleForCpk(carDefault), isTrue);
      expect(VehicleClassificationEngine.isCarForTaxPurposes(carDefault), isTrue);
    });
  });
}
