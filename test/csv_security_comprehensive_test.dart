import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/core/utils/csv_security.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/engine/ato_report_service.dart';
import 'package:kiloclaim/services/engine/cpk_export_service.dart';
import 'package:kiloclaim/services/engine/logbook_export_service.dart';

void main() {
  group('PR-14: Comprehensive CSV Formula Injection Sanitization', () {
    test('Neutralizes formula triggers with leading whitespace', () {
      expect(CsvSecurity.sanitizeCsvCell(' =SUM(A1:B10)'), equals("' =SUM(A1:B10)"));
      expect(CsvSecurity.sanitizeCsvCell('   +cmd|calc'), equals("'   +cmd|calc"));
      expect(CsvSecurity.sanitizeCsvCell('  -12345'), equals("'  -12345"));
      expect(CsvSecurity.sanitizeCsvCell(' @import'), equals("' @import"));
    });

    test('Neutralizes extended formula triggers (%, ;, |)', () {
      expect(CsvSecurity.sanitizeCsvCell('%0Acmd'), equals("'%0Acmd"));
      expect(CsvSecurity.sanitizeCsvCell(';cmd'), equals("';cmd"));
      expect(CsvSecurity.sanitizeCsvCell('|calc'), equals("'|calc"));
      expect(CsvSecurity.sanitizeCsvCell('  |calc'), equals("'  |calc"));
    });

    test('Escapes internal double quotes and wraps in quotes with quoteCell', () {
      expect(CsvSecurity.quoteCell('Toyota "Hilux"'), equals('"Toyota ""Hilux"""'));
      expect(CsvSecurity.quoteCell('=cmd'), equals('"\'=cmd"'));
    });

    test('Logbook export wraps fields in quotes and sanitizes extended triggers', () {
      final vehicle = Vehicle(
        id: 'v_csv_sec',
        regoPlate: '|EVIL-REGO',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 10000.0,
      );

      final trip = Trip(
        id: 't_csv_1',
        vehicleId: 'v_csv_sec',
        distanceKm: 25.0,
        date: DateTime(2026, 7, 10, 8, 30),
        purpose: ' %EVIL-PURPOSE',
        startOdometer: 10000.0,
        endOdometer: 10025.0,
        classification: TripClassification.business,
      );

      final csv = LogbookExportService.generateLogbookAuditLedgerCsv(
        vehicle: vehicle,
        trips: [trip],
      );

      expect(csv, contains('"\'|EVIL-REGO"'));
      expect(csv, contains('"\' %EVIL-PURPOSE"'));
    });

    test('CpkExportService wraps rego in quotes and sanitizes trigger', () {
      final vehicle = Vehicle(
        id: 'v_cpk_sec',
        regoPlate: ';MALICIOUS-REGO',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 10000.0,
      );

      final trip = Trip(
        id: 't_cpk_1',
        vehicleId: 'v_cpk_sec',
        distanceKm: 15.0,
        date: DateTime(2026, 7, 10, 8, 30),
        purpose: 'Tools transport',
      );

      final csv = CpkExportService.generateCpkTripLedgerCsv(
        vehicle: vehicle,
        trips: [trip],
        taxRule: AppConstants.activeTaxRule,
      );

      expect(csv, contains('"\' ;MALICIOUS-REGO"'.replaceAll('\' ;', '\';')));
    });

    test('AtoReportService wraps vehicle string fields in quotes', () {
      final vehicle = Vehicle(
        id: 'v_ato_1',
        regoPlate: '%REGOPLATE',
        make: 'Toyota',
        model: 'Corolla',
        initialOdometer: 5000.0,
      );

      final csv = AtoReportService.generateMultiVehicleBoxD1SummaryCsv(
        vehicles: [vehicle],
        tripsByVehicleId: {},
        summariesByVehicleId: {},
        taxRule: AppConstants.activeTaxRule,
      );

      expect(csv, contains('v_ato_1'));
      expect(csv, contains('\'%REGOPLATE'));
      expect(csv, contains('Toyota Corolla'));
    });
  });
}
