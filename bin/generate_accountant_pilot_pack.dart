import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_handoff_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('assets/samples/accountant_sample_pack');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final tempDir = Directory.systemTemp.createTempSync('kilotax_pilot_gen_');
  const service = AccountantHandoffService();
  final taxRule = AppConstants.activeTaxRule;

  print('📦 Generating Accountant Pilot Pack Samples...');

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
      purpose: 'Site job: Residential rewiring & switchboard upgrade #JOB-${1000 + i}',
      startOdometer: 25000 + (i * 110),
      endOdometer: 25000 + (i * 110) + 95,
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

  final cpkDest = File('${outDir.path}/KiloTax_Accountant_Pack_CPK_Sample.xlsx');
  await cpkPkg.dataFile.copy(cpkDest.path);
  print('✅ Generated: ${cpkDest.path}');

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
  var currentOdo = 45000;
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
      endOdometer: currentOdo + dist.toInt(),
      taxMethod: TaxMethod.logbook,
    ));
    currentOdo += dist.toInt();
  }

  final sampleExpenses = [
    VehicleExpense(
      id: 'exp-bunnings-1',
      vehicleId: logVehicle.id,
      date: DateTime(2026, 7, 14),
      amount: 458.50,
      category: ExpenseCategory.toolsMaterials,
      vendor: 'Bunnings Warehouse Alexandria',
      merchantAbn: '26 008 672 179',
      cloudReceiptUrl: 'https://vault.kilotax.com.au/receipts/proof_bunnings_01.webp',
      auditEvidenceId: 'AUDIT-BNG-882194',
      imageSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    ),
    VehicleExpense(
      id: 'exp-bp-fuel-1',
      vehicleId: logVehicle.id,
      date: DateTime(2026, 7, 20),
      amount: 142.80,
      category: ExpenseCategory.fuel,
      vendor: 'BP Connect Mascot',
      merchantAbn: '53 004 085 616',
      cloudReceiptUrl: 'https://vault.kilotax.com.au/receipts/proof_bp_fuel_02.webp',
      auditEvidenceId: 'AUDIT-BP-102941',
      imageSha256: 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
    ),
    VehicleExpense(
      id: 'exp-service-1',
      vehicleId: logVehicle.id,
      date: DateTime(2026, 9, 10),
      amount: 890.00,
      category: ExpenseCategory.maintenance,
      vendor: 'Ultra Tune Sydney CBD',
      merchantAbn: '79 069 669 824',
      cloudReceiptUrl: 'https://vault.kilotax.com.au/receipts/proof_service_03.webp',
      auditEvidenceId: 'AUDIT-ULT-771239',
      imageSha256: 'c23be59ae27e2a25629347bef9e03d488714b9e31a68985f56ac30097310e59e',
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
      File('${outDir.path}/KiloTax_Accountant_Pack_Logbook_Sample.xlsx');
  await logPkg.dataFile.copy(logDest.path);
  print('✅ Generated: ${logDest.path}');

  final pdfDest = File('${outDir.path}/KiloTax_Tax_Summary_Sample.pdf');
  await logPkg.pdfFile.copy(pdfDest.path);
  print('✅ Generated: ${pdfDest.path}');

  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  print('🎉 Accountant Pilot Pack generation complete!');
}
