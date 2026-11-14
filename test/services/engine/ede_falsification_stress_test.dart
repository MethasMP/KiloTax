import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_handoff_service.dart';
import 'package:kilotax/services/engine/openxml_workbook_builder.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';
// ignore: depend_on_referenced_packages
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ede_stress_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EDE Invariant 1: ITAA 1997 Division 28-C (Cents-per-km)', () {
    test('Falsification: CPK claim must strictly cap at 5,000 km even with massive distance', () async {
      final vehicle = Vehicle(
        id: 'v-cpk-overcap',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'OVERCAP1',
        initialOdometer: 10000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-massive',
          vehicleId: 'v-cpk-overcap',
          date: DateTime(2026, 8, 1),
          distanceKm: 15000.0,
          purpose: 'Long haul trade contract',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 25000,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
      );

      final maxAllowedClaim = 5000.0 * AppConstants.activeTaxRule.centsPerKmRate;
      expect(package.claimAmount, equals(maxAllowedClaim),
          reason: 'Claim amount MUST NOT exceed statutory 5,000 km cap');

      final bytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet2 = archive.findFile('xl/worksheets/sheet2.xml');
      expect(sheet2, isNotNull);
      final xmlContent = utf8.decode(sheet2!.content as List<int>);
      expect(xmlContent, contains('CAPPED_EXCESS'));
      expect(package.emailBody, contains('\$${maxAllowedClaim.toStringAsFixed(2)}'));
    });

    test('Falsification: CPK deliverables and email body must leak ZERO fuel or repair receipts', () async {
      final vehicle = Vehicle(
        id: 'v-cpk-leak',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'LEAK001',
        initialOdometer: 50000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-cpk',
          vehicleId: 'v-cpk-leak',
          date: DateTime(2026, 8, 10),
          distanceKm: 100.0,
          purpose: 'Service call',
          classification: TripClassification.business,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-fuel-leak',
          vehicleId: 'v-cpk-leak',
          date: DateTime(2026, 8, 10),
          amount: 145.50,
          category: ExpenseCategory.fuel,
          receiptPath: '/storage/secret_fuel_receipt.webp',
          notes: 'TOP_SECRET_FUEL_RECEIPT_LEAK',
        ),
        VehicleExpense(
          id: 'exp-repairs-leak',
          vehicleId: 'v-cpk-leak',
          date: DateTime(2026, 8, 11),
          amount: 890.00,
          category: ExpenseCategory.maintenanceTyres,
          notes: 'TOP_SECRET_TRANSMISSION_REPAIR',
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
      );

      expect(package.emailBody, isNot(contains('TOP_SECRET')));
      expect(package.emailBody, isNot(contains('145.50')));
      expect(package.emailBody, isNot(contains('890.00')));
      expect(package.emailBody, contains('Per Division 28-C, fuel and maintenance receipts are not required and are excluded.'));

      final bytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet2 = archive.findFile('xl/worksheets/sheet2.xml');
      expect(sheet2, isNotNull);
      final xml = utf8.decode(sheet2!.content as List<int>);
      expect(xml, isNot(contains('TOP_SECRET')));
      expect(xml, isNot(contains('145.50')));
      expect(xml, isNot(contains('fuel')));

      expect(package.reviewIssues.any((issue) => issue.contains('expense receipts')), isFalse);
    });

    test('Falsification: 0 km or negative distance trips edge case', () async {
      final vehicle = Vehicle(
        id: 'v-cpk-zero',
        make: 'Holden',
        model: 'Colorado',
        regoPlate: 'ZERO00',
        initialOdometer: 1000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-zero',
          vehicleId: 'v-cpk-zero',
          date: DateTime(2026, 8, 1),
          distanceKm: 0.0,
          purpose: 'Cancelled call',
          classification: TripClassification.business,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
      );

      expect(package.claimAmount, equals(0.0));
      expect(package.claimAmount.isNaN, isFalse);
      expect(package.claimAmount.isInfinite, isFalse);
    });
  });

  group('EDE Invariant 2: ITAA 1997 Subdivision 28-F (Logbook Deductions Reconciliation)', () {
    test('Falsification: Divergence between calculateLogbookClaim and evaluateSummary', () {
      final trips = [
        Trip(
          id: 't-1',
          vehicleId: 'v-1',
          date: DateTime(2025, 7, 10),
          distanceKm: 700.0,
          purpose: 'Work',
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
        Trip(
          id: 't-2',
          vehicleId: 'v-1',
          date: DateTime(2025, 7, 11),
          distanceKm: 300.0,
          purpose: 'Personal',
          classification: TripClassification.personal,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'e-fuel',
          vehicleId: 'v-1',
          date: DateTime(2025, 7, 15),
          amount: 1000.0,
          category: ExpenseCategory.fuel,
        ),
        VehicleExpense(
          id: 'e-toll',
          vehicleId: 'v-1',
          date: DateTime(2025, 8, 5),
          amount: 100.0,
          category: ExpenseCategory.tollsParking,
          businessPercentage: 100.0,
        ),
        VehicleExpense(
          id: 'e-bunnings',
          vehicleId: 'v-1',
          date: DateTime(2025, 8, 10),
          amount: 2000.0,
          category: ExpenseCategory.toolsMaterials,
        ),
      ];

      final claimViaCalc = TaxCalculatorService.calculateLogbookClaim(
        expenses: expenses,
        businessPercentage: 70.0,
      );

      final summary = TaxCalculatorService.evaluateSummary(
        trips: trips,
        expenses: expenses,
      );

      // Diagnostic check:
      // calculateLogbookClaim: (1000 + 2000) * 0.7 + 100 = 2200
      // evaluateSummary: (1000 * 0.7) + 100 + 2000 = 2800
      print('calculateLogbookClaim: $claimViaCalc');
      print('evaluateSummary.logbookClaim: ${summary.logbookClaim}');

      expect(summary.logbookClaim, equals(claimViaCalc),
          reason: 'FALSIFIED: Invariant 2 broken! calculateLogbookClaim and evaluateSummary disagree on logbook formula!');
    });

    test('Falsification: Box D1 table row sum must match total claimAmount without rogue non-car tools', () async {
      final vehicle = Vehicle(
        id: 'v-logbook-recon',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'RECON1',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 7, 1),
      );

      final trips = [
        Trip(
          id: 't-1',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 7, 10),
          distanceKm: 700.0,
          purpose: 'Job sites across Sydney',
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
        Trip(
          id: 't-2',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 7, 11),
          distanceKm: 300.0,
          purpose: 'Personal weekend drive',
          classification: TripClassification.personal,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'e-fuel',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 7, 15),
          amount: 1000.0,
          category: ExpenseCategory.fuel,
        ),
        VehicleExpense(
          id: 'e-repairs',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 8, 1),
          amount: 500.0,
          category: ExpenseCategory.maintenanceTyres,
        ),
        VehicleExpense(
          id: 'e-toll',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 8, 5),
          amount: 100.0,
          category: ExpenseCategory.tollsParking,
          businessPercentage: 100.0,
        ),
        VehicleExpense(
          id: 'e-bunnings',
          vehicleId: 'v-logbook-recon',
          date: DateTime(2025, 8, 10),
          amount: 2000.0,
          category: ExpenseCategory.toolsMaterials,
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
      );

      // In the Excel summary sheet, the Box D1 rows are:
      // Fuel (700) + Repairs (350) + Rego (0) + Interest (0) + Tolls (100) = 1150
      // Does package.claimAmount equal 1150?
      const expectedCarClaim = (1000.0 + 500.0) * 0.70 + 100.0; // 1150.0
      expect(package.claimAmount, equals(expectedCarClaim),
          reason: 'FALSIFIED: Box D1 Car Expenses claim polluted with Section 8-1 tools and materials!');
    });
  });

  group('EDE Invariant 3: OpenXML Escaping and XML 1.0 Standards', () {
    test('Falsification: XML escaping of special characters and quotation marks', () {
      final builder = OpenXmlWorkbookBuilder();
      final sheet = builder.addSheet('XML & Tests <Special>');

      sheet.addRow([
        'Tom & Jerry <Plumbing> "Fix" & \'Tools\'',
        '<script>alert("XSS")</script>',
        'A & B && C < > " \'',
        123.45,
      ]);

      final bytes = builder.buildBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final wbFile = archive.findFile('xl/workbook.xml');
      expect(wbFile, isNotNull);
      final wbXmlStr = utf8.decode(wbFile!.content as List<int>);
      expect(() => XmlDocument.parse(wbXmlStr), returnsNormally,
          reason: 'workbook.xml must be valid XML despite special chars in sheet name');

      final s1File = archive.findFile('xl/worksheets/sheet1.xml');
      expect(s1File, isNotNull);
      final s1XmlStr = utf8.decode(s1File!.content as List<int>);
      expect(() => XmlDocument.parse(s1XmlStr), returnsNormally,
          reason: 'sheet1.xml must be valid XML despite XML characters in cells');
    });

    test('Falsification: XML 1.0 Illegal Control Characters (e.g. \\x00, \\x08, \\x1B)', () {
      final builder = OpenXmlWorkbookBuilder();
      final sheet = builder.addSheet('ControlChars');

      // Check whether builder prevents XML 1.0 invalid control chars:
      final hostilePayload = 'Bunnings\x00Warehouse\x08Receipt\x1b[31m';
      sheet.addRow(['Merchant', hostilePayload]);

      final bytes = builder.buildBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final s1File = archive.findFile('xl/worksheets/sheet1.xml');
      expect(s1File, isNotNull);

      final s1XmlStr = utf8.decode(s1File!.content as List<int>);

      // In XML 1.0 W3C Section 2.2, chars 0x00, 0x08, 0x1B cannot be present in XML text
      final hasRawNullOrControl = s1XmlStr.contains('\x00') || s1XmlStr.contains('\x08') || s1XmlStr.contains('\x1b');
      expect(hasRawNullOrControl, isFalse,
          reason: 'FALSIFIED: OpenXML workbook builder allowed raw illegal XML 1.0 control characters in output XML!');
    });
  });

  group('EDE Invariant 4: Runtime Resilience & Asset Loading Boundedness', () {
    test('Falsification: Logbook PDF generation without bundled fonts handles non-Latin/Emoji gracefully', () async {
      final vehicle = Vehicle(
        id: 'v-unicode',
        make: 'Citroen & Mobius 🚗',
        model: 'Berlingo Pro',
        regoPlate: 'UNI-999',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 7, 1),
      );

      final trips = [
        Trip(
          id: 't-u1',
          vehicleId: 'v-unicode',
          date: DateTime(2025, 7, 5),
          distanceKm: 50.0,
          purpose: 'Site visit - North Sydney',
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      const service = AccountantHandoffService();

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
      );

      expect(package.pdfFile.existsSync(), isTrue);
      expect(package.pdfFile.lengthSync(), greaterThan(0));
    });
  });

  group('EDE Invariant 5: Evidence Ledger (Excel Receipts Linking & Cloud URLs)', () {
    test('Falsification: Unlinked receipts without cloud URL contradict email assertion', () async {
      final vehicle = Vehicle(
        id: 'v-evidence',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'EVID01',
        initialOdometer: 30000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 7, 1),
      );

      final trips = [
        Trip(
          id: 't-trip-1',
          vehicleId: 'v-evidence',
          date: DateTime(2025, 7, 10),
          distanceKm: 50.0,
          purpose: 'Supply run',
          classification: TripClassification.business,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        // Unlinked expense with no receipt
        VehicleExpense(
          id: 'exp-unlinked-noreceipt',
          vehicleId: 'v-evidence',
          date: DateTime(2025, 7, 12),
          amount: 25.0,
          category: ExpenseCategory.tollsParking,
          linkedTripId: null,
          receiptPath: null,
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
      );

      final bytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final s3 = archive.findFile('xl/worksheets/sheet3.xml');
      expect(s3, isNotNull);

      // Falsification check:
      // The email body explicitly states:
      // "All expenses are cross-referenced with trip references and high-resolution cloud receipt URLs."
      // BUT for exp-unlinked-noreceipt, linkedTripId is null and receiptPath is null.
      // Therefore, the statement in emailBody is false whenever unlinked expenses exist.
      final hasUnlinkedExpenses = expenses.any((e) => e.linkedTripId == null || e.receiptPath == null);
      if (hasUnlinkedExpenses) {
        expect(
          package.emailBody,
          isNot(contains('All expenses are cross-referenced with trip references and high-resolution cloud receipt URLs.')),
          reason: 'FALSIFIED: Invariant 5 broken! Email body makes false claim that ALL expenses are cross-referenced with trips and cloud receipt URLs when unlinked expenses exist!',
        );
      }
    });
  });
}
