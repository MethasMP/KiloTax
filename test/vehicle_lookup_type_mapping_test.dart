import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/vehicle/australian_vehicle_catalog.dart';
import 'package:kilotax/services/vehicle/vehicle_lookup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VehicleLookupService & Type Mapping Tests', () {
    test('VehicleLookupResult.fromJson maps all vehicle types accurately', () {
      final suvJson = {
        'id': 'isuzu-mux-lsu',
        'make': 'Isuzu',
        'model': 'MU-X',
        'variant': 'LS-U 4x4 7-Seat SUV 3.0L',
        'type': 'suv',
        'engine': '3.0L Turbo Diesel',
        'fuel': 'Diesel',
      };
      final suvResult = VehicleLookupResult.fromJson(suvJson);
      expect(suvResult.vehicleType, equals(VehicleType.suv));
      expect(suvResult.atoCategoryLabel, equals('SUV / 4WD'));

      final uteJson = {'type': 'ute', 'make': 'Ford', 'model': 'Ranger'};
      expect(VehicleLookupResult.fromJson(uteJson).vehicleType, equals(VehicleType.ute));

      final vanJson = {'type': 'van', 'make': 'Toyota', 'model': 'HiAce'};
      expect(VehicleLookupResult.fromJson(vanJson).vehicleType, equals(VehicleType.van));

      final truckJson = {'type': 'truck', 'make': 'Isuzu', 'model': 'NPR'};
      expect(VehicleLookupResult.fromJson(truckJson).vehicleType, equals(VehicleType.truck));

      final passengerJson = {'type': 'passenger', 'make': 'Toyota', 'model': 'Corolla'};
      expect(VehicleLookupResult.fromJson(passengerJson).vehicleType, equals(VehicleType.car));

      final evJson = {'type': 'ev', 'make': 'Tesla', 'model': 'Model 3'};
      expect(VehicleLookupResult.fromJson(evJson).vehicleType, equals(VehicleType.car));

      final evSuvJson = {'type': 'ev', 'make': 'Tesla', 'model': 'Model Y'};
      expect(VehicleLookupResult.fromJson(evSuvJson).vehicleType, equals(VehicleType.suv));
    });

    test('AustralianVehicleCatalogEntry.fromLookup preserves SUV vehicleType and silhouette asset', () {
      final lookup = VehicleLookupResult(
        id: 'isuzu-mux-lsu',
        make: 'Isuzu',
        model: 'MU-X',
        variant: 'LS-U 4x4 7-Seat SUV 3.0L',
        displayName: 'Isuzu MU-X LS-U 4x4 7-Seat SUV 3.0L',
        vehicleType: VehicleType.suv,
        engineCapacity: '3.0L Turbo Diesel',
        fuelType: 'Diesel',
      );

      final entry = AustralianVehicleCatalogEntry.fromLookup(lookup);
      expect(entry.vehicleType, equals(VehicleType.suv));
      expect(entry.vehicleType.shortCategoryName, equals('SUV'));
      expect(entry.vehicleType.svgAssetPath, equals('assets/vehicles/suv.svg'));
    });
  });
}
