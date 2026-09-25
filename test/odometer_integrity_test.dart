import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  group('Odometer Integrity Engine Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      final vehicle = Vehicle(
        id: 'test_veh',
        make: 'Toyota',
        model: 'HiAce',
        regoPlate: 'TRADIE-1',
        initialOdometer: 80000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(vehicle);
    });

    test('Starting odometer is editable freely when no trips exist', () {
      expect(appState.trips.isEmpty, true);
      expect(appState.maxAllowedStartingOdometer, isNull);

      final (isValid, errorMsg) = appState.validateStartingOdometer(82421.0);
      expect(isValid, true);
      expect(errorMsg, isNull);

      final updated = appState.updateStartingOdometer(82421.0);
      expect(updated, true);
      expect(appState.startingOdometer, 82421.0);
    });

    test('Starting odometer cannot be negative', () {
      final (isValid, errorMsg) = appState.validateStartingOdometer(-100.0);
      expect(isValid, false);
      expect(errorMsg, contains('negative'));
    });

    test('Starting odometer is bounded by first trip startOdometer once trips exist', () {
      appState.recordTrip(
        Trip(
          id: 'trip_1',
          vehicleId: 'test_veh',
          distanceKm: 25.0,
          date: DateTime.now(),
          purpose: 'Site visit',
          startOdometer: 82421.0,
          endOdometer: 82446.0,
        ),
      );

      expect(appState.maxAllowedStartingOdometer, 82421.0);

      // Editing to <= 82421 is permitted
      final (validLow, _) = appState.validateStartingOdometer(82000.0);
      expect(validLow, true);

      // Editing to > 82421 violates ATO progression and is rejected
      final (validHigh, errorMsg) = appState.validateStartingOdometer(82500.0);
      expect(validHigh, false);
      expect(errorMsg, contains('Cannot exceed first trip start odometer'));

      final success = appState.updateStartingOdometer(82500.0);
      expect(success, false);
      expect(appState.startingOdometer, 80000.0); // remains unchanged
    });

    test('Current odometer reading validation rejects lower values', () {
      appState.recordTrip(
        Trip(
          id: 'trip_1',
          vehicleId: 'test_veh',
          distanceKm: 50.0,
          date: DateTime.now(),
          purpose: 'Site visit',
          startOdometer: 80000.0,
          endOdometer: 80050.0,
        ),
      );

      expect(appState.currentOdometer, 80050.0);

      // Lower reading rejected
      final (invalid, err) = appState.validateNewCurrentOdometer(80040.0);
      expect(invalid, false);
      expect(err, contains('cannot be less than'));

      // Equal or higher reading accepted
      final (valid, _) = appState.validateNewCurrentOdometer(80060.0);
      expect(valid, true);
    });
  });

  group('Zero-Data-Loss Sign Out Guard Tests', () {
    test('Sign out with wipeLocalData=false preserves vehicle and offline trips', () async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'test_veh',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANGER-1',
        initialOdometer: 50000.0,
      );
      await appState.addVehicle(vehicle);
      appState.recordTrip(
        Trip(
          id: 'trip_offline',
          vehicleId: 'test_veh',
          distanceKm: 30.0,
          date: DateTime.now(),
          purpose: 'Emergency callout',
          startOdometer: 50000.0,
          endOdometer: 50030.0,
        ),
      );

      expect(appState.hasVehicle, true);
      expect(appState.trips.length, 1);

      // Sign out while keeping local cache on trusted device
      await appState.signOut(wipeLocalData: false);

      expect(appState.isAuthenticated, false);
      expect(appState.hasVehicle, true); // preserved
      expect(appState.trips.length, 1); // preserved
    });

    test('Sign out with wipeLocalData=true purges local data', () async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'test_veh',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANGER-1',
        initialOdometer: 50000.0,
      );
      await appState.addVehicle(vehicle);
      appState.recordTrip(
        Trip(
          id: 'trip_offline',
          vehicleId: 'test_veh',
          distanceKm: 30.0,
          date: DateTime.now(),
          purpose: 'Emergency callout',
          startOdometer: 50000.0,
          endOdometer: 50030.0,
        ),
      );

      // Full wipe sign out
      await appState.signOut(wipeLocalData: true);

      expect(appState.isAuthenticated, false);
      expect(appState.hasVehicle, false);
      expect(appState.trips.isEmpty, true);
    });
  });

  group('ATO Logbook Best Practice & Chaining Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      final vehicle = Vehicle(
        id: 'tradie_ute',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE-1',
        initialOdometer: 100000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(vehicle);
    });

    test('Gapless chaining across Work and Personal trips maintains continuous ledger', () {
      // 1. Work trip
      appState.recordTrip(
        Trip(
          id: 't1',
          vehicleId: 'tradie_ute',
          distanceKm: 20.0,
          date: DateTime.now(),
          purpose: 'Job Site A',
          startOdometer: 100000.0,
          endOdometer: 100020.0,
          classification: TripClassification.business,
        ),
      );
      expect(appState.currentOdometer, 100020.0);

      // 2. Personal trip immediately continues from 100020.0
      appState.recordTrip(
        Trip(
          id: 't2',
          vehicleId: 'tradie_ute',
          distanceKm: 15.0,
          date: DateTime.now(),
          purpose: 'Personal errands',
          startOdometer: 100020.0,
          endOdometer: 100035.0,
          classification: TripClassification.personal,
        ),
      );
      expect(appState.currentOdometer, 100035.0);

      // Verify continuous ledger integrity
      expect(appState.isOdometerChainGapless, true);
      expect(appState.taxSummary.businessKm, 20.0);
      expect(appState.taxSummary.personalKm, 15.0);
      expect(appState.taxSummary.totalKm, 35.0);
      // 20 / 35 = 57.14%
      expect(appState.taxSummary.businessPercentage, closeTo(57.14, 0.01));
    });

    test('detectOdometerGap flags unrecorded gap distance', () {
      appState.recordTrip(
        Trip(
          id: 't1',
          vehicleId: 'tradie_ute',
          distanceKm: 50.0,
          date: DateTime.now(),
          purpose: 'Job Site A',
          startOdometer: 100000.0,
          endOdometer: 100050.0,
          classification: TripClassification.business,
        ),
      );

      // Current odometer is 100050.0. User attempts to start trip at 100100.0
      final gap = appState.detectOdometerGap(100100.0);
      expect(gap, 50.0);

      // No gap when matching current odometer
      final noGap = appState.detectOdometerGap(100050.0);
      expect(noGap, 0.0);
    });

    test('fillOdometerGap seamlessly bridges gap as Personal or Work', () {
      appState.recordTrip(
        Trip(
          id: 't1',
          vehicleId: 'tradie_ute',
          distanceKm: 50.0,
          date: DateTime.now(),
          purpose: 'Job Site A',
          startOdometer: 100000.0,
          endOdometer: 100050.0,
          classification: TripClassification.business,
        ),
      );

      // Bridge the 30km gap as Personal
      appState.fillOdometerGap(
        gapEndOdometer: 100080.0,
        isBusiness: false,
        purpose: 'Weekend personal driving',
      );

      expect(appState.currentOdometer, 100080.0);
      expect(appState.trips.length, 2);
      expect(appState.trips.last.classification, TripClassification.personal);
      expect(appState.trips.last.distanceKm, 30.0);
      expect(appState.isOdometerChainGapless, true);
    });

    test('Home-to-work travel compliance warns when commuting without bulky tools (TR 2021/1)', () {
      // Home to site without bulky tools -> triggers warning
      final (isCompliant, warning) = appState.validateHomeToWorkCompliance(
        origin: 'Home - 12 Elm Street',
        destination: 'Commercial Job Site',
        purpose: 'Client / Job',
        isBulkyToolsCarried: false,
      );

      expect(isCompliant, false);
      expect(warning, contains('heavy or bulky equipment'));

      // Home to site WITH bulky tools -> compliant
      final (isCompliantWithTools, warningTools) = appState.validateHomeToWorkCompliance(
        origin: 'Home - 12 Elm Street',
        destination: 'Commercial Job Site',
        purpose: 'Work Site (Bulky Tools Carried)',
        isBulkyToolsCarried: true,
      );

      expect(isCompliantWithTools, true);
      expect(warningTools, isNull);

      // Non-home origin (e.g. Depot to Job Site) -> compliant without bulky tools
      final (isCompliantDepot, warningDepot) = appState.validateHomeToWorkCompliance(
        origin: 'Trade Depot',
        destination: 'Commercial Job Site',
        purpose: 'Client / Job',
        isBulkyToolsCarried: false,
      );

      expect(isCompliantDepot, true);
      expect(warningDepot, isNull);
    });

    test('Vehicle start and end odometer photos can be saved and verified', () {
      final now = DateTime.now();
      appState.setLogbookOdometerPhotos(
        startPhotoPath: '/photos/odo_start.jpg',
        startVerifiedAt: now,
      );

      expect(appState.primaryVehicle?.startOdometerPhotoPath, '/photos/odo_start.jpg');
      expect(appState.primaryVehicle?.startOdometerVerifiedAt, now);

      appState.setLogbookOdometerPhotos(
        endPhotoPath: '/photos/odo_end.jpg',
        endVerifiedAt: now,
      );

      expect(appState.primaryVehicle?.endOdometerPhotoPath, '/photos/odo_end.jpg');
      expect(appState.primaryVehicle?.endOdometerVerifiedAt, now);
    });
  });
}

