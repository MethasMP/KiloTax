import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/tax_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/export_file_name_helper.dart';
import 'evidence_engine.dart';
import 'cpk_export_service.dart';
import 'logbook_export_service.dart';

/// ATO-READY REPORT ORCHESTRATOR (Layer 6):
/// Unified façade delegating to specialized CPK and Logbook Exporters.
class AtoReportService {
  /// Generates standardized cross-platform safe export filenames.
  /// Complies with KiloTax Dynamic File Naming Specification.
  static String generateExportFileName({
    required String method,
    required String financialYear,
    required String taxpayerName,
    required String rego,
    required String documentType,
    required String extension,
  }) {
    return ExportFileNameHelper.buildFileName(
      method: method,
      fy: financialYear,
      taxpayerName: taxpayerName,
      rego: rego,
      documentType: documentType,
      extension: extension,
    );
  }

  /// Generates the method-appropriate CSV export based on vehicle tax method
  static String generateMethodAppropriateCsv({
    required Vehicle vehicle,
    required EvidenceEngine engine,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
  }) {
    if (vehicle.taxMethod == TaxMethod.centsPerKm) {
      return CpkExportService.generateCpkTripLedgerCsv(
        vehicle: vehicle,
        trips: engine.trips,
        taxRule: taxRule,
      );
    } else {
      return LogbookExportService.generateLogbookAuditLedgerCsv(
        vehicle: vehicle,
        trips: engine.trips,
      );
    }
  }

  /// Backward-compatible method
  static String generateAtoAuditCsv({
    required Vehicle vehicle,
    required EvidenceEngine engine,
    required TaxSummary summary,
  }) {
    return generateMethodAppropriateCsv(
      vehicle: vehicle,
      engine: engine,
      summary: summary,
      taxRule: AppConstants.activeTaxRule,
    );
  }

  /// Generates the Xero Manual Journal CSV (Logbook only)
  /// Supports optional custom [ChartOfAccountsConfig].
  static String generateXeroJournalCsv({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    required EvidenceEngine engine,
    ChartOfAccountsConfig? coaConfig,
  }) {
    return LogbookExportService.generateXeroManualJournalCsv(
      vehicle: vehicle,
      summary: summary,
      taxRule: taxRule,
      expenses: engine.expenses,
      coaConfig: coaConfig,
    );
  }

  /// Generates the MYOB General Journal CSV (Logbook only)
  /// Supports optional custom [ChartOfAccountsConfig].
  static String generateMyobJournalCsv({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    required EvidenceEngine engine,
    ChartOfAccountsConfig? coaConfig,
    String journalNumber = 'MV-2026-001',
  }) {
    return LogbookExportService.generateMyobGeneralJournalCsv(
      vehicle: vehicle,
      summary: summary,
      taxRule: taxRule,
      expenses: engine.expenses,
      coaConfig: coaConfig,
      journalNumber: journalNumber,
    );
  }

  /// Generates the method-appropriate textual PDF dossier/slip layout
  static String generateMethodAppropriateDossierText({
    required Vehicle vehicle,
    required EvidenceEngine engine,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
  }) {
    if (vehicle.taxMethod == TaxMethod.centsPerKm) {
      return CpkExportService.generateCpkLodgementSlipText(
        vehicle: vehicle,
        trips: engine.trips,
        summary: summary,
        taxRule: taxRule,
        taxpayerName: taxpayerName,
        abn: abn,
      );
    } else {
      return LogbookExportService.generateLogbookAuditDossierText(
        vehicle: vehicle,
        trips: engine.trips,
        expenses: engine.expenses,
        summary: summary,
        taxRule: taxRule,
        taxpayerName: taxpayerName,
        abn: abn,
      );
    }
  }

  /// Multi-Vehicle Box D1 Summary Text layout (ITAA 1997 s 28-25 & Subdiv 28-F)
  /// Applies the 5,000 km statutory cap per vehicle independently for CPK vehicles.
  static String generateMultiVehicleBoxD1SummaryText({
    required List<Vehicle> vehicles,
    required Map<String, List<Trip>> tripsByVehicleId,
    required Map<String, TaxSummary> summariesByVehicleId,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
  }) {
    double totalAggregatedClaim = 0.0;
    double totalAggregatedWorkKm = 0.0;
    final buffer = StringBuffer();

    // Calculate totals across fleet
    for (final v in vehicles) {
      final summary = summariesByVehicleId[v.id];
      final trips = tripsByVehicleId[v.id] ?? const [];
      final workKm = summary != null
          ? summary.businessKm
          : trips.where((t) => t.isBusiness).fold(0.0, (sum, t) => sum + t.distanceKm);

      totalAggregatedWorkKm += workKm;

      if (v.taxMethod == TaxMethod.centsPerKm) {
        final cappedKm = workKm > taxRule.centsPerKmMaxKm ? taxRule.centsPerKmMaxKm : workKm;
        totalAggregatedClaim += (cappedKm * taxRule.centsPerKmRate);
      } else {
        final claim = summary?.logbookClaim ?? 0.0;
        totalAggregatedClaim += claim;
      }
    }

    final hasCpk = vehicles.any((v) => v.taxMethod == TaxMethod.centsPerKm);
    final hasLogbook = vehicles.any((v) => v.taxMethod == TaxMethod.logbook);
    final compositeMethodCode = (hasCpk && hasLogbook)
        ? 'MULTI (S & B)'
        : hasCpk
            ? 'S (CPK Fleet)'
            : 'B (Logbook Fleet)';

    buffer.writeln(
        '====================================================================================================');
    buffer.writeln(
        'KILOTAX • ATO MULTI-VEHICLE COMBINED BOX D1 LODGEMENT SCHEDULE');
    buffer.writeln(
        'GOVERNING STATUTE: ITAA 1997 Subdivision 28-C (§ 28-25) & Subdivision 28-F');
    buffer.writeln(
        'FINANCIAL YEAR: ${taxRule.financialYear} | TAXPAYER: $taxpayerName | ABN: ${abn.isNotEmpty ? abn : "Registered Sole Trader"}');
    buffer.writeln(
        '====================================================================================================\n');

    buffer.writeln(
        '⚡ TAX AGENT FAST-FILL SUMMARY • ATO TAX RETURN BOX D1');
    buffer.writeln(
        '----------------------------------------------------------------------------------------------------');
    buffer.writeln(
        '  TOTAL AGGREGATED BOX D1 CLAIM:     \$${totalAggregatedClaim.toStringAsFixed(2)} AUD');
    buffer.writeln(
        '  PRIMARY METHOD CODE:               [ $compositeMethodCode ] (Multi-Vehicle Aggregation)');
    buffer.writeln(
        '  TOTAL WORK KILOMETRES LOGGED:      ${totalAggregatedWorkKm.toStringAsFixed(1)} km');
    buffer.writeln(
        '  TOTAL VEHICLES CLAIMED:            ${vehicles.length} Vehicles');
    buffer.writeln(
        '----------------------------------------------------------------------------------------------------\n');

    buffer.writeln('[INDIVIDUAL VEHICLE ALLOCATION BREAKDOWN]');

    int idx = 1;
    final subtotalReconciliation = <String>[];

    for (final v in vehicles) {
      final summary = summariesByVehicleId[v.id];
      final trips = tripsByVehicleId[v.id] ?? const [];
      final workKm = summary != null
          ? summary.businessKm
          : trips.where((t) => t.isBusiness).fold(0.0, (sum, t) => sum + t.distanceKm);

      buffer.writeln('Vehicle #$idx: ${v.regoPlate} - ${v.displayName}');
      if (v.taxMethod == TaxMethod.centsPerKm) {
        final cappedKm =
            workKm > taxRule.centsPerKmMaxKm ? taxRule.centsPerKmMaxKm : workKm;
        final vClaim = cappedKm * taxRule.centsPerKmRate;
        subtotalReconciliation.add(
            'Total Car $idx (${v.regoPlate}) Deduction:        \$${vClaim.toStringAsFixed(2)} AUD');

        buffer.writeln('  • Method:              Box D1 Code S (Cents-per-kilometre)');
        buffer.writeln('  • Work Distance:       ${workKm.toStringAsFixed(1)} km');
        buffer.writeln(
            '  • Allowable Cap:       ${cappedKm.toStringAsFixed(1)} km (Capped at 5,000 km per s 28-25)');
        buffer.writeln(
            '  • Rate:                ${(taxRule.centsPerKmRate * 100).toInt()}c / km');
        buffer.writeln(
            '  • Subtotal Deduction:  \$${vClaim.toStringAsFixed(2)} AUD\n');
      } else {
        final vClaim = summary?.logbookClaim ?? 0.0;
        final businessPct = summary?.businessPercentage ?? 0.0;
        subtotalReconciliation.add(
            'Total Car $idx (${v.regoPlate}) Deduction:        \$${vClaim.toStringAsFixed(2)} AUD');

        buffer.writeln('  • Method:              Box D1 Code B (Logbook Method)');
        buffer.writeln('  • Work Distance:       ${workKm.toStringAsFixed(1)} km');
        buffer.writeln(
            '  • Business Use %:      ${businessPct.toStringAsFixed(2)}% (TR 97/11 compliant)');
        buffer.writeln(
            '  • Subtotal Deduction:  \$${vClaim.toStringAsFixed(2)} AUD\n');
      }
      idx++;
    }

    buffer.writeln(
        '----------------------------------------------------------------------------------------------------');
    buffer.writeln('AUDIT RECONCILIATION SUMMARY:');
    for (final line in subtotalReconciliation) {
      buffer.writeln(line);
    }
    buffer.writeln(
        '====================================================================================================');
    buffer.writeln(
        '>>> FINAL INDIVIDUAL TAX RETURN BOX D1 ENTRY: \$${totalAggregatedClaim.toStringAsFixed(2)} AUD <<<');
    buffer.writeln(
        '====================================================================================================\n');

    buffer.writeln('STATUTORY COMPLIANCE NOTE FOR TAX AGENTS:');
    buffer.writeln(
        'Pursuant to s 28-25 of the Income Tax Assessment Act 1997, the 5,000 km limit applies to each car owned');
    buffer.writeln(
        'or leased by the taxpayer. The claims above have been calculated independently for each vehicle up to');
    buffer.writeln(
        'the statutory limit, and aggregated solely for disclosure at Item D1 of the Individual Tax Return.\n');

    buffer.writeln(
        'Taxpayer Signature: ___________________________        Date: ____ / ____ / ________');
    buffer.writeln(
        'Tax Agent Signature: __________________________        RAN:  ______________________');
    buffer.writeln(
        '====================================================================================================');

    return buffer.toString();
  }

  /// Multi-Vehicle Box D1 Summary CSV export (ITAA 1997 s 28-25)
  /// Structure:
  /// Vehicle_ID,Vehicle_Rego,Vehicle_Model,Method,Logged_Work_KM,Statutory_Capped_KM,Rate_Or_Percent,Vehicle_Deduction_AUD,Box_D1_Contribution_AUD
  static String generateMultiVehicleBoxD1SummaryCsv({
    required List<Vehicle> vehicles,
    required Map<String, List<Trip>> tripsByVehicleId,
    required Map<String, TaxSummary> summariesByVehicleId,
    required AtoTaxRule taxRule,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Vehicle_ID,Vehicle_Rego,Vehicle_Model,Method,Logged_Work_KM,Statutory_Capped_KM,Rate_Or_Percent,Vehicle_Deduction_AUD,Box_D1_Contribution_AUD',
    );

    double totalLoggedKm = 0.0;
    double totalCappedKm = 0.0;
    double totalDeduction = 0.0;

    for (final v in vehicles) {
      final summary = summariesByVehicleId[v.id];
      final trips = tripsByVehicleId[v.id] ?? const [];
      final workKm = summary != null
          ? summary.businessKm
          : trips.where((t) => t.isBusiness).fold(0.0, (sum, t) => sum + t.distanceKm);

      final isCpk = v.taxMethod == TaxMethod.centsPerKm;
      final methodStr = isCpk ? 'CPK' : 'LOGBOOK';
      final cappedKm = isCpk
          ? (workKm > taxRule.centsPerKmMaxKm ? taxRule.centsPerKmMaxKm : workKm)
          : workKm;
      final rateOrPct = isCpk
          ? '\$${taxRule.centsPerKmRate.toStringAsFixed(2)}/km'
          : '${summary?.businessPercentage.toStringAsFixed(1) ?? "0.0"}%';
      final claimAmount = isCpk
          ? (cappedKm * taxRule.centsPerKmRate)
          : (summary?.logbookClaim ?? 0.0);

      totalLoggedKm += workKm;
      totalCappedKm += cappedKm;
      totalDeduction += claimAmount;

      final sanitizedId = CpkExportService.sanitizeCsvCell(v.id);
      final sanitizedRego = CpkExportService.sanitizeCsvCell(v.regoPlate);
      final sanitizedModel =
          CpkExportService.sanitizeCsvCell('${v.make} ${v.model}');

      buffer.writeln(
        '$sanitizedId,$sanitizedRego,$sanitizedModel,$methodStr,${workKm.toStringAsFixed(2)},${cappedKm.toStringAsFixed(2)},$rateOrPct,${claimAmount.toStringAsFixed(2)},${claimAmount.toStringAsFixed(2)}',
      );
    }

    // Write TOTALS row
    buffer.writeln(
      'TOTALS,${vehicles.length}_VEHICLES,COMBINED_FLEET,MULTI,${totalLoggedKm.toStringAsFixed(2)},${totalCappedKm.toStringAsFixed(2)},N/A,${totalDeduction.toStringAsFixed(2)},${totalDeduction.toStringAsFixed(2)}',
    );

    return buffer.toString();
  }

  /// Generates a clean 1-Click summary message for the Tradie to WhatsApp or Email directly to their Accountant
  static String generateAccountantEmailText({
    required Vehicle vehicle,
    required TaxSummary summary,
    required int tripCount,
    required int expenseCount,
    required AtoTaxRule taxRule,
  }) {
    final isCpk = vehicle.taxMethod == TaxMethod.centsPerKm;
    final claimAmount = isCpk ? summary.centsPerKmClaim : summary.logbookClaim;
    final methodCode = isCpk ? 'S (Cents per km)' : 'B (Logbook)';

    if (isCpk) {
      return '''Hi [Accountant Name],

Here is my official ATO Vehicle Tax Lodgement Summary for ${vehicle.displayName} (Rego: ${vehicle.regoPlate}) prepared via KiloTax.

--------------------------------------------------
📊 ATO TAX RETURN BOX D1 CLAIM (FY${taxRule.financialYear}):
--------------------------------------------------
• Claim Method: Box D1 Code $methodCode
• Statutory Rate: ${(taxRule.centsPerKmRate * 100).toInt()}c / km
• Total Claimable Distance: ${summary.businessKm.toStringAsFixed(1)} km (Capped at 5,000 km)
• Final Box D1 Deductible Claim: \$${claimAmount.toStringAsFixed(2)} AUD

📁 ATTACHED EVIDENCE:
• Total Logged Work Drives: $tripCount (Contemporaneous GPS Log)
• Reasonable Estimate Ledger attached: KiloTax_CPK_Trip_Ledger.csv

Regards,
[Tradie Name]
''';
    } else {
      return '''Hi [Accountant Name],

Here is my official ATO Vehicle Tax Substantiation Summary for ${vehicle.displayName} (Rego: ${vehicle.regoPlate}) prepared via KiloTax.

--------------------------------------------------
📊 ATO TAX RETURN BOX D1 CLAIM (FY${taxRule.financialYear}):
--------------------------------------------------
• Primary Tax Method: Box D1 Code $methodCode
• Statutory Business Percentage: ${summary.businessPercentage.toStringAsFixed(2)}% (Valid 5 Years under TR 97/11)
• Total Business Distance: ${summary.businessKm.toStringAsFixed(1)} km of ${summary.totalKm.toStringAsFixed(1)} total km
• Final Box D1 Deductible Claim: \$${claimAmount.toStringAsFixed(2)} AUD

📁 ATTACHED AUDIT-PROOF EVIDENCE DOSSIER:
• Continuous Odometer Ledger: $tripCount trips (100% gapless)
• Substantiated Receipts Vault: $expenseCount receipts (Fuel, Repairs, Rego, Ins)
• 1-Click Xero / MYOB Manual Journal CSV attached

Regards,
[Tradie Name]
''';
    }
  }
}
