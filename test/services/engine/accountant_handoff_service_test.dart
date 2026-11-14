import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_handoff_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountantHandoffService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('handoff_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Case 1 (CPK) generates exactly 2 files (PDF + 2-Tab XLSX) with no fuel receipt attachments', () async {
      final vehicle = Vehicle(
        id: 'v-cpk',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANGER1',
        initialOdometer: 10000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-1',
          vehicleId: 'v-cpk',
          date: DateTime(2026, 8, 14),
          distanceKm: 25.0,
          purpose: 'Client site inspection at Mascot',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10025,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-fuel',
          vehicleId: 'v-cpk',
          date: DateTime(2026, 8, 14),
          amount: 85.0,
          category: ExpenseCategory.fuel,
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'Bob Tradie',
        abn: '98 765 432 109',
      );

      expect(package.taxMethod, TaxMethod.centsPerKm);
      expect(package.attachmentPaths.length, 2);
      expect(package.pdfFile.path.endsWith('.pdf'), isTrue);
      expect(package.dataFile.path.endsWith('.xlsx'), isTrue);
      expect(await package.pdfFile.exists(), isTrue);
      expect(await package.dataFile.exists(), isTrue);

      // Verify that CPK generates an .xlsx file that decodes as valid zip with 2 sheets
      final xlsxBytes = await package.dataFile.readAsBytes();
      final zip = ZipDecoder().decodeBytes(xlsxBytes);
      final fileNames = zip.files.map((f) => f.name).toSet();

      expect(fileNames, contains('xl/workbook.xml'));
      expect(fileNames, contains('xl/worksheets/sheet1.xml'));
      expect(fileNames, contains('xl/worksheets/sheet2.xml'));
      expect(fileNames.contains('xl/worksheets/sheet3.xml'), isFalse);

      final sheet1Xml = zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
      final sheet1Content = String.fromCharCodes(sheet1Xml.content as List<int>);
      expect(sheet1Content, contains('Bob Tradie'));
      expect(sheet1Content, contains('98 765 432 109'));
      expect(sheet1Content, contains('RANGER1'));
      expect(sheet1Content, contains('Prescribed Cents-per-km rate'));
      expect(sheet1Content, contains('Capped Kilometres'));
      expect(sheet1Content, contains('Box D1 Code S Deduction Amount'));
      expect(sheet1Content, contains('Opening Odometer'));
      expect(sheet1Content, contains('Closing Odometer'));
      expect(sheet1Content, contains('10000'));
      expect(sheet1Content, contains('10025'));

      final sheet2Xml = zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml');
      final sheet2Content = String.fromCharCodes(sheet2Xml.content as List<int>);
      expect(sheet2Content, contains('Trip_ID'));
      expect(sheet2Content, contains('Trip_Date'));
      expect(sheet2Content, contains('Start_Time'));
      expect(sheet2Content, contains('Vehicle_Rego'));
      expect(sheet2Content, contains('Origin_Address'));
      expect(sheet2Content, contains('Destination_Address'));
      expect(sheet2Content, contains('Distance_KM'));
      expect(sheet2Content, contains('ATO_Purpose_Category'));
      expect(sheet2Content, contains('Business_Purpose_Detail'));
      expect(sheet2Content, contains('Bulky_Tools_Carried'));
      expect(sheet2Content, contains('Statutory_Rate'));
      expect(sheet2Content, contains('Uncapped_Trip_Value_AUD'));
      expect(sheet2Content, contains('Cumulative_KM_Year'));
      expect(sheet2Content, contains('Cap_Status'));
      expect(sheet2Content, contains('Client site inspection at Mascot'));
      expect(sheet2Content, contains('RANGER1'));

      // Check email body mentions CPK and Division 28-C
      expect(package.emailBody, contains('Cents per Kilometre'));
      expect(package.emailBody, contains('fuel and maintenance receipts are not required'));
      expect(package.emailBody, contains('Excel Workbook: Summary & Trip Ledger'));
    });

    test('Case 2 (Logbook) generates exactly 2 files (PDF + Multi-Tab XLSX) with 3 sheets and D1 breakdown', () async {
      final vehicle = Vehicle(
        id: 'v-logbook',
        make: 'Toyota',
        model: 'HiLux SR5',
        regoPlate: 'HILUX88',
        initialOdometer: 20000,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2025, 9, 1),
      );

      final trips = [
        Trip(
          id: 't-1',
          vehicleId: 'v-logbook',
          date: DateTime(2025, 9, 2),
          distanceKm: 80.0,
          purpose: 'Commercial plumbing install at Alexandria',
          classification: TripClassification.business,
          startOdometer: 20000,
          endOdometer: 20080,
          taxMethod: TaxMethod.logbook,
          originAddress: 'Workshop',
          destinationAddress: 'Alexandria Site',
          linkedExpenseIds: ['exp-bunnings'],
        ),
        Trip(
          id: 't-2',
          vehicleId: 'v-logbook',
          date: DateTime(2025, 9, 3),
          distanceKm: 20.0,
          purpose: 'Personal commute',
          classification: TripClassification.personal,
          startOdometer: 20080,
          endOdometer: 20100,
          taxMethod: TaxMethod.logbook,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp-bunnings',
          vehicleId: 'v-logbook',
          date: DateTime(2025, 9, 2),
          amount: 250.0,
          category: ExpenseCategory.toolsMaterials,
          linkedTripId: 't-1',
          receiptPath: '/dummy/receipt.webp',
          receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.confirmed,
            capturedAt: DateTime(2025, 9, 2),
            ocrMerchant: 'Bunnings Alexandria',
          ),
        ),
        VehicleExpense(
          id: 'exp-fuel',
          vehicleId: 'v-logbook',
          date: DateTime(2025, 9, 5),
          amount: 120.0,
          category: ExpenseCategory.fuel,
          receiptPath: '/dummy/fuel.webp',
          receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.confirmed,
            capturedAt: DateTime(2025, 9, 5),
            ocrMerchant: 'BP Gladesville',
          ),
        ),
      ];

      const service = AccountantHandoffService();
      final package = await service.buildPackage(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: trips,
        expenses: expenses,
        outputDirectory: tempDir,
        taxpayerName: 'John Tradie',
        abn: '12 345 678 901',
      );

      expect(package.taxMethod, TaxMethod.logbook);
      expect(package.attachmentPaths.length, 2);
      expect(package.pdfFile.path.endsWith('.pdf'), isTrue);
      expect(package.dataFile.path.endsWith('.xlsx'), isTrue);
      expect(await package.pdfFile.exists(), isTrue);
      expect(await package.dataFile.exists(), isTrue);

      // Verify business percentage calculation (80 km out of 100 km = 80%)
      expect(package.businessPercentage, 80.0);
      expect(package.verifiedReceiptsCount, 2);

      // Verify the generated Excel workbook structure
      final xlsxBytes = await package.dataFile.readAsBytes();
      final zip = ZipDecoder().decodeBytes(xlsxBytes);
      final fileNames = zip.files.map((f) => f.name).toSet();

      expect(fileNames, contains('xl/workbook.xml'));
      expect(fileNames, contains('xl/worksheets/sheet1.xml'));
      expect(fileNames, contains('xl/worksheets/sheet2.xml'));
      expect(fileNames, contains('xl/worksheets/sheet3.xml'));

      // Check email body
      expect(package.emailBody, contains('Logbook Method'));
      expect(package.emailBody, contains('80.00%'));
      expect(package.emailBody, contains('3-Tab Excel Workbook'));

      // Check sheet 1 content for Taxpayer Name, ABN, and Odometers
      final sheet1Xml = zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
      final sheet1Content = String.fromCharCodes(sheet1Xml.content as List<int>);
      expect(sheet1Content, contains('John Tradie'));
      expect(sheet1Content, contains('12 345 678 901'));
      expect(sheet1Content, contains('Opening Odometer (KM)'));
      expect(sheet1Content, contains('Closing Odometer (KM)'));
      expect(sheet1Content, contains('20000'));
      expect(sheet1Content, contains('20100'));

      // Check sheet 3 content for updated columns, 2-way reverse verification fields and Supabase cloud receipt URLs
      final sheet3Xml = zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet3.xml');
      final sheet3Content = String.fromCharCodes(sheet3Xml.content as List<int>);
      expect(sheet3Content, contains('Merchant_Name'));
      expect(sheet3Content, contains('Merchant_ABN'));
      expect(sheet3Content, contains('Gross_Amount_AUD'));
      expect(sheet3Content, contains('GST_Amount_AUD'));
      expect(sheet3Content, contains('Net_Amount_AUD'));
      expect(sheet3Content, contains('Deductible_Amount_AUD'));
      expect(sheet3Content, contains('Bunnings Alexandria'));
      expect(sheet3Content, contains('BP Gladesville'));
      expect(sheet3Content, contains('Linked_Trip_Date'));
      expect(sheet3Content, contains('Linked_Trip_Odometer_Range'));
      expect(sheet3Content, contains('Linked_Trip_Route'));
      expect(sheet3Content, contains('Cloud_Receipt_URL'));
      expect(sheet3Content, contains('${AppConstants.supabaseUrl}/storage/v1/object/public/${AppConstants.receiptStorageBucket}/v-logbook/exp-bunnings.webp'));
      expect(sheet3Content, contains('20000 - 20080 KM'));
    });
  });
}
