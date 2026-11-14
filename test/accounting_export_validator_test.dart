import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/engine/accounting_export_validator.dart';
import 'package:kilotax/services/engine/logbook_export_service.dart';

void main() {
  group('AccountingExportValidator (Xero AU CSV Import Specification)', () {
    test('Validates clean standard Xero Manual Journal CSV correctly', () {
      final validCsv = '''
*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1
Year-End MV Apportionment,30/06/2026,Motor Vehicle Gross Fuel & Repairs (Pre-apportionment),449,BAS Excluded,-700.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Motor Vehicle Gross Rego & Insurance (Pre-apportionment),450,BAS Excluded,-300.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Allowable MV Fuel & Servicing (80.0% Logbook),449,GST on Expenses,560.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Allowable MV Rego & Insurance (80.0% Logbook),450,BAS Excluded,240.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Owner Drawings - Private Vehicle Use (20.0% Non-deductible),880,BAS Excluded,200.00,Vehicle,1TR-4DI
''';

      final result = AccountingExportValidator.validateXeroJournalCsv(validCsv);
      expect(result.isValid, isTrue, reason: result.errors.join(', '));
      expect(result.errors, isEmpty);
      expect(result.netBalance, 0.0);
      expect(result.transactionCount, 5);
    });

    test('Catches US or ISO date format inversion (Must be DD/MM/YYYY)', () {
      final invalidDateCsv = '''
*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1
Year-End MV Apportionment,2026-06-30,Motor Vehicle Gross Fuel & Repairs,449,BAS Excluded,-100.00,Vehicle,1TR-4DI
Year-End MV Apportionment,2026-06-30,Allowable MV Fuel & Servicing,449,GST on Expenses,100.00,Vehicle,1TR-4DI
''';

      final result = AccountingExportValidator.validateXeroJournalCsv(invalidDateCsv);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Invalid Australian date format')), isTrue);
    });

    test('Catches unbalanced journal (Sum != 0.00) to prevent Xero import rejection', () {
      final unbalancedCsv = '''
*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1
Year-End MV Apportionment,30/06/2026,Motor Vehicle Gross Fuel & Repairs,449,BAS Excluded,-100.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Allowable MV Fuel & Servicing,449,GST on Expenses,95.00,Vehicle,1TR-4DI
''';

      final result = AccountingExportValidator.validateXeroJournalCsv(unbalancedCsv);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Journal is unbalanced')), isTrue);
    });

    test('Catches unescaped formula injection characters', () {
      final formulaCsv = '''
*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1
Year-End MV Apportionment,30/06/2026,=CMD() Exploit,449,BAS Excluded,-100.00,Vehicle,1TR-4DI
Year-End MV Apportionment,30/06/2026,Allowable MV,449,GST on Expenses,100.00,Vehicle,1TR-4DI
''';

      final result = AccountingExportValidator.validateXeroJournalCsv(formulaCsv);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Unsanitized formula character detected')), isTrue);
    });

    test('Proves LogbookExportService generates 100% compliant Xero CSV under real conditions', () {
      final vehicle = Vehicle(
        id: 'v_test_01',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE-99',
        initialOdometer: 50000,
      );

      final summary = TaxSummary(
        totalKm: 10000,
        businessKm: 8500,
        personalKm: 1500,
        businessPercentage: 85.0,
        totalRunningExpenses: 4321.50, // Non-round decimal to test rounding plug
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 4400.0,
        logbookClaim: 3673.28,
      );

      final taxRule = const AtoTaxRule(
        financialYear: '2025-2026',
        centsPerKmRate: 0.88,
        centsPerKmMaxKm: 5000,
        carDepreciationLimit: 68108,
      );

      final csv = LogbookExportService.generateXeroManualJournalCsv(
        vehicle: vehicle,
        summary: summary,
        taxRule: taxRule,
      );

      final validation = AccountingExportValidator.validateXeroJournalCsv(csv);
      expect(validation.isValid, isTrue, reason: validation.errors.join('\n'));
      expect(validation.netBalance, 0.0);
      expect(validation.transactionCount, 5);
    });
  });
}
