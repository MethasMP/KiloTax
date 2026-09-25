import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/services/engine/cpk_export_service.dart';
import 'package:kilotax/services/engine/logbook_export_service.dart';

void main() {
  group('Workstream B: Odometer Integrity Tests', () {
    late AppState appState;
    late Vehicle testVehicle;

    setUp(() {
      appState = AppState();
      testVehicle = Vehicle(
        id: 'veh_test_01',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'ODO-SEC-01',
        initialOdometer: 50000.0,
        taxMethod: TaxMethod.centsPerKm,
        startOdometerPhotoPath: '/storage/emulated/0/odometer_start.jpg',
        startOdometerVerifiedAt: DateTime(2026, 7, 1, 9, 0),
        startOdometerImageHash: 'sha256_hash_start_odometer_verified_123',
        endOdometerPhotoPath: '/storage/emulated/0/odometer_end.jpg',
        endOdometerVerifiedAt: DateTime(2026, 9, 23, 17, 30),
        endOdometerImageHash: 'sha256_hash_end_odometer_verified_456',
        toolSetupPhotoPath: '/storage/emulated/0/tools.jpg',
        toolSetupVerifiedAt: DateTime(2026, 7, 1, 9, 15),
        toolSetupImageHash: 'sha256_hash_tool_setup_789',
      );
      appState.addVehicle(testVehicle);
    });

    test('Inverted odometer rejected by model invariant and recordTrip (endOdometer < startOdometer)', () {
      expect(appState.trips.isEmpty, isTrue);

      // 1. Inverted odometer with positive distance: Trip constructor throws AssertionError in debug mode
      expect(
        () => Trip.fromJson({
          'id': 'trip_inverted_1',
          'vehicleId': testVehicle.id,
          'distanceKm': 50.0,
          'date': DateTime.now().toIso8601String(),
          'purpose': 'Site visit',
          'startOdometer': 50100.0,
          'endOdometer': 50050.0, // Inverted!
          'classification': 'business',
        }),
        throwsA(isA<AssertionError>()),
        reason: 'Trip entity enforces endOdometer >= startOdometer invariant',
      );

      // 2. Zero or negative distance trip rejected by recordTrip runtime guard
      final zeroDistanceTrip = Trip(
        id: 'trip_zero_1',
        vehicleId: testVehicle.id,
        distanceKm: 0.0,
        date: DateTime.now(),
        purpose: 'Accidental start/stop',
        startOdometer: 50100.0,
        endOdometer: 50100.0,
      );
      appState.recordTrip(zeroDistanceTrip);
      expect(appState.trips.isEmpty, isTrue,
          reason: '0-distance trip must be rejected by recordTrip');

      // 3. Valid trip is accepted
      final validTrip = Trip(
        id: 'trip_valid_1',
        vehicleId: testVehicle.id,
        distanceKm: 25.0,
        date: DateTime.now(),
        purpose: 'Valid client drive',
        startOdometer: 50000.0,
        endOdometer: 50025.0,
      );
      appState.recordTrip(validTrip);
      expect(appState.trips.length, equals(1));
      expect(appState.trips.first.id, equals('trip_valid_1'));
    });

    test('Odometer image hash and photo paths preserved when updating starting odometer', () {
      expect(appState.primaryVehicle?.initialOdometer, equals(50000.0));
      expect(appState.primaryVehicle?.startOdometerImageHash, equals('sha256_hash_start_odometer_verified_123'));
      expect(appState.primaryVehicle?.startOdometerPhotoPath, equals('/storage/emulated/0/odometer_start.jpg'));
      expect(appState.primaryVehicle?.startOdometerVerifiedAt, isNotNull);
      expect(appState.primaryVehicle?.endOdometerImageHash, equals('sha256_hash_end_odometer_verified_456'));
      expect(appState.primaryVehicle?.toolSetupImageHash, equals('sha256_hash_tool_setup_789'));

      // Update starting odometer
      final updated = appState.updateStartingOdometer(49500.0);
      expect(updated, isTrue);

      final updatedVehicle = appState.primaryVehicle!;
      expect(updatedVehicle.initialOdometer, equals(49500.0));
      // Verify all cryptographic hashes and photo metadata are strictly preserved
      expect(updatedVehicle.startOdometerImageHash, equals('sha256_hash_start_odometer_verified_123'));
      expect(updatedVehicle.startOdometerPhotoPath, equals('/storage/emulated/0/odometer_start.jpg'));
      expect(updatedVehicle.startOdometerVerifiedAt, equals(DateTime(2026, 7, 1, 9, 0)));
      expect(updatedVehicle.endOdometerImageHash, equals('sha256_hash_end_odometer_verified_456'));
      expect(updatedVehicle.endOdometerPhotoPath, equals('/storage/emulated/0/odometer_end.jpg'));
      expect(updatedVehicle.endOdometerVerifiedAt, equals(DateTime(2026, 9, 23, 17, 30)));
      expect(updatedVehicle.toolSetupImageHash, equals('sha256_hash_tool_setup_789'));
      expect(updatedVehicle.toolSetupPhotoPath, equals('/storage/emulated/0/tools.jpg'));
    });

    test('Odometer image hash and photo paths preserved when activating startLogbookPeriod', () {
      final logbookStartDate = DateTime(2026, 7, 1);
      appState.startLogbookPeriod(
        startDate: logbookStartDate,
        startingOdometer: 52000.0,
      );

      final vehicle = appState.primaryVehicle!;
      expect(vehicle.initialOdometer, equals(52000.0));
      expect(vehicle.taxMethod, equals(TaxMethod.logbook));
      expect(vehicle.logbookStartDate, equals(logbookStartDate));
      // Verify photo evidence & SHA-256 hashes survived the method change
      expect(vehicle.startOdometerImageHash, equals('sha256_hash_start_odometer_verified_123'));
      expect(vehicle.startOdometerPhotoPath, equals('/storage/emulated/0/odometer_start.jpg'));
      expect(vehicle.startOdometerVerifiedAt, equals(DateTime(2026, 7, 1, 9, 0)));
      expect(vehicle.endOdometerImageHash, equals('sha256_hash_end_odometer_verified_456'));
      expect(vehicle.toolSetupImageHash, equals('sha256_hash_tool_setup_789'));
    });
  });

  group('Workstream C: CSV Formula Injection Sanitization (CWE-1236) Tests', () {
    test('sanitizeCsvCell escapes quotes and neutralizes trigger characters (=, +, -, @, \\t, \\r)', () {
      // Test CPK exporter sanitizeCsvCell
      expect(CpkExportService.sanitizeCsvCell('=SUM(A1:A10)'), equals("'=SUM(A1:A10)"));
      expect(CpkExportService.sanitizeCsvCell('+1234567890'), equals("'+1234567890"));
      expect(CpkExportService.sanitizeCsvCell('-cmd|"/C calc"!A0'), equals("'-cmd|\"\"/C calc\"\"!A0"));
      expect(CpkExportService.sanitizeCsvCell('@cmd|foo'), equals("'@cmd|foo"));
      expect(CpkExportService.sanitizeCsvCell('\tmalicious_tab'), equals("'\tmalicious_tab"));
      expect(CpkExportService.sanitizeCsvCell('\rmalicious_cr'), equals("'\rmalicious_cr"));
      expect(CpkExportService.sanitizeCsvCell('Normal Text'), equals('Normal Text'));
      expect(CpkExportService.sanitizeCsvCell('Text with "quotes"'), equals('Text with ""quotes""'));
      expect(CpkExportService.sanitizeCsvCell(''), equals(''));

      // Test Logbook exporter sanitizeCsvCell
      expect(LogbookExportService.sanitizeCsvCell('=1+1'), equals("'=1+1"));
      expect(LogbookExportService.sanitizeCsvCell('+cmd'), equals("'+cmd"));
      expect(LogbookExportService.sanitizeCsvCell('-HYPERLINK("http://evil.com")'),
          equals("'-HYPERLINK(\"\"http://evil.com\"\")"));
      expect(LogbookExportService.sanitizeCsvCell('@IMPORTXML("http://evil.com")'),
          equals("'@IMPORTXML(\"\"http://evil.com\"\")"));
      expect(LogbookExportService.sanitizeCsvCell('\tsneaky'), equals("'\tsneaky"));
      expect(LogbookExportService.sanitizeCsvCell('\rsneaky'), equals("'\rsneaky"));
    });

    test('Formula characters sanitized in CPK CSV export', () {
      final vehicle = Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: '=CMD|rego',
        initialOdometer: 10000.0,
      );

      final trips = [
        Trip(
          id: 't_attack_1',
          vehicleId: 'v1',
          distanceKm: 30.0,
          date: DateTime(2026, 7, 10, 8, 30),
          purpose: '=cmd|"/C calc"!A0',
          startOdometer: 10000.0,
          endOdometer: 10030.0,
          classification: TripClassification.business,
          originAddress: '+123 Melbourne St, Richmond',
          destinationAddress: '@Client Office, Docklands',
        ),
      ];

      final csv = CpkExportService.generateCpkTripLedgerCsv(
        vehicle: vehicle,
        trips: trips,
        taxRule: AppConstants.activeTaxRule,
      );

      expect(csv, contains("'=CMD|rego"));
      expect(csv, contains("'+123 Melbourne St  Richmond"));
      expect(csv, contains("'@Client Office  Docklands"));
      expect(csv, contains("'=cmd|\"\"/C calc\"\"!A0"));
      // Ensure no raw formula execution starter remains unquoted
      expect(csv, isNot(contains(',=CMD|rego')));
    });

    test('Formula characters sanitized in Logbook continuous audit ledger CSV', () {
      final vehicle = Vehicle(
        id: 'v1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: '-EVIL-PLATE',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't_attack_2',
          vehicleId: 'v1',
          distanceKm: 40.0,
          date: DateTime(2026, 7, 10, 8, 30),
          purpose: '+Deliver equipment & tools',
          startOdometer: 10000.0,
          endOdometer: 10040.0,
          classification: TripClassification.business,
          originAddress: '=HYPERLINK("http://evil.com")',
          destinationAddress: '\tTabIndentedAddress',
        ),
      ];

      final csv = LogbookExportService.generateLogbookAuditLedgerCsv(
        vehicle: vehicle,
        trips: trips,
        driverName: '@Attacker Driver',
      );

      expect(csv, contains("'-EVIL-PLATE"));
      expect(csv, contains("'=HYPERLINK(\"\"http://evil.com\"\")"));
      expect(csv, contains("'\tTabIndentedAddress"));
      expect(csv, contains("'+Deliver equipment & tools"));
      expect(csv, contains("'@Attacker Driver"));
    });
  });
}
