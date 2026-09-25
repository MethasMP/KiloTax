import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/core/utils/export_file_name_helper.dart';
import 'package:kilotax/data/models/tax_config.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/ato_report_service.dart';
import 'package:kilotax/services/engine/cpk_export_service.dart';
import 'package:kilotax/services/engine/logbook_export_service.dart';
import 'package:kilotax/services/engine/multi_vehicle_export_service.dart';

void main() {
  group('1. Dynamic File Naming & Sanitization Tests', () {
    test('buildFileName formats standard CPK and Logbook deliverable filenames', () {
      final cpkSlip = AtoReportService.generateExportFileName(
        method: 'CPK',
        financialYear: '2025-26',
        taxpayerName: 'John Smith',
        rego: '1ABC234',
        documentType: ExportFileNameHelper.boxD1LodgementSlip,
        extension: 'pdf',
      );
      expect(cpkSlip, equals('KiloTax_CPK_FY2025-26_John_Smith_1ABC234_BoxD1_Lodgement_Slip.pdf'));

      final logbookLedger = AtoReportService.generateExportFileName(
        method: 'Logbook',
        financialYear: 'FY2026-27',
        taxpayerName: 'Acme Plumbing & Gas',
        rego: 'xyz-888',
        documentType: ExportFileNameHelper.continuousOdometerLedger,
        extension: '.csv',
      );
      expect(logbookLedger, equals('KiloTax_Logbook_FY2026-27_Acme_Plumbing__Gas_XYZ888_Continuous_Odometer_Ledger.csv'));

      final xeroJournal = AtoReportService.generateExportFileName(
        method: 'Logbook',
        financialYear: '2026-27',
        taxpayerName: 'Dave',
        rego: '123',
        documentType: ExportFileNameHelper.manualJournalXero,
        extension: 'csv',
      );
      expect(xeroJournal, equals('KiloTax_Logbook_FY2026-27_Dave_123_Manual_Journal_Xero.csv'));
    });

    test('Sanitization handles edge cases, path traversal, empty input and excessive length', () {
      final sanitizedName = ExportFileNameHelper.sanitizeAlphaNumeric('../../../evil<script>Bob O\'Connor', maxLength: 20);
      expect(sanitizedName, isNot(contains('/')));
      expect(sanitizedName, isNot(contains('<')));
      expect(sanitizedName, isNot(contains('>')));
      expect(sanitizedName, isNot(contains('\'')));
      expect(sanitizedName.length, lessThanOrEqualTo(20));

      final emptyName = AtoReportService.generateExportFileName(
        method: 'CPK',
        financialYear: '2026-27',
        taxpayerName: '   ',
        rego: '',
        documentType: ExportFileNameHelper.cpkTripLedger,
        extension: 'csv',
      );
      expect(emptyName, equals('KiloTax_CPK_FY2026-27_TradieClient_VEHICLE_Trip_Ledger.csv'));
    });
  });

  group('2. Tax Software Fast-Fill Box Verification', () {
    late Vehicle cpkVehicle;
    late Vehicle logbookVehicle;
    late TaxSummary cpkSummary;
    late TaxSummary logbookSummary;

    setUp(() {
      cpkVehicle = Vehicle(
        id: 'cpk_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'HILUX-01',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      logbookVehicle = Vehicle(
        id: 'logbook_1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'RANG-99',
        initialOdometer: 50000.0,
        taxMethod: TaxMethod.logbook,
        logbookStartDate: DateTime(2026, 7, 1),
      );

      cpkSummary = TaxSummary(
        totalKm: 6000.0,
        businessKm: 5500.0,
        personalKm: 500.0,
        businessPercentage: (5500.0 / 6000.0) * 100.0,
        totalRunningExpenses: 0.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 5000.0 * 0.91,
        logbookClaim: 0.0,
        recommendedMethod: RecommendedMethod.centsPerKm,
        taxSavingsDiff: 0.0,
      );

      logbookSummary = TaxSummary(
        totalKm: 10000.0,
        businessKm: 8000.0,
        personalKm: 2000.0,
        businessPercentage: 80.0,
        totalRunningExpenses: 6000.0,
        totalDirectDeductions: 500.0,
        centsPerKmClaim: 4550.0,
        logbookClaim: (6000.0 * 0.8) + 500.0,
        recommendedMethod: RecommendedMethod.logbook,
        taxSavingsDiff: 750.0,
      );
    });

    test('CPK Lodgement Slip prepends Fast-Fill box with Box D1 Code S and software field labels', () {
      final text = CpkExportService.generateCpkLodgementSlipText(
        vehicle: cpkVehicle,
        trips: [],
        summary: cpkSummary,
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'Bob Tradie',
      );

      expect(text, contains('⚡ TAX AGENT FAST-FILL BOX'));
      expect(text, contains('Xero Tax, HandiTax, and MYOB Practice'));
      expect(text, contains('[ S ] (Cents per kilometre)'));
      expect(text, contains('5500.0 km'));
      expect(text, contains('5000.0 km (Capped @ 5,000 km per car)'));
      expect(text, contains('\$4550.00 AUD'));
      expect(text, contains('HILUX-01 (Toyota Hilux (HILUX-01))'));
    });

    test('Logbook Audit Dossier prepends Fast-Fill box with Box D1 Code B, depreciation, and 5-yr term', () {
      final text = LogbookExportService.generateLogbookAuditDossierText(
        vehicle: logbookVehicle,
        trips: [],
        expenses: [],
        summary: logbookSummary,
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'Alice Builder',
      );

      expect(text, contains('⚡ TAX AGENT FAST-FILL BOX'));
      expect(text, contains('[ B ] (Logbook method)'));
      expect(text, contains('80.00% (TR 97/11 12-wk compliant)'));
      expect(text, contains('8000.0 km / 10000.0 km'));
      expect(text, contains('BOX D1 WORK EXPENSES:  \$4800.00 AUD'));
      expect(text, contains('BOX D1 OTHER EXPENSES: \$500.00 AUD'));
      expect(text, contains('DIV 40 ASSET DEDUCT:'));
      expect(text, contains('Valid Income Years:    FY 2026 to FY 2030'));
    });
  });

  group('3. Chart of Accounts (COA) & MYOB / Xero Journal Tests', () {
    late Vehicle vehicle;
    late TaxSummary summary;
    late List<VehicleExpense> expenses;

    setUp(() {
      vehicle = Vehicle(
        id: 'v_coa',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'DMAX-77',
        initialOdometer: 20000.0,
        taxMethod: TaxMethod.logbook,
      );

      summary = TaxSummary(
        totalKm: 10000.0,
        businessKm: 7500.0,
        personalKm: 2500.0,
        businessPercentage: 75.0,
        totalRunningExpenses: 4000.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 4550.0,
        logbookClaim: 3000.0,
        recommendedMethod: RecommendedMethod.logbook,
        taxSavingsDiff: 0.0,
      );

      expenses = [
        VehicleExpense(
          id: 'e1',
          vehicleId: 'v_coa',
          category: ExpenseCategory.fuel,
          amount: 2000.0,
          date: DateTime(2026, 8, 15),
          gstAmount: 181.82,
        ),
        VehicleExpense(
          id: 'e2',
          vehicleId: 'v_coa',
          category: ExpenseCategory.rego,
          amount: 1000.0,
          date: DateTime(2026, 9, 1),
          gstAmount: 0.0,
        ),
      ];
    });

    test('Xero Manual Journal uses default COA accounts and accepts custom COA override', () {
      // Default Xero accounts: Fuel 449, Rego 450, Drawings 880
      final defaultCsv = LogbookExportService.generateXeroManualJournalCsv(
        vehicle: vehicle,
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        expenses: expenses,
      );

      expect(defaultCsv, contains('449,BAS Excluded,-2000.00,Vehicle,DMAX-77'));
      expect(defaultCsv, contains('450,BAS Excluded,-1000.00,Vehicle,DMAX-77'));
      expect(defaultCsv, contains('449,GST on Expenses,1500.00,Vehicle,DMAX-77'));
      expect(defaultCsv, contains('450,BAS Excluded,750.00,Vehicle,DMAX-77'));
      expect(defaultCsv, contains('880,BAS Excluded,750.00,Vehicle,DMAX-77'));

      // Custom COA config
      const customCoa = ChartOfAccountsConfig(
        fuelAccount: '5-1100',
        repairsAccount: '5-1120',
        regoAccount: '5-1130',
        insuranceAccount: '5-1140',
        tollsParkingAccount: '5-1150',
        drawingsAccount: '3-9999',
        platform: AccountingPlatform.xero,
      );

      final customCsv = LogbookExportService.generateXeroManualJournalCsv(
        vehicle: vehicle,
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        expenses: expenses,
        coaConfig: customCoa,
      );

      expect(customCsv, contains('5-1100,BAS Excluded,-2000.00,Vehicle,DMAX-77'));
      expect(customCsv, contains('5-1130,BAS Excluded,-1000.00,Vehicle,DMAX-77'));
      expect(customCsv, contains('3-9999,BAS Excluded,750.00,Vehicle,DMAX-77'));
    });

    test('MYOB General Journal CSV matches layout with debit/credit columns and MYOB account IDs', () {
      final myobCsv = LogbookExportService.generateMyobGeneralJournalCsv(
        vehicle: vehicle,
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        expenses: expenses,
        journalNumber: 'JRN-2026-999',
      );

      final lines = myobCsv.trim().split('\n');
      expect(lines.first, equals('JournalNumber,Date,Memo,AccountSource,AccountID,DebitAmount,CreditAmount,TaxCode,Job'));

      // Line 1: Credit fuel gross
      expect(lines[1], contains('JRN-2026-999'));
      expect(lines[1], contains('6-1400,0.00,2000.00,N-T,'));

      // Line 2: Debit deductible fuel
      expect(lines[2], contains('6-1400,1500.00,0.00,GST,'));

      // Line 3: Credit rego gross
      expect(lines[3], contains('6-1420,0.00,1000.00,N-T,'));

      // Line 4: Debit deductible rego
      expect(lines[4], contains('6-1420,750.00,0.00,N-T,'));

      // Line 5: Debit private drawings
      expect(lines[5], contains('3-1800,750.00,0.00,N-T,'));
    });
  });

  group('4. Bulky Equipment Legal Defense (Vogt 75 ATC 4073 & TR 95/34)', () {
    test('CPK Trip Ledger CSV marks bulky tools with full Vogt citation', () {
      final vehicle = Vehicle(
        id: 'v_bulky',
        make: 'Toyota',
        model: 'HiAce',
        regoPlate: 'BULK-88',
        initialOdometer: 15000.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't_bulky',
          vehicleId: 'v_bulky',
          distanceKm: 40.0,
          date: DateTime(2026, 8, 10, 7, 30),
          purpose: 'Transport heavy tool boxes and ladders to job site',
          classification: TripClassification.business,
        ),
        Trip(
          id: 't_normal',
          vehicleId: 'v_bulky',
          distanceKm: 15.0,
          date: DateTime(2026, 8, 10, 14, 0),
          purpose: 'Meet client for consultation',
          classification: TripClassification.business,
        ),
      ];

      final csv = CpkExportService.generateCpkTripLedgerCsv(
        vehicle: vehicle,
        trips: trips,
        taxRule: AppConstants.activeTaxRule,
      );

      expect(csv, contains('YES (Vogt 75 ATC 4073 / TR 95/34)'));
      expect(csv, contains('BULKY_TOOLS_TRADE_DUTY'));
      expect(csv, contains(',NO,'));
    });

    test('Section 4 of CPK and Logbook text dossiers include statutory substantiation clause', () {
      final vehicle = Vehicle(
        id: 'v_dossier',
        make: 'Ford',
        model: 'Transit',
        regoPlate: 'TRANS-11',
        initialOdometer: 0.0,
      );

      final summary = TaxSummary(
        totalKm: 100.0,
        businessKm: 80.0,
        personalKm: 20.0,
        businessPercentage: 80.0,
        totalRunningExpenses: 100.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 80.0 * 0.91,
        logbookClaim: 80.0,
        recommendedMethod: RecommendedMethod.centsPerKm,
        taxSavingsDiff: 0.0,
      );

      final cpkText = CpkExportService.generateCpkLodgementSlipText(
        vehicle: vehicle,
        trips: [],
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
      );

      expect(cpkText, contains('BULKY EQUIPMENT SUBSTANTIATION DECLARATION (ITAA 1997 s 8-1, TR 95/34 & FC OF T v VOGT)'));
      expect(cpkText, contains('STATUTORY DEFENSE UNDER VOGT\'S CASE (75 ATC 4073) & ATO TR 95/34'));
      expect(cpkText, contains('Absence of Secure Storage'));

      final logbookText = LogbookExportService.generateLogbookAuditDossierText(
        vehicle: vehicle,
        trips: [],
        expenses: [],
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
      );

      expect(logbookText, contains('BULKY EQUIPMENT SUBSTANTIATION DECLARATION (ITAA 1997 s 8-1, TR 95/34 & FC OF T v VOGT)'));
      expect(logbookText, contains('Character of Travel'));
    });
  });

  group('5. Multi-Vehicle Box D1 Aggregation (ITAA 1997 s 28-25)', () {
    late Vehicle car1;
    late Vehicle car2;
    late List<Trip> car1Trips;
    late List<Trip> car2Trips;
    late TaxSummary car1Summary;
    late TaxSummary car2Summary;

    setUp(() {
      car1 = Vehicle(
        id: 'veh_001',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: '1ABC234',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      car2 = Vehicle(
        id: 'veh_002',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: '9XYZ890',
        initialOdometer: 25000.0,
        taxMethod: TaxMethod.centsPerKm,
      );

      // Car 1: 5,420 km logged -> capped at 5,000 km = $4,550 (@ $0.91)
      car1Trips = [
        Trip(
          id: 'c1_t1',
          vehicleId: 'veh_001',
          distanceKm: 5420.0,
          date: DateTime(2026, 7, 15),
          purpose: 'Site works',
          classification: TripClassification.business,
        ),
      ];

      // Car 2: 3,200 km logged -> under 5,000 km cap = $2,912 (@ $0.91)
      car2Trips = [
        Trip(
          id: 'c2_t1',
          vehicleId: 'veh_002',
          distanceKm: 3200.0,
          date: DateTime(2026, 8, 20),
          purpose: 'Emergency plumbing repairs',
          classification: TripClassification.business,
        ),
      ];

      car1Summary = TaxSummary(
        totalKm: 5420.0,
        businessKm: 5420.0,
        personalKm: 0.0,
        businessPercentage: 100.0,
        totalRunningExpenses: 0.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 5000.0 * 0.91,
        logbookClaim: 0.0,
        recommendedMethod: RecommendedMethod.centsPerKm,
        taxSavingsDiff: 0.0,
      );

      car2Summary = TaxSummary(
        totalKm: 3200.0,
        businessKm: 3200.0,
        personalKm: 0.0,
        businessPercentage: 100.0,
        totalRunningExpenses: 0.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 3200.0 * 0.91,
        logbookClaim: 0.0,
        recommendedMethod: RecommendedMethod.centsPerKm,
        taxSavingsDiff: 0.0,
      );
    });

    test('Multi-vehicle summary text applies 5,000 km cap per car and aggregates Box D1 total', () {
      final summaryText = MultiVehicleExportService.generateCombinedMultiVehicleSlipText(
        vehicles: [car1, car2],
        tripsByVehicleId: {
          'veh_001': car1Trips,
          'veh_002': car2Trips,
        },
        summariesByVehicleId: {
          'veh_001': car1Summary,
          'veh_002': car2Summary,
        },
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'Frankie Fleet',
      );

      // Expected calculation:
      // Car 1: 5,000 * 0.91 = $4,550.00
      // Car 2: 3,200 * 0.91 = $2,912.00
      // Combined: $7,462.00
      expect(summaryText, contains('\$7462.00 AUD'));
      expect(summaryText, contains('TOTAL WORK KILOMETRES LOGGED:      8620.0 km'));
      expect(summaryText, contains('TOTAL VEHICLES CLAIMED:            2 Vehicles'));
      expect(summaryText, contains('Vehicle #1: 1ABC234 - Toyota Hilux (1ABC234)'));
      expect(summaryText, contains('Allowable Cap:       5000.0 km (Capped at 5,000 km per s 28-25)'));
      expect(summaryText, contains('\$4550.00 AUD'));
      expect(summaryText, contains('Vehicle #2: 9XYZ890 - Ford Ranger (9XYZ890)'));
      expect(summaryText, contains('Allowable Cap:       3200.0 km (Capped at 5,000 km per s 28-25)'));
      expect(summaryText, contains('\$2912.00 AUD'));
      expect(summaryText, contains('FINAL INDIVIDUAL TAX RETURN BOX D1 ENTRY: \$7462.00 AUD'));
    });

    test('Multi-vehicle CSV produces fleet breakdown with TOTALS reconciliation row', () {
      final csv = MultiVehicleExportService.generateCombinedMultiVehicleCsv(
        vehicles: [car1, car2],
        tripsByVehicleId: {
          'veh_001': car1Trips,
          'veh_002': car2Trips,
        },
        summariesByVehicleId: {
          'veh_001': car1Summary,
          'veh_002': car2Summary,
        },
        taxRule: AppConstants.activeTaxRule,
      );

      final lines = csv.trim().split('\n');
      expect(lines.first, equals('Vehicle_ID,Vehicle_Rego,Vehicle_Model,Method,Logged_Work_KM,Statutory_Capped_KM,Rate_Or_Percent,Vehicle_Deduction_AUD,Box_D1_Contribution_AUD'));
      expect(lines[1], equals('veh_001,1ABC234,Toyota Hilux,CPK,5420.00,5000.00,\$0.91/km,4550.00,4550.00'));
      expect(lines[2], equals('veh_002,9XYZ890,Ford Ranger,CPK,3200.00,3200.00,\$0.91/km,2912.00,2912.00'));
      expect(lines[3], equals('TOTALS,2_VEHICLES,COMBINED_FLEET,MULTI,8620.00,8200.00,N/A,7462.00,7462.00'));
    });
  });
}
