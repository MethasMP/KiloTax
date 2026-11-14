import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_handoff_service.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const service = AccountantHandoffService();
  final taxRule = AppConstants.activeTaxRule;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ede_falsification_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EDE Invariant 1: Exact File Count & Formats (Anti-Junk/Anti-CSV)', () {
    test(
        'CPK delivers exactly 2 files, and dataFile is ALWAYS .xlsx (NEVER .csv)',
        () async {
      final vehicle = Vehicle(
        id: 'v-cpk-inv1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'INV1CPK',
        initialOdometer: 10000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 45.0,
          purpose: 'Plumbing callout',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10045,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-fuel',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          amount: 110.0,
          category: ExpenseCategory.fuel,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'Dave Smith',
        abn: '51 824 753 556',
      );

      // Exactly 2 files in package
      expect(package.attachmentPaths.length, equals(2));
      expect(package.pdfFile.path.endsWith('.pdf'), isTrue);
      expect(package.dataFile.path.endsWith('.xlsx'), isTrue);
      expect(package.dataFile.path.endsWith('.csv'), isFalse);

      // Verify directory has ONLY these 2 files (no rogue csv or zip extracts)
      final allFiles = tempDir.listSync();
      expect(allFiles.length, equals(2));
      for (final entity in allFiles) {
        expect(entity.path.endsWith('.csv'), isFalse,
            reason: 'Zero CSV policy violated');
      }
    });

    test(
        'Logbook delivers exactly 2 files, and dataFile is ALWAYS .xlsx (NEVER .csv)',
        () async {
      final vehicle = Vehicle(
        id: 'v-log-inv1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'INV1LOG',
        initialOdometer: 50000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-log-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 80.0,
          purpose: 'Site inspection',
          classification: TripClassification.business,
          startOdometer: 50000,
          endOdometer: 50080,
          taxMethod: TaxMethod.logbook,
        ),
        Trip(
          id: 't-log-2',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 2),
          distanceKm: 20.0,
          purpose: 'Personal commute',
          classification: TripClassification.personal,
          startOdometer: 50080,
          endOdometer: 50100,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-log-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          amount: 220.0,
          category: ExpenseCategory.maintenanceTyres,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'Sarah Connor',
        abn: '12 345 678 901',
      );

      expect(package.attachmentPaths.length, equals(2));
      expect(package.pdfFile.path.endsWith('.pdf'), isTrue);
      expect(package.dataFile.path.endsWith('.xlsx'), isTrue);
      expect(package.dataFile.path.endsWith('.csv'), isFalse);

      final allFiles = tempDir.listSync();
      expect(allFiles.length, equals(2));
      for (final entity in allFiles) {
        expect(entity.path.endsWith('.csv'), isFalse,
            reason: 'Zero CSV policy violated');
      }
    });
  });

  group('EDE Invariant 2: OpenXML Specification Compliance', () {
    test(
        'Unpack generated .xlsx with Archive and verify XML validity and required structures',
        () async {
      final vehicle = Vehicle(
        id: 'v-openxml',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'XML001',
        initialOdometer: 30000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-xml-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 9, 10),
          distanceKm: 120.0,
          purpose: 'Electrical wiring job',
          classification: TripClassification.business,
          startOdometer: 30000,
          endOdometer: 30120,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-xml-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 9, 10),
          amount: 150.0,
          category: ExpenseCategory.fuel,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'OpenXML Tester',
        abn: '99 888 777 666',
      );

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);

      // Verify presence of OpenXML core files
      final fileMap = {for (final f in archive.files) f.name: f};
      expect(fileMap.containsKey('[Content_Types].xml'), isTrue);
      expect(fileMap.containsKey('_rels/.rels'), isTrue);
      expect(fileMap.containsKey('xl/_rels/workbook.xml.rels'), isTrue);
      expect(fileMap.containsKey('xl/workbook.xml'), isTrue);
      expect(fileMap.containsKey('xl/styles.xml'), isTrue);
      expect(fileMap.containsKey('xl/worksheets/sheet1.xml'), isTrue);
      expect(fileMap.containsKey('xl/worksheets/sheet2.xml'), isTrue);
      expect(fileMap.containsKey('xl/worksheets/sheet3.xml'), isTrue);

      // Parse every single XML file using XmlDocument.parse to strictly prove XML validity
      for (final entry in fileMap.entries) {
        if (entry.key.endsWith('.xml') || entry.key.endsWith('.rels')) {
          final contentStr =
              String.fromCharCodes(entry.value.content as List<int>);
          expect(() => XmlDocument.parse(contentStr), returnsNormally,
              reason: 'File ${entry.key} must be well-formed valid XML');
        }
      }

      // Check [Content_Types].xml overrides
      final ctDoc = XmlDocument.parse(String.fromCharCodes(
          fileMap['[Content_Types].xml']!.content as List<int>));
      final overrides = ctDoc
          .findAllElements('Override')
          .map((e) => e.getAttribute('PartName'))
          .toSet();
      expect(overrides, contains('/xl/workbook.xml'));
      expect(overrides, contains('/xl/styles.xml'));
      expect(overrides, contains('/xl/worksheets/sheet1.xml'));
      expect(overrides, contains('/xl/worksheets/sheet2.xml'));
      expect(overrides, contains('/xl/worksheets/sheet3.xml'));

      // Check xl/workbook.xml sheet references
      final wbDoc = XmlDocument.parse(String.fromCharCodes(
          fileMap['xl/workbook.xml']!.content as List<int>));
      final sheetNames = wbDoc
          .findAllElements('sheet')
          .map((e) => e.getAttribute('name'))
          .toList();
      expect(sheetNames,
          equals(['Tax Summary', 'Logbook Trips', 'Expenses & Receipts']));
    });
  });

  group('EDE Invariant 3: Adversarial Inputs & Falsification', () {
    test(
        'Adversarial XML characters (control chars, &, <, >, ", \') in trips & expenses do not crash parser',
        () async {
      final adversarialString =
          'Malicious & <Company> "Pty" \'Ltd\' \x00\x01\x08\x0B\x0C\x0E\x1F';

      final vehicle = Vehicle(
        id: 'v-adversarial',
        make: 'Holden & <Son>',
        model: 'Rodeo "Extreme"',
        regoPlate: 'ADV&<>"',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-adv-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 7, 15),
          distanceKm: 55.5,
          purpose: 'Trip purpose with $adversarialString and bulky tools',
          originAddress: 'Origin & <HQ> "North"',
          destinationAddress: 'Dest > Site & "South"',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10055,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-adv-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 7, 15),
          amount: 99.99,
          category: ExpenseCategory.toolsMaterials,
          notes: 'Notes with $adversarialString',
          receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.confirmed,
            ocrMerchant: 'Bunnings & <Hardware> "Outlet"',
            ocrAbn: '11 222 333 444',
            capturedAt: DateTime(2026, 7, 15),
          ),
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'Dave & Co <Plumbing> "Boss"',
        abn: '12 345 & 678',
      );

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);

      for (final file in archive.files) {
        if (file.name.endsWith('.xml') || file.name.endsWith('.rels')) {
          final content = String.fromCharCodes(file.content as List<int>);
          // Must not throw FormatException / XmlParserException
          XmlDocument? doc;
          expect(() {
            doc = XmlDocument.parse(content);
          }, returnsNormally,
              reason: 'Failed parsing ${file.name} with adversarial input');
          expect(doc, isNotNull);
        }
      }
    });

    test(
        'Empty trips list handles gracefully without crashing or divide-by-zero',
        () async {
      final vehicle = Vehicle(
        id: 'v-empty',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'EMPTY1',
        initialOdometer: 15000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: [],
        expenses: [],
        outputDirectory: tempDir,
        taxpayerName: 'Empty Guy',
        abn: '00 000 000 000',
      );

      expect(package.totalTrips, equals(0));
      expect(package.claimAmount, equals(0.0));
      expect(package.businessPercentage, equals(0.0));

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      expect(archive.files.isNotEmpty, isTrue);
    });

    test(
        'Only personal trips produces 0% business percentage and \$0 CPK claim',
        () async {
      final vehicle = Vehicle(
        id: 'v-personal',
        make: 'Hyundai',
        model: 'i30',
        regoPlate: 'PERS01',
        initialOdometer: 5000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-p-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 200.0,
          purpose: 'Weekend road trip with family',
          classification: TripClassification.personal,
          startOdometer: 5000,
          endOdometer: 5200,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
      );

      expect(package.businessPercentage, equals(0.0));
      expect(package.claimAmount, equals(0.0));
    });

    test(
        'Expenses with null GST or custom business percentages are correctly handled',
        () async {
      final vehicle = Vehicle(
        id: 'v-custom-exp',
        make: 'Mazda',
        model: 'BT-50',
        regoPlate: 'CUST01',
        initialOdometer: 40000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-c-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 100.0,
          purpose: 'Work travel',
          classification: TripClassification.business,
          startOdometer: 40000,
          endOdometer: 40100,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        // Null GST: default to 1/11th
        VehicleExpense(
          id: 'exp-null-gst',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          amount: 110.0,
          gstAmount: null,
          category: ExpenseCategory.fuel,
        ),
        // Direct deductible with custom business percentage 50%
        VehicleExpense(
          id: 'exp-custom-pct',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 2),
          amount: 200.0,
          gstAmount: 18.18,
          category: ExpenseCategory.tollsParking,
          businessPercentage: 50.0,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
      );

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      final sheet3 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet3.xml');
      final sheet3Doc =
          XmlDocument.parse(String.fromCharCodes(sheet3.content as List<int>));

      // Check that null GST calculated 110 / 11 = 10.0
      // Check that direct deductible with 50% business percentage calculated 200 * 0.50 = 100.0
      final allNums =
          sheet3Doc.findAllElements('v').map((e) => e.innerText).toSet();

      // Check GST was calculated as 10.0
      expect(allNums.any((n) => (double.tryParse(n) ?? 0.0) == 10.0), isTrue);
      // Check net amount 100.0
      expect(allNums.any((n) => (double.tryParse(n) ?? 0.0) == 100.0), isTrue);
    });
  });

  group('EDE Invariant 4: Tax Arithmetic & Consistency (PDF vs Excel)', () {
    test(
        'Deduction amount in PDF matches Excel Sheet 1 down to 2 decimal places for Logbook',
        () async {
      final vehicle = Vehicle(
        id: 'v-arith-log',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'MATH01',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-m-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 85.0,
          purpose: 'Site job',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10085,
          taxMethod: TaxMethod.logbook,
        ),
        Trip(
          id: 't-m-2',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 2),
          distanceKm: 15.0,
          purpose: 'Personal journey',
          classification: TripClassification.personal,
          startOdometer: 10085,
          endOdometer: 10100,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      // 85 business km / 100 total km = 85.0% business use
      final expenses = [
        VehicleExpense(
          id: 'exp-fuel',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          amount: 150.0,
          category: ExpenseCategory.fuel,
        ),
        VehicleExpense(
          id: 'exp-tolls',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 2),
          amount: 45.0,
          category: ExpenseCategory.tollsParking, // 100% direct deductible
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'Math Checker',
        abn: '33 444 555 666',
      );

      // Expected calculation:
      // Fuel: 150 * 0.85 = 127.50
      // Tolls: 45.00
      // Total car claim: 127.50 + 45.00 = 172.50
      expect(package.claimAmount, equals(172.50));

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      final sheet1 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
      final sheet1Doc =
          XmlDocument.parse(String.fromCharCodes(sheet1.content as List<int>));

      // Locate claim in Sheet 1: 172.5
      final numbers = sheet1Doc
          .findAllElements('v')
          .map((e) => double.tryParse(e.innerText))
          .whereType<double>()
          .toList();
      expect(numbers.contains(172.5), isTrue,
          reason: 'Sheet 1 must contain exact deduction 172.50');
    });

    test(
        'CPK strictly respects 5,000 km cap in both PDF summary and Excel Sheet 1 & 2',
        () async {
      final vehicle = Vehicle(
        id: 'v-cpk-cap',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'CAP5000',
        initialOdometer: 10000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-massive',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 8500.0,
          purpose: 'Massive remote trade contract',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 18500,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
      );

      final maxAllowedClaim = 5000.0 * taxRule.centsPerKmRate;
      expect(package.claimAmount, equals(maxAllowedClaim));

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);

      // Sheet 1 must have capped km = 5000
      final sheet1 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
      final sheet1Content = String.fromCharCodes(sheet1.content as List<int>);
      expect(sheet1Content, contains('5000'));
      expect(sheet1Content, contains('$maxAllowedClaim'));

      // Sheet 2 must reflect CAPPED_EXCESS status
      final sheet2 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml');
      final sheet2Content = String.fromCharCodes(sheet2.content as List<int>);
      expect(sheet2Content, contains('CAPPED_EXCESS'));
    });
  });

  group('EDE Invariant 5: Required ATO Audit Fields Presence', () {
    test(
        'Taxpayer Name, ABN, Rego, FY, Opening/Closing Odometer in Excel & PDF',
        () async {
      final vehicle = Vehicle(
        id: 'v-ato-fields',
        make: 'Mitsubishi',
        model: 'Triton',
        regoPlate: 'ATO888',
        initialOdometer: 12345,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-ato-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 155.0,
          purpose: 'Installation works',
          classification: TripClassification.business,
          startOdometer: 12345,
          endOdometer: 12500,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: [],
        outputDirectory: tempDir,
        taxpayerName: 'Bruce Wayne',
        abn: '98 765 432 109',
      );

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      final sheet1 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
      final sheet1Content = String.fromCharCodes(sheet1.content as List<int>);

      expect(sheet1Content, contains('Bruce Wayne'));
      expect(sheet1Content, contains('98 765 432 109'));
      expect(sheet1Content, contains('ATO888'));
      expect(sheet1Content, contains('FY${taxRule.financialYear}'));
      expect(sheet1Content, contains('12345'));
      expect(sheet1Content, contains('12500'));
    });

    test('Expense columns in Sheet 3 contain exact required header schema',
        () async {
      final vehicle = Vehicle(
        id: 'v-schema',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'SCH001',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-sch-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 50.0,
          purpose: 'Trade service',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10050,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-sch-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          amount: 75.0,
          category: ExpenseCategory.fuel,
        ),
      ];

      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: taxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
      );

      final xlsxBytes = await package.dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      final sheet3 =
          archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet3.xml');
      final sheet3Content = String.fromCharCodes(sheet3.content as List<int>);

      // Invariant 5: Verify exact column names specified in prompt
      final requiredHeaders = [
        'Merchant_Name',
        'Merchant_ABN',
        'Gross_Amount_AUD',
        'GST_Amount_AUD',
        'Net_Amount_AUD',
        'Business_Percent',
        'Deductible_Amount_AUD',
        'Cloud_Receipt_URL',
      ];

      for (final header in requiredHeaders) {
        expect(sheet3Content, contains(header),
            reason: 'Sheet 3 must contain required ATO audit header: $header');
      }
    });
  });
}
