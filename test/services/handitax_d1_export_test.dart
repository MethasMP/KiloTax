import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/data/models/tax_summary.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/accounting_export_validator.dart';
import 'package:kiloclaim/services/engine/logbook_export_service.dart';

void main() {
  group('HandiTax & Xero D1 Action Schedule (Accountant B2B Workpaper Moat)', () {
    final testVehicle = Vehicle(
      id: 'v_test_01',
      make: 'Toyota',
      model: 'Hilux SR5',
      regoPlate: 'TRADIE-01',
      initialOdometer: 50000,
    );

    final testTaxRule = const AtoTaxRule(
      financialYear: '2025-2026',
      centsPerKmRate: 0.88,
      centsPerKmMaxKm: 5000,
      carDepreciationLimit: 68108,
    );

    final testSummary = TaxSummary(
      totalKm: 12000,
      businessKm: 10200,
      personalKm: 1800,
      businessPercentage: 85.0,
      totalRunningExpenses: 7800.0,
      totalDirectDeductions: 450.0,
      centsPerKmClaim: 4400.0,
      logbookClaim: 7080.0,
    );

    final testExpenses = [
      VehicleExpense(
        id: 'exp_1',
        vehicleId: 'v_test_01',
        amount: 3500.0,
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 3, 1),
      ),
      VehicleExpense(
        id: 'exp_2',
        vehicleId: 'v_test_01',
        amount: 1500.0,
        category: ExpenseCategory.maintenanceTyres,
        date: DateTime(2026, 3, 15),
      ),
      VehicleExpense(
        id: 'exp_3',
        vehicleId: 'v_test_01',
        amount: 1200.0,
        category: ExpenseCategory.rego,
        date: DateTime(2026, 4, 1),
      ),
      VehicleExpense(
        id: 'exp_4',
        vehicleId: 'v_test_01',
        amount: 1600.0,
        category: ExpenseCategory.insurance,
        date: DateTime(2026, 4, 15),
      ),
      VehicleExpense(
        id: 'exp_5',
        vehicleId: 'v_test_01',
        amount: 800.0,
        category: ExpenseCategory.interest,
        date: DateTime(2026, 5, 1),
      ),
      VehicleExpense(
        id: 'exp_6',
        vehicleId: 'v_test_01',
        amount: 450.0,
        category: ExpenseCategory.tollsParking,
        date: DateTime(2026, 5, 15),
      ),
    ];

    test('Generates fully compliant HandiTax & Xero D1 Action Schedule CSV with exact schema', () {
      final csv = LogbookExportService.generateHandiTaxD1ScheduleCsv(
        vehicle: testVehicle,
        summary: testSummary,
        taxRule: testTaxRule,
        expenses: testExpenses,
        taxpayerName: 'Dave Miller Plumbing',
        abn: '51 824 753 556',
        customDepreciation: 17027.0, // Div 40 depreciation
        customInterest: 800.0,
      );

      expect(csv, contains('Tax_Year,Client_Name,ABN,Vehicle_Rego,Vehicle_Description,Item_Label,Schedule_Code,Schedule_Name,Gross_Amount,Business_Percentage,Allowable_Deduction,ATO_Legislative_Reference'));

      // Validate D1A row
      expect(csv, contains('D1A,METHOD,"Logbook Method",0.00,85.00,0.00,"ITAA 1997 Subdiv 28-F (Code B)"'));

      // Validate D1B Schedules: 401, 402, 403, 404, 405
      expect(csv, contains('D1B,401,"Fuel and Oil",3500.00,85.00,2975.00,"TR 97/11 Par 18"'));
      expect(csv, contains('D1B,402,"Repairs and Maintenance",1500.00,85.00,1275.00,"TR 97/11 Par 18"'));
      expect(csv, contains('D1B,403,"Registration and Insurance",2800.00,85.00,2380.00,"TR 97/11 Par 18"'));
      expect(csv, contains('D1B,404,"Depreciation Div 40",17027.00,85.00,14472.95,"ITAA 1997 s 40-230"'));
      expect(csv, contains('D1B,405,"Interest on Car Finance",800.00,85.00,680.00,"ITAA 1997 s 8-1"'));
      expect(csv, contains('D1B,406,"Direct Work Deductions (Tolls/Parking)",450.00,100.00,450.00,"ITAA 1997 s 8-1"'));
      expect(csv, contains('D1B,TOTAL,"Total Allowable Item D1 Claim"'));

      // Validate through AccountingExportValidator
      final validation = AccountingExportValidator.validateHandiTaxD1ScheduleCsv(csv);
      expect(validation.isValid, isTrue, reason: validation.errors.join('\n'));
      expect(validation.errors, isEmpty);
      expect(validation.transactionCount, equals(8));
    });

    test('Produces fast-fill 30-second text workpaper for immediate accountant copy-paste', () {
      final text = LogbookExportService.generateHandiTaxD1ScheduleText(
        vehicle: testVehicle,
        summary: testSummary,
        taxRule: testTaxRule,
        expenses: testExpenses,
        taxpayerName: 'Dave Miller Plumbing',
        abn: '51 824 753 556',
        customDepreciation: 17027.0,
      );

      expect(text, contains('HANDITAX & XERO WORKPAPER ACTION SCHEDULE'));
      expect(text, contains('Dave Miller Plumbing'));
      expect(text, contains('TRADIE-01'));
      expect(text, contains('ATO Item D1 Method:  [ B ]'));
      expect(text, contains('85.00%'));
      expect(text, contains('401   Fuel and Oil'));
      expect(text, contains('402   Repairs and Maintenance'));
      expect(text, contains('403   Registration & Insurance'));
      expect(text, contains('404   Depreciation Div 40'));
      expect(text, contains('405   Interest on Car Finance'));
      expect(text, contains('TOTAL ITEM D1 ALLOWABLE DEDUCTION'));
    });

    test('Defends against CWE-1236 CSV formula injection in HandiTax schedule', () {
      final maliciousVehicle = Vehicle(
        id: 'v_mal',
        make: '=cmd|/c calc!A0',
        model: '@SUM(1+1)',
        regoPlate: '+REGO-99',
        initialOdometer: 10000,
      );

      final csv = LogbookExportService.generateHandiTaxD1ScheduleCsv(
        vehicle: maliciousVehicle,
        summary: testSummary,
        taxRule: testTaxRule,
        taxpayerName: '=HYPERLINK("http://evil.com")',
        abn: '-12345678',
      );

      // Verify dangerous formula triggers are sanitized with leading single quotes
      expect(csv.contains("'=HYPERLINK"), isTrue);
      expect(csv.contains("'-12345678"), isTrue);
      expect(csv.contains("'+REGO-99"), isTrue);
      expect(csv.contains("'=cmd"), isTrue);

      // Validation passes because cells are sanitized
      final validation = AccountingExportValidator.validateHandiTaxD1ScheduleCsv(csv);
      expect(validation.isValid, isTrue, reason: validation.errors.join('\n'));
    });
  });
}
