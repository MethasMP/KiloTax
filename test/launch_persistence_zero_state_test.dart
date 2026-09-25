import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/services/vehicle/australian_vehicle_catalog.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KiloTax Production Launch - Zero-State & Local Persistence Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(r'Fresh install starts with genuine clean zero-state (0 trips, 0 expenses, $0.00 claim)', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      expect(appState.hasVehicle, isFalse);
      expect(appState.vehicles, isEmpty);
      expect(appState.trips, isEmpty);
      expect(appState.expenses, isEmpty);

      final summary = appState.taxSummary;
      expect(summary.totalKm, equals(0.0));
      expect(summary.businessKm, equals(0.0));
      expect(summary.centsPerKmClaim, equals(0.0));
      expect(summary.totalDirectDeductions, equals(0.0));
      expect(summary.highestClaim, equals(0.0));
    });

    test('Adding real vehicle and trips persists across app restarts', () async {
      final storage = await LocalStorageService.init();
      final appState1 = AppState(storageService: storage);
      await appState1.init();

      final vehicle = Vehicle(
        id: 'veh_tradie_hilux',
        make: 'Toyota',
        model: 'Hilux SR5',
        regoPlate: 'TRADIE-99',
        initialOdometer: 45200.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      await appState1.addVehicle(vehicle);

      final trip = Trip(
        id: 'trip_site_alexandria',
        vehicleId: vehicle.id,
        distanceKm: 32.5,
        date: DateTime(2026, 9, 15, 7, 30),
        purpose: 'Site inspection & quoting',
        startOdometer: 45200.0,
        endOdometer: 45232.5,
        originAddress: 'Workshop Depot',
        destinationAddress: 'Client Job Site, Alexandria',
        classification: TripClassification.business,
      );

      appState1.recordTrip(trip);

      final expense = VehicleExpense(
        id: 'exp_materials_conduit',
        vehicleId: vehicle.id,
        amount: 215.40,
        category: ExpenseCategory.toolsMaterials,
        date: DateTime(2026, 9, 15),
        notes: 'Electrical conduit and fittings',
      );

      appState1.recordExpense(expense);

      // Verify immediate live calculations in session 1
      expect(appState1.hasVehicle, isTrue);
      expect(appState1.primaryVehicle?.displayName, equals('Toyota Hilux SR5 (TRADIE-99)'));
      expect(appState1.trips.length, equals(1));
      expect(appState1.expenses.length, equals(1));
      expect(appState1.taxSummary.businessKm, equals(32.5));
      expect(appState1.taxSummary.centsPerKmClaim, closeTo(32.5 * 0.91, 0.01));
      expect(appState1.taxSummary.totalDirectDeductions, equals(215.40));

      // Simulate app restart / cold start with fresh AppState instance
      final appState2 = AppState(storageService: storage);
      await appState2.init();

      expect(appState2.hasVehicle, isTrue);
      expect(appState2.primaryVehicle?.id, equals('veh_tradie_hilux'));
      expect(appState2.primaryVehicle?.make, equals('Toyota'));
      expect(appState2.primaryVehicle?.model, equals('Hilux SR5'));
      expect(appState2.trips.length, equals(1));
      expect(appState2.trips.first.destinationAddress, equals('Client Job Site, Alexandria'));
      expect(appState2.trips.first.distanceKm, equals(32.5));
      expect(appState2.expenses.length, equals(1));
      expect(appState2.expenses.first.amount, equals(215.40));
      expect(appState2.taxSummary.centsPerKmClaim, closeTo(32.5 * 0.91, 0.01));
    });

    test('Zero mock/seed data policy: AppState contains no seedRealisticDemoData', () {
      final appState = AppState();
      // Ensure there are no unexpected default pre-filled items
      expect(appState.trips, isEmpty);
      expect(appState.expenses, isEmpty);
      expect(appState.vehicles, isEmpty);
    });

    test('Australian Vehicle Catalog delivers instant search, top tradie chips, and optional plate', () {
      // 1. Popular Tradie quick chips
      final popular = AustralianVehicleCatalog.popularTradieVehicles;
      expect(popular.length, equals(5));
      expect(popular.any((v) => v.model == 'Ranger' && v.make == 'Ford'), isTrue);
      expect(popular.any((v) => v.model == 'HiLux' && v.make == 'Toyota'), isTrue);
      expect(popular.any((v) => v.model == 'D-Max' && v.make == 'Isuzu'), isTrue);
      expect(popular.any((v) => v.model == 'Triton' && v.make == 'Mitsubishi'), isTrue);
      expect(popular.any((v) => v.model == 'HiAce' && v.make == 'Toyota'), isTrue);

      // 2. Search catalog
      final searchResults = AustralianVehicleCatalog.search('Hilux');
      expect(searchResults, isNotEmpty);
      expect(searchResults.first.make, equals('Toyota'));

      final searchVan = AustralianVehicleCatalog.search('Transit');
      expect(searchVan, isNotEmpty);
      expect(searchVan.first.vehicleType, equals(VehicleType.van));

      // 3. Optional registration plate behavior
      final vehicleNoPlate = Vehicle(
        id: 'veh_test_no_plate',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'Pending Rego',
        initialOdometer: 10000.0,
      );
      expect(vehicleNoPlate.regoPlate, equals('Pending Rego'));
      expect(vehicleNoPlate.displayName, contains('Ford Ranger'));
    });
  });
}
