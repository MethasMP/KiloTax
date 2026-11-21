import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_handoff_service.dart';
import 'package:kilotax/services/engine/xero_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packDir = Directory('assets/samples/accountant_sample_pack');

  setUpAll(() async {
    if (!packDir.existsSync()) {
      packDir.createSync(recursive: true);
    }

    final tempDir = Directory.systemTemp.createTempSync('kilotax_pilot_gen_');
    const service = AccountantHandoffService();
    final taxRule = AppConstants.activeTaxRule;

    // 1. CPK Sample
    final cpkVehicle = Vehicle(
      id: 'sample-hilux-cpk',
      make: 'Toyota',
      model: 'HiLux SR5',
      regoPlate: 'TRADIE-CPK',
      initialOdometer: 25000,
      taxMethod: TaxMethod.centsPerKm,
    );

    final cpkTrips = List.generate(
      40,
      (i) => Trip(
        id: 'cpk-trip-$i',
        vehicleId: cpkVehicle.id,
        date: DateTime(2026, 7, 1).add(Duration(days: i * 3)),
        distanceKm: 95.0,
        classification: TripClassification.business,
        purpose:
            'Site job: Residential rewiring & switchboard upgrade #JOB-${1000 + i}',
        startOdometer: 25000.0 + (i * 110.0),
        endOdometer: 25000.0 + (i * 110.0) + 95.0,
        taxMethod: TaxMethod.centsPerKm,
      ),
    );

    final cpkPkg = await service.buildPackage(
      vehicle: cpkVehicle,
      taxRule: taxRule,
      trips: cpkTrips,
      expenses: const [],
      outputDirectory: tempDir,
      taxpayerName: 'Jack Thompson (Sole Trader)',
      abn: '51 824 753 556',
    );

    final cpkDest =
        File('${packDir.path}/KiloTax_Accountant_Pack_CPK_Sample.xlsx');
    await cpkPkg.dataFile.copy(cpkDest.path);

    // 2. Logbook Sample
    final logVehicle = Vehicle(
      id: 'sample-ranger-logbook',
      make: 'Ford',
      model: 'Ranger Wildtrak',
      regoPlate: 'TRADIE-LOG',
      initialOdometer: 45000,
      taxMethod: TaxMethod.logbook,
    );

    final logTrips = <Trip>[];
    var currentOdo = 45000.0;
    for (int i = 0; i < 60; i++) {
      final isBiz = i % 5 != 0; // 80% business
      final dist = isBiz ? 65.0 : 20.0;
      logTrips.add(Trip(
        id: 'log-trip-$i',
        vehicleId: logVehicle.id,
        date: DateTime(2026, 7, 1).add(Duration(days: i * 2)),
        distanceKm: dist,
        classification:
            isBiz ? TripClassification.business : TripClassification.personal,
        purpose: isBiz
            ? 'Commercial plumbing contract site inspection #SITE-${200 + i}'
            : 'Personal commute / weekend travel',
        startOdometer: currentOdo,
        endOdometer: currentOdo + dist,
        taxMethod: TaxMethod.logbook,
      ));
      currentOdo += dist;
    }

    final sampleExpenses = <VehicleExpense>[
      VehicleExpense(
        id: 'exp-bunnings-1',
        vehicleId: logVehicle.id,
        date: DateTime(2026, 7, 14),
        amount: 458.50,
        category: ExpenseCategory.toolsMaterials,
        supplier: 'Bunnings Warehouse Alexandria',
        supplierAbn: '26 008 672 179',
        receiptPath: 'https://vault.kilotax.com.au/receipts/proof_bunnings_01.webp',
        sha256Hash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ),
      VehicleExpense(
        id: 'exp-bp-fuel-1',
        vehicleId: logVehicle.id,
        date: DateTime(2026, 7, 20),
        amount: 142.80,
        category: ExpenseCategory.fuel,
        supplier: 'BP Connect Mascot',
        supplierAbn: '53 004 085 616',
        receiptPath: 'https://vault.kilotax.com.au/receipts/proof_bp_fuel_02.webp',
        sha256Hash:
            'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      ),
      VehicleExpense(
        id: 'exp-service-1',
        vehicleId: logVehicle.id,
        date: DateTime(2026, 9, 10),
        amount: 890.00,
        category: ExpenseCategory.maintenanceTyres,
        supplier: 'Ultra Tune Sydney CBD',
        supplierAbn: '79 069 669 824',
        receiptPath: 'https://vault.kilotax.com.au/receipts/proof_service_03.webp',
        sha256Hash:
            'c23be59ae27e2a25629347bef9e03d488714b9e31a68985f56ac30097310e59e',
      ),
    ];

    final logPkg = await service.buildPackage(
      vehicle: logVehicle,
      taxRule: taxRule,
      trips: logTrips,
      expenses: sampleExpenses,
      outputDirectory: tempDir,
      taxpayerName: 'Jack Thompson (Sole Trader)',
      abn: '51 824 753 556',
    );

    final logDest =
        File('${packDir.path}/KiloTax_Accountant_Pack_Logbook_Sample.xlsx');
    await logPkg.dataFile.copy(logDest.path);

    final pdfDest = File('${packDir.path}/KiloTax_Tax_Summary_Sample.pdf');
    await logPkg.pdfFile.copy(pdfDest.path);

    // 3. Xero 1-Click Import Preset Sample
    final xeroCsv = XeroExportService.generateBillsCsv(
      expenses: sampleExpenses,
      vehicle: logVehicle,
    );
    final xeroDest = File('${packDir.path}/KiloTax_Xero_Bills_Import_Sample.csv');
    await xeroDest.writeAsString(xeroCsv);

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Accountant sample pack files exist and are valid PKZip archives',
      () async {
    expect(packDir.existsSync(), isTrue,
        reason: 'Sample pack directory must exist');

    final cpkExcel =
        File('${packDir.path}/KiloTax_Accountant_Pack_CPK_Sample.xlsx');
    expect(cpkExcel.existsSync(), isTrue, reason: 'CPK sample excel must exist');
    final cpkBytes = await cpkExcel.readAsBytes();
    final cpkZip = ZipDecoder().decodeBytes(cpkBytes);
    expect(cpkZip.files.any((f) => f.name == 'xl/workbook.xml'), isTrue,
        reason: 'CPK sample excel must be valid OpenXML PKZip archive');

    final logbookExcel =
        File('${packDir.path}/KiloTax_Accountant_Pack_Logbook_Sample.xlsx');
    expect(logbookExcel.existsSync(), isTrue,
        reason: 'Logbook sample excel must exist');
    final logbookBytes = await logbookExcel.readAsBytes();
    final logbookZip = ZipDecoder().decodeBytes(logbookBytes);
    expect(logbookZip.files.any((f) => f.name == 'xl/workbook.xml'), isTrue,
        reason: 'Logbook sample excel must be valid OpenXML PKZip archive');

    final pdfSummary = File('${packDir.path}/KiloTax_Tax_Summary_Sample.pdf');
    expect(pdfSummary.existsSync(), isTrue, reason: 'PDF summary must exist');
    expect(await pdfSummary.length(), greaterThan(1000),
        reason: 'PDF summary must contain valid PDF document structure');

    final xeroSampleCsv =
        File('${packDir.path}/KiloTax_Xero_Bills_Import_Sample.csv');
    expect(xeroSampleCsv.existsSync(), isTrue,
        reason: 'Xero sample CSV must exist');
    final xeroLines = (await xeroSampleCsv.readAsString()).trim().split('\n');
    expect(xeroLines.first, contains('*ContactName,*InvoiceNumber,*InvoiceDate'));

    final guideFile = File('ACCOUNTANT_PILOT_GUIDE.md');
    expect(guideFile.existsSync(), isTrue,
        reason: 'ACCOUNTANT_PILOT_GUIDE.md must exist in root');
    final guideContent = await guideFile.readAsString();
    expect(guideContent, contains('ITAA 1997 Div 28'));
    expect(guideContent, contains('HandiTax'));
    expect(guideContent, contains('Xero'));
  });
}
