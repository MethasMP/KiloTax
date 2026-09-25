import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/services/engine/logbook_export_service.dart';
import 'package:kilotax/core/constants/app_constants.dart';

void main() {
  group('Logbook Privacy & ATO Best Practice Export Tests', () {
    late Vehicle vehicle;
    late List<Trip> trips;

    setUp(() {
      vehicle = Vehicle(
        id: 'veh_tradie',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE-99',
        initialOdometer: 100000.0,
        taxMethod: TaxMethod.logbook,
        startOdometerPhotoPath: '/evidence/odo_day1.jpg',
        startOdometerVerifiedAt: DateTime(2026, 7, 1),
        endOdometerPhotoPath: '/evidence/odo_day84.jpg',
        endOdometerVerifiedAt: DateTime(2026, 9, 23),
      );

      trips = [
        Trip(
          id: 't_bus_1',
          vehicleId: 'veh_tradie',
          distanceKm: 25.0,
          date: DateTime(2026, 7, 1, 8, 30),
          purpose: 'Site inspection & plumbing install',
          startOdometer: 100000.0,
          endOdometer: 100025.0,
          classification: TripClassification.business,
          originAddress: 'Workshop, 12 Smith St',
          destinationAddress: 'Client Site, 45 George St',
        ),
        Trip(
          id: 't_pers_1',
          vehicleId: 'veh_tradie',
          distanceKm: 15.0,
          date: DateTime(2026, 7, 1, 18, 0),
          purpose: 'Private doctor visit & groceries',
          startOdometer: 100025.0,
          endOdometer: 100040.0,
          classification: TripClassification.personal,
          originAddress: 'Medical Centre, 88 High St',
          destinationAddress: 'Home, 1 Ocean Drive',
        ),
      ];
    });

    test('ATO CSV audit ledger masks personal trip addresses as [Private Journey]', () {
      final csv = LogbookExportService.generateLogbookAuditLedgerCsv(
        vehicle: vehicle,
        trips: trips,
        driverName: 'John Tradie',
      );

      final lines = csv.trim().split('\n');
      expect(lines.length, 3); // Header + 2 trips

      // Line 2: Business trip retains actual addresses and purpose
      expect(lines[1], contains('BUSINESS'));
      expect(lines[1], contains('Workshop  12 Smith St'));
      expect(lines[1], contains('Client Site  45 George St'));
      expect(lines[1], contains('Site inspection & plumbing install'));

      // Line 3: Personal trip MUST mask sensitive addresses
      expect(lines[2], contains('PERSONAL'));
      expect(lines[2], contains('"[Private Journey]"'));
      expect(lines[2], contains('Personal Travel'));
      expect(lines[2], isNot(contains('Medical Centre')));
      expect(lines[2], isNot(contains('1 Ocean Drive')));
      expect(lines[2], isNot(contains('Private doctor visit & groceries')));
    });

    test('Audit Dossier contains Odometer Photo Verification status and masks private purpose', () {
      final summary = TaxSummary(
        totalKm: 40.0,
        businessKm: 25.0,
        personalKm: 15.0,
        businessPercentage: 62.5,
        totalRunningExpenses: 500.0,
        totalDirectDeductions: 50.0,
        centsPerKmClaim: 0.0,
        logbookClaim: (500.0 * 0.625) + 50.0,
        recommendedMethod: RecommendedMethod.logbook,
        taxSavingsDiff: 100.0,
      );

      final dossier = LogbookExportService.generateLogbookAuditDossierText(
        vehicle: vehicle,
        trips: trips,
        expenses: [],
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'John Tradie',
      );

      expect(dossier, contains('• Day 1 Odometer Photo:'));
      expect(dossier, contains('• Day 84 Odometer Photo:'));
      expect(dossier, contains('Verified'));
      expect(dossier, contains('Private Travel'));
    });
  });
}
