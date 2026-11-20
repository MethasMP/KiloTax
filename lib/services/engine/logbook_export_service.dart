import 'dart:typed_data';

import '../../core/utils/formatters.dart';
import '../../data/models/audit_evidence.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/tax_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/csv_security.dart';
import 'openxml_workbook_builder.dart';

/// Logbook Method (TR 97/11) Dedicated Exporter
/// Aligned strictly with ITAA 1997 Subdivision 28-F & TR 97/11
/// Produces:
/// 1. The Multi-Page Audit Dossier Text/PDF layout
/// 2. Standard ATO Continuous Odometer Audit Schedule CSV (16 Columns)
/// 3. Standard Xero Manual Journal CSV (with custom or default COA)
/// 4. Standard MYOB General Journal CSV (with custom or default COA)
class LogbookExportService {
  const LogbookExportService();

  /// Generates the standard 3-tab Logbook OpenXML Workbook (.xlsx) with AuditEvidence and SHA-256 provenance (INV-B05):
  /// - Tab 1: Tax Summary (all 7 ATO required audit fields)
  /// - Tab 2: Logbook Trips (continuous odometer trail)
  /// - Tab 3: Expenses & Receipts (10 columns: Merchant_Name, Merchant_ABN, Gross_Amount_AUD, GST_Amount_AUD, Net_Amount_AUD, Business_Percent, Deductible_Amount_AUD, Cloud_Receipt_URL, AuditEvidence_Id, Image_SHA256)
  Future<Uint8List> buildWorkbook({
    required Vehicle vehicle,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
    double openingOdometer = 0.0,
    double closingOdometer = 0.0,
    List<AuditEvidence> auditEvidenceList = const [],
  }) async {
    final builder = OpenXmlWorkbookBuilder();

    final effectiveOpening = openingOdometer > 0
        ? openingOdometer
        : (trips.isNotEmpty ? trips.first.startOdometer : vehicle.initialOdometer);
    final effectiveClosing = closingOdometer > 0
        ? closingOdometer
        : (trips.isNotEmpty ? trips.last.endOdometer : effectiveOpening);

    // ── TAB 1: TAX SUMMARY ───────────────────────────────────────────────────
    final summarySheet = builder.addSheet('Tax Summary', tabular: true);
    summarySheet.addRow([
      'taxpayerName',
      'abn',
      'vehicleRego',
      'financialYear',
      'openingOdometer',
      'closingOdometer',
      'deductibleClaim',
    ]);
    summarySheet.addRow([
      taxpayerName,
      abn,
      vehicle.regoPlate,
      'FY${taxRule.financialYear}',
      effectiveOpening,
      effectiveClosing,
      summary.logbookClaim,
    ]);
    summarySheet.addRow([]);
    summarySheet.addRow(['Taxpayer / Client Name', taxpayerName]);
    summarySheet.addRow(['ABN', abn]);
    summarySheet.addRow(['Vehicle Rego', vehicle.regoPlate]);
    summarySheet.addRow(['Financial Year', 'FY${taxRule.financialYear}']);
    summarySheet.addRow(['Opening Odometer', effectiveOpening]);
    summarySheet.addRow(['Closing Odometer', effectiveClosing]);
    summarySheet.addRow(['Deductible Claim', summary.logbookClaim]);

    // ── TAB 2: LOGBOOK TRIPS ──────────────────────────────────────────────────
    final tripsSheet = builder.addSheet('Logbook Trips', tabular: true);
    tripsSheet.addRow([
      'Trip_Number',
      'Trip_Date',
      'Start_Time',
      'Vehicle_Rego',
      'Odometer_Start_KM',
      'Odometer_End_KM',
      'Distance_KM',
      'Classification',
      'Origin',
      'Destination',
      'ATO_Business_Purpose',
      'Driver_Name',
      'Linked_Expense_IDs',
    ]);
    var tripNum = 1;
    for (final t in trips) {
      tripsSheet.addRow([
        tripNum++,
        t.date.toIso8601String().split('T').first,
        '${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
        vehicle.regoPlate,
        t.startOdometer,
        t.endOdometer,
        t.distanceKm,
        t.isBusiness ? 'BUSINESS' : 'PERSONAL',
        t.originAddress ?? '[Origin]',
        t.destinationAddress ?? '[Destination]',
        t.isBusiness ? t.purpose : '[Private Journey]',
        'Primary Driver',
        t.linkedExpenseIds.join('; '),
      ]);
    }

    // ── TAB 3: EXPENSES & RECEIPTS (10 Mandated Columns under INV-B05) ────────
    final expensesSheet = builder.addSheet('Expenses & Receipts', tabular: true);
    expensesSheet.addRow([
      'Merchant_Name',
      'Merchant_ABN',
      'Gross_Amount_AUD',
      'GST_Amount_AUD',
      'Net_Amount_AUD',
      'Business_Percent',
      'Deductible_Amount_AUD',
      'Cloud_Receipt_URL',
      'AuditEvidence_Id',
      'Image_SHA256',
    ]);

    for (final exp in expenses) {
      // Find matching AuditEvidence:
      // 1. Direct entity match
      AuditEvidence? matchedEvidence = auditEvidenceList
          .where((e) => e.entityId == exp.id || e.id == exp.receiptAudit?.batchId)
          .firstOrNull;

      // 2. Link via trips' evidenceLinks
      if (matchedEvidence == null) {
        for (final t in trips) {
          for (final link in t.evidenceLinks) {
            if (link.expenseId == exp.id && link.evidenceId != null) {
              matchedEvidence = auditEvidenceList
                  .where((e) => e.id == link.evidenceId)
                  .firstOrNull;
              if (matchedEvidence != null) break;
            }
          }
          if (matchedEvidence != null) break;
        }
      }

      final evidenceId = matchedEvidence?.id ??
          exp.receiptAudit?.batchId ??
          exp.clientDedupId ??
          exp.id;
      final imageSha256 = matchedEvidence?.imageSha256 ??
          exp.sha256Hash ??
          exp.receiptAudit?.imageSha256 ??
          '';

      final gross = exp.amount;
      final gst = exp.gstAmount ?? (gross / 11.0);
      final net = gross - gst;
      final merchant = exp.receiptAudit?.ocrMerchant ??
          exp.supplier ??
          exp.category.displayName;
      final merchantAbn = exp.receiptAudit?.ocrAbn ?? exp.supplierAbn ?? '';
      final deductible = gross * (exp.businessPercentage / 100.0);
      final cloudUrl = (exp.receiptPath != null && exp.receiptPath!.isNotEmpty)
          ? exp.receiptPath!
          : (matchedEvidence != null
              ? '${AppConstants.supabaseUrl}/storage/v1/object/public/${AppConstants.receiptStorageBucket}/${matchedEvidence.storagePath}'
              : '');

      expensesSheet.addRow([
        merchant,
        merchantAbn,
        gross,
        gst,
        net,
        exp.businessPercentage,
        deductible,
        cloudUrl,
        evidenceId,
        imageSha256,
      ]);
    }

    return builder.buildBytes();
  }
  /// Sanitize a CSV cell per CWE-1236 to prevent CSV formula injection
  /// Routes to centralized [CsvSecurity.sanitizeCsvCell].
  static String sanitizeCsvCell(String input) =>
      CsvSecurity.sanitizeCsvCell(input);

  /// Statutory disclaimer text mandated under ITAA 1997 Subdivision 28-F / TR 97/11 / Subdivision 28-H
  static const String statutoryDisclaimer =
      'Calculated under ATO Logbook method (ITAA 1997 Subdivision 28-F & TR 97/11). Not tax advice. Confirm claims with a registered tax agent. Retain for 5 years per Subdivision 28-H / Section 900-165.';

  static String _extract4DigitEndYear(String financialYear) {
    final rawYear = financialYear.split('-').last.trim();
    if (rawYear.length == 2) {
      return '20$rawYear';
    }
    return rawYear;
  }

  /// Generates the standard 16-column ATO continuous odometer audit ledger CSV
  static String generateLogbookAuditLedgerCsv({
    required Vehicle vehicle,
    required List<Trip> trips,
    String driverName = 'Primary Driver',
  }) {
    final buffer = StringBuffer();
    // Header
    buffer.writeln(
      'Trip_Number,Trip_Date,Start_Time,Vehicle_Rego,Odometer_Start_KM,Odometer_End_KM,Total_Distance_KM,Classification,Start_Address,End_Address,ATO_Business_Purpose,Driver_Name,In_Statutory_12W_Period,Cumulative_Business_KM,Cumulative_Total_KM,Running_Business_Percent',
    );

    double cumBusinessKm = 0.0;
    double cumTotalKm = 0.0;
    int index = 1;

    final logbookStart = vehicle.logbookStartDate ??
        (trips.isNotEmpty ? trips.first.date : DateTime.now());
    final logbookEnd = logbookStart.add(const Duration(days: 84));

    for (final t in trips) {
      final isBus = t.isBusiness;
      cumTotalKm += t.distanceKm;
      cumBusinessKm += t.businessDistanceKm;

      final runningPct =
          cumTotalKm > 0 ? (cumBusinessKm / cumTotalKm * 100.0) : 0.0;
      final dateStr = t.date.toIso8601String().split('T').first;
      final startTime =
          '${t.date.hour.toString().padLeft(2, "0")}:${t.date.minute.toString().padLeft(2, "0")}';
      final rego = sanitizeCsvCell(vehicle.regoPlate);
      final odoStart = t.startOdometer.toStringAsFixed(0);
      final odoEnd = t.endOdometer.toStringAsFixed(0);
      final dist = t.distanceKm.toStringAsFixed(2);
      final classification = isBus
          ? (t.isMixed ? 'MIXED' : 'BUSINESS')
          : t.classification == TripClassification.unclassified
              ? 'UNCLASSIFIED'
              : 'PERSONAL';
      // ATO & Privacy Best Practice: Mask addresses and purpose for private journeys
      final origin = sanitizeCsvCell(t.shareRoute
          ? (t.originAddress != null && t.originAddress!.trim().isNotEmpty
                  ? t.originAddress!
                  : '[Unspecified Origin]')
              .replaceAll(',', ' ')
          : '[Private Journey]');
      final dest = sanitizeCsvCell(t.shareRoute
          ? (t.destinationAddress != null &&
                      t.destinationAddress!.trim().isNotEmpty
                  ? t.destinationAddress!
                  : '[Unspecified Destination]')
              .replaceAll(',', ' ')
          : '[Private Journey]');
      final purpose = sanitizeCsvCell(isBus
          ? (t.purpose.trim().isNotEmpty ? t.purpose : '[Unspecified Purpose]')
              .replaceAll(',', ' ')
          : 'Personal Travel');
      final driver = sanitizeCsvCell(driverName);

      // Strict evaluation against the statutory 84-day window
      final inPeriod =
          (t.date.isAfter(logbookStart.subtract(const Duration(seconds: 1))) &&
                  t.date.isBefore(logbookEnd.add(const Duration(days: 1))))
              ? 'TRUE'
              : 'OUT_OF_PERIOD';

      buffer.writeln(
        '$index,$dateStr,$startTime,"$rego",$odoStart,$odoEnd,$dist,$classification,"$origin","$dest","$purpose","$driver",$inPeriod,${cumBusinessKm.toStringAsFixed(2)},${cumTotalKm.toStringAsFixed(2)},${runningPct.toStringAsFixed(2)}',
      );
      index++;
    }

    // Statutory Compliance Footer (Subdivision 28-H / Section 900-165)
    buffer.writeln('# DISCLAIMER: $statutoryDisclaimer');

    return buffer.toString();
  }

  /// Generates the multi-line Xero Manual Journal CSV with accurate BAS GST tax-type separation
  /// Supports optional custom [ChartOfAccountsConfig], defaulting to standard Xero codes.
  static String generateXeroManualJournalCsv({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    List<VehicleExpense> expenses = const [],
    ChartOfAccountsConfig? coaConfig,
  }) {
    final coa = coaConfig ?? const ChartOfAccountsConfig.xeroDefault();
    final buffer = StringBuffer();
    final businessPct = summary.businessPercentage;
    final dateStr = '30/06/${_extract4DigitEndYear(taxRule.financialYear)}';
    final activeExpenses = expenses.expand((e) => e.claimComponents).toList();

    // Separate GST-bearing running costs (Fuel, Servicing) from non-GST statutory costs (Rego, CTP)
    final gstRunningExpenses = activeExpenses
        .where((e) =>
            e.category == ExpenseCategory.fuel ||
            e.category == ExpenseCategory.maintenanceTyres)
        .fold(0.0, (sum, e) => sum + e.amount);

    final nonGstRunningExpenses = activeExpenses
        .where((e) =>
            e.category == ExpenseCategory.rego ||
            e.category == ExpenseCategory.insurance)
        .fold(0.0, (sum, e) => sum + e.amount);

    final actualGstRunning = gstRunningExpenses > 0
        ? gstRunningExpenses
        : (summary.totalRunningExpenses * 0.7);
    final actualNonGstRunning = nonGstRunningExpenses > 0
        ? nonGstRunningExpenses
        : (summary.totalRunningExpenses * 0.3);

    final deductibleGst = double.parse(
        (actualGstRunning * (businessPct / 100.0)).toStringAsFixed(2));
    final deductibleNonGst = double.parse(
        (actualNonGstRunning * (businessPct / 100.0)).toStringAsFixed(2));
    // Calculate private portion as exact plug to ensure journal sums to 0.00 without floating point drift
    final totalGross = double.parse(
        (actualGstRunning + actualNonGstRunning).toStringAsFixed(2));
    final privatePortion = double.parse(
        (totalGross - deductibleGst - deductibleNonGst).toStringAsFixed(2));

    final rego = sanitizeCsvCell(vehicle.regoPlate);
    final trackingName = sanitizeCsvCell('Vehicle');
    final narration = sanitizeCsvCell('Year-End MV Apportionment');
    final descFuelGross = sanitizeCsvCell(
        'Motor Vehicle Gross Fuel & Repairs (Pre-apportionment)');
    final descRegoGross = sanitizeCsvCell(
        'Motor Vehicle Gross Rego & Insurance (Pre-apportionment)');
    final descFuelAllowable = sanitizeCsvCell(
        'Allowable MV Fuel & Servicing (${businessPct.toStringAsFixed(1)}% Logbook)');
    final descRegoAllowable = sanitizeCsvCell(
        'Allowable MV Rego & Insurance (${businessPct.toStringAsFixed(1)}% Logbook)');
    final descDrawings = sanitizeCsvCell(
        'Owner Drawings - Private Vehicle Use (${(100.0 - businessPct).toStringAsFixed(1)}% Non-deductible)');
    final fuelAcc = sanitizeCsvCell(coa.fuelAccount);
    final regoAcc = sanitizeCsvCell(coa.regoAccount);
    final drawingsAcc = sanitizeCsvCell(coa.drawingsAccount);

    buffer.writeln(
        '*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1');
    buffer.writeln(
        '$narration,$dateStr,$descFuelGross,$fuelAcc,BAS Excluded,-${actualGstRunning.toStringAsFixed(2)},$trackingName,$rego');
    buffer.writeln(
        '$narration,$dateStr,$descRegoGross,$regoAcc,BAS Excluded,-${actualNonGstRunning.toStringAsFixed(2)},$trackingName,$rego');
    buffer.writeln(
        '$narration,$dateStr,$descFuelAllowable,$fuelAcc,GST on Expenses,${deductibleGst.toStringAsFixed(2)},$trackingName,$rego');
    buffer.writeln(
        '$narration,$dateStr,$descRegoAllowable,$regoAcc,BAS Excluded,${deductibleNonGst.toStringAsFixed(2)},$trackingName,$rego');
    buffer.writeln(
        '$narration,$dateStr,$descDrawings,$drawingsAcc,BAS Excluded,${privatePortion.toStringAsFixed(2)},$trackingName,$rego');

    final result = buffer.toString();
    return result;
  }

  /// Generates the MYOB AccountRight / Practice compatible General Journal CSV
  /// Comma-delimited general journal import layout with TaxCode separation
  static String generateMyobGeneralJournalCsv({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    List<VehicleExpense> expenses = const [],
    ChartOfAccountsConfig? coaConfig,
    String journalNumber = 'MV-2026-001',
  }) {
    final coa = coaConfig ?? const ChartOfAccountsConfig.myobDefault();
    final buffer = StringBuffer();
    final businessPct = summary.businessPercentage;
    final dateStr = '30/06/${_extract4DigitEndYear(taxRule.financialYear)}';
    final activeExpenses = expenses.expand((e) => e.claimComponents).toList();

    final gstRunningExpenses = activeExpenses
        .where((e) =>
            e.category == ExpenseCategory.fuel ||
            e.category == ExpenseCategory.maintenanceTyres)
        .fold(0.0, (sum, e) => sum + e.amount);

    final nonGstRunningExpenses = activeExpenses
        .where((e) =>
            e.category == ExpenseCategory.rego ||
            e.category == ExpenseCategory.insurance)
        .fold(0.0, (sum, e) => sum + e.amount);

    final actualGstRunning = gstRunningExpenses > 0
        ? gstRunningExpenses
        : (summary.totalRunningExpenses * 0.7);
    final actualNonGstRunning = nonGstRunningExpenses > 0
        ? nonGstRunningExpenses
        : (summary.totalRunningExpenses * 0.3);

    final deductibleGst = actualGstRunning * (businessPct / 100.0);
    final deductibleNonGst = actualNonGstRunning * (businessPct / 100.0);
    final privatePortion = (actualGstRunning + actualNonGstRunning) *
        ((100.0 - businessPct) / 100.0);

    final rego = sanitizeCsvCell(vehicle.regoPlate);
    final safeJrnNumber = sanitizeCsvCell(journalNumber);
    final fuelAcc = sanitizeCsvCell(coa.fuelAccount);
    final regoAcc = sanitizeCsvCell(coa.regoAccount);
    final drawingsAcc = sanitizeCsvCell(coa.drawingsAccount);

    final memoGross =
        sanitizeCsvCell('Year-End MV Apportionment (Rego: $rego)');
    final memoFuelAllowable = sanitizeCsvCell(
        'Allowable MV Fuel (${businessPct.toStringAsFixed(1)}% Logbook)');
    final memoRegoGross = sanitizeCsvCell('Year-End MV Apportionment Rego/CTP');
    final memoRegoAllowable = sanitizeCsvCell(
        'Allowable MV Rego (${businessPct.toStringAsFixed(1)}% Logbook)');
    final memoDrawings =
        sanitizeCsvCell('Owner Drawings - Private Motor Vehicle Use');

    buffer.writeln(
        'JournalNumber,Date,Memo,AccountSource,AccountID,DebitAmount,CreditAmount,TaxCode,Job');
    // Credit gross fuel & oil pool
    buffer.writeln(
        '$safeJrnNumber,$dateStr,"$memoGross",MYOB,$fuelAcc,0.00,${actualGstRunning.toStringAsFixed(2)},N-T,');
    // Debit allowable fuel (GST code)
    buffer.writeln(
        '$safeJrnNumber,$dateStr,"$memoFuelAllowable",MYOB,$fuelAcc,${deductibleGst.toStringAsFixed(2)},0.00,GST,');
    // Credit gross rego/insurance pool
    buffer.writeln(
        '$safeJrnNumber,$dateStr,"$memoRegoGross",MYOB,$regoAcc,0.00,${actualNonGstRunning.toStringAsFixed(2)},N-T,');
    // Debit allowable rego/insurance (N-T or FRE)
    buffer.writeln(
        '$safeJrnNumber,$dateStr,"$memoRegoAllowable",MYOB,$regoAcc,${deductibleNonGst.toStringAsFixed(2)},0.00,N-T,');
    // Debit owner drawings (N-T)
    buffer.writeln(
        '$safeJrnNumber,$dateStr,"$memoDrawings",MYOB,$drawingsAcc,${privatePortion.toStringAsFixed(2)},0.00,N-T,');

    return buffer.toString();
  }

  /// Generates the visual Multi-Page Logbook Audit Pack Dossier text layout
  static String generateLogbookAuditDossierText({
    required Vehicle vehicle,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
  }) {
    final businessPct = summary.businessPercentage;
    final startDate = vehicle.logbookStartDate ??
        (trips.isNotEmpty
            ? trips.first.date
            : DateTime.now().subtract(const Duration(days: 84)));
    final endDate = startDate.add(const Duration(days: 84));
    final cappedCarCost = taxRule.carDepreciationLimit;
    final maxAllowableDepreciation = cappedCarCost *
        (businessPct / 100.0) *
        0.25; // 25% Diminishing value guideline
    final activeExpenses = expenses.expand((e) => e.claimComponents).toList();
    final savedOcrMatchCount = activeExpenses
        .where((expense) =>
            expense.receiptAudit?.reviewStatus ==
                ReceiptReviewStatus.verified &&
            expense.receiptAudit?.imageSha256 != null)
        .length;
    final receiptsNeedingReview = activeExpenses.length - savedOcrMatchCount;

    // Check if the 84-day period crosses 30 June (ATO FY Boundary)
    final june30Current = DateTime(startDate.year, 6, 30, 23, 59, 59);
    final june30Next = DateTime(startDate.year + 1, 6, 30, 23, 59, 59);
    final straddlesFy =
        (startDate.isBefore(june30Current) && endDate.isAfter(june30Current)) ||
            (startDate.isBefore(june30Next) && endDate.isAfter(june30Next));
    final boundaryYear =
        startDate.month > 6 ? startDate.year + 1 : startDate.year;
    final june30 = DateTime(boundaryYear, 6, 30);
    final daysInFy1 = june30.difference(startDate).inDays + 1;
    final daysInFy2 = 84 - daysInFy1;
    final fyAdvisory = straddlesFy
        ? '• ATO FY Transition Advisory: 12-week period straddles 30 June ($daysInFy1 days in FY${boundaryYear - 1}-$boundaryYear / $daysInFy2 days in FY$boundaryYear-${boundaryYear + 1}). Statutory business percentage of ${businessPct.toStringAsFixed(2)}% applies to both years pursuant to TR 97/11 par 18.'
        : '• ATO FY Transition: Scheduled period falls within one income year (does not straddle 30 June boundary).';

    final apportionedRunningClaim =
        summary.totalRunningExpenses * (businessPct / 100.0);
    final totalLogbookDeduction =
        summary.logbookClaim + maxAllowableDepreciation;

    return '''
====================================================================================================
⚡ TAX AGENT FAST-FILL BOX • INDIVIDUAL TAX RETURN (ITR) / TRUST / COMPANY RETURN
For immediate 30-second entry into Xero Tax, HandiTax, and MYOB Practice:
----------------------------------------------------------------------------------------------------
  Item / Field                  Software Field / Box   Value to Enter
  ----------------------------  ---------------------  ---------------------------------------------
  Motor Vehicle Claim Method:   D1 Item Label:         [ B ] (Logbook method)
  Recorded Business Use %:     Business %:            ${businessPct.toStringAsFixed(2)}% (review period and supporting records)
  Total Work / Total Odo:       Logbook Distance:      ${summary.businessKm.toStringAsFixed(1)} km / ${summary.totalKm.toStringAsFixed(1)} km
  Gross Operating Expenses:     Financial Accounts:    \$${summary.totalRunningExpenses.toStringAsFixed(2)} AUD
  Allowable Running Deduction:  BOX D1 WORK EXPENSES:  \$${apportionedRunningClaim.toStringAsFixed(2)} AUD
  Direct Deductions (Tolls/Pk): BOX D1 OTHER EXPENSES: \$${summary.totalDirectDeductions.toStringAsFixed(2)} AUD
  Capital Allowance / Deprec:   DIV 40 ASSET DEDUCT:   \$${maxAllowableDepreciation.toStringAsFixed(2)} AUD (Asset cap \$${taxRule.carDepreciationLimit.toStringAsFixed(0)})
  TOTAL D1 DEDUCTION (Gross):   BOX D1 CLAIM TOTAL:    \$${totalLogbookDeduction.toStringAsFixed(2)} AUD
  Illustrative 5-Yr Window:    Review applicability:    FY ${startDate.year} to FY ${startDate.year + 4}
====================================================================================================

====================================================================================================
KILOTAX COMPLIANCE DOSSIER | ATO MOTOR VEHICLE LOGBOOK SCHEDULE (ITAA 1997 Subdiv 28-F & TR 97/11)
METHOD: LOGBOOK | ATO BOX D1 CODE: B | FINANCIAL YEAR: ${taxRule.financialYear}
====================================================================================================

PAGE 1: RECORDED SUMMARY & BUSINESS PERCENTAGE
----------------------------------------------------------------------------------------------------
[1.1] TAXPAYER & VEHICLE SCHEDULE
• Taxpayer Name:              $taxpayerName
• ABN / Trading Name:         ${abn.isNotEmpty ? abn : 'Registered Sole Trader'}
• Vehicle Description:        ${vehicle.displayName}
• Vehicle Registration:       ${vehicle.regoPlate}
• Baseline Starting Odometer: ${Formatters.odometer(vehicle.initialOdometer)} km (recorded baseline)
• Car Cost Cap (s 40-230):    \$${taxRule.carDepreciationLimit.toStringAsFixed(0)} AUD (Statutory Capital Allowance Limit)
• Day 1 Odometer Photo:       ${vehicle.startOdometerPhotoPath != null ? 'Reference saved, file not checked' : 'No reference saved'}
• Day 84 Odometer Photo:      ${vehicle.endOdometerPhotoPath != null ? 'Reference saved, file not checked' : 'No reference saved'}

[1.2] SCHEDULED LOGBOOK PERIOD (CONTINUITY REQUIRES REVIEW)
• Logbook Period:             ${Formatters.date(startDate)} to ${Formatters.date(endDate)} (84 Consecutive Days)
• Statutory Status:           Review duration, continuity, and eligibility before use
$fyAdvisory
• Total Kilometres Logged:    ${Formatters.distance(summary.totalKm)}
• Total Business Distance:    ${Formatters.distance(summary.businessKm)}
• Total Personal Distance:    ${Formatters.distance(summary.personalKm)}

====================================================================================================
>>> RECORDED BUSINESS PERCENTAGE: ${businessPct.toStringAsFixed(2)}% <<<
Formula: (${summary.businessKm.toStringAsFixed(1)} Business km / ${summary.totalKm.toStringAsFixed(1)} Total km) * 100
====================================================================================================

[1.3] ANNUAL CLAIM LODGEMENT RECONCILIATION
• Total Documented Operating Expenses:    ${Formatters.currency(summary.totalRunningExpenses)}
• Direct Work Deductions (Tolls/Parking): ${Formatters.currency(summary.totalDirectDeductions)}
• Apportioned Business Running Claim:     ${Formatters.currency(apportionedRunningClaim)}
• Estimated Div 40 Capital Allowance:    ${Formatters.currency(maxAllowableDepreciation)} (Guideline @ 25% DV)

>>> TAX RETURN BOX D1 CLAIM (RUNNING):   ${Formatters.currency(summary.logbookClaim)} AUD <<<
* Note for Tax Agent: Add vehicle depreciation / lease interest above pursuant to client asset register.

----------------------------------------------------------------------------------------------------
PAGE 2: ITEMIZED RUNNING EXPENSES & GST TAX-TYPE BREAKDOWN
----------------------------------------------------------------------------------------------------
Expense Category             Receipts    Gross Total       GST Component    Deductible (${businessPct.toStringAsFixed(0)}%)
----------------------------------------------------------------------------------------------------
Fuel & Oil (GST Claimable)   ${activeExpenses.where((e) => e.category == ExpenseCategory.fuel).length.toString().padLeft(5)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.fuel)).padLeft(12)}       ${Formatters.currency(_catGst(activeExpenses, ExpenseCategory.fuel)).padLeft(12)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.fuel) * (businessPct / 100.0)).padLeft(14)}
Servicing & Tyres (GST)      ${activeExpenses.where((e) => e.category == ExpenseCategory.maintenanceTyres).length.toString().padLeft(5)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.maintenanceTyres)).padLeft(12)}       ${Formatters.currency(_catGst(activeExpenses, ExpenseCategory.maintenanceTyres)).padLeft(12)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.maintenanceTyres) * (businessPct / 100.0)).padLeft(14)}
Insurance & CTP (BAS Excl)   ${activeExpenses.where((e) => e.category == ExpenseCategory.insurance).length.toString().padLeft(5)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.insurance)).padLeft(12)}       ${Formatters.currency(0.0).padLeft(12)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.insurance) * (businessPct / 100.0)).padLeft(14)}
Registration (BAS Excl)      ${activeExpenses.where((e) => e.category == ExpenseCategory.rego).length.toString().padLeft(5)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.rego)).padLeft(12)}       ${Formatters.currency(0.0).padLeft(12)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.rego) * (businessPct / 100.0)).padLeft(14)}
Tolls & Work Parking (100%)  ${activeExpenses.where((e) => e.category == ExpenseCategory.tollsParking).length.toString().padLeft(5)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.tollsParking)).padLeft(12)}       ${Formatters.currency(_catGst(activeExpenses, ExpenseCategory.tollsParking)).padLeft(12)}       ${Formatters.currency(_catTotal(activeExpenses, ExpenseCategory.tollsParking)).padLeft(14)}
----------------------------------------------------------------------------------------------------
TOTALS                       ${activeExpenses.length.toString().padLeft(5)}       ${Formatters.currency(summary.totalRunningExpenses + summary.totalDirectDeductions).padLeft(12)}       ${Formatters.currency(_catGst(activeExpenses, ExpenseCategory.fuel) + _catGst(activeExpenses, ExpenseCategory.maintenanceTyres) + _catGst(activeExpenses, ExpenseCategory.tollsParking)).padLeft(12)}       ${Formatters.currency(summary.logbookClaim).padLeft(14)}

* Receipt evidence status: $savedOcrMatchCount have a saved OCR match and image fingerprint; ${expenses.where((e) => e.isVaultOnly).length} stored in audit vault (excluded from FY claim); $receiptsNeedingReview require record review. Receipt availability is checked separately when a ZIP tax pack is prepared.

----------------------------------------------------------------------------------------------------
PAGE 3+: CONTINUOUS ODODMETRE AUDIT TRAIL (TR 97/11 MANDATED)
----------------------------------------------------------------------------------------------------
Date         Odo Start   Odo End     Distance   Purpose                           Class
----------------------------------------------------------------------------------------------------
${trips.take(15).map((t) => '${t.date.toIso8601String().split("T").first}   ${t.startOdometer.toStringAsFixed(0).padLeft(8)}   ${t.endOdometer.toStringAsFixed(0).padLeft(8)}   ${Formatters.distance(t.distanceKm).padLeft(8)}   ${(t.isBusiness ? (t.purpose.isNotEmpty ? t.purpose : "Work Drive") : "Private Travel").padRight(32).substring(0, 32)}   ${t.isBusiness ? "BUS" : "PRIV"}').join("\n")}
... [Review the separately exported full trip ledger, if supplied] ...

====================================================================================================
RECORD REVIEW
====================================================================================================
Review actual equipment, transport purpose, and storage circumstances before claiming bulky-tool travel.
Review dates, odometer continuity, business purposes, and expense evidence before lodging.
This generated schedule does not establish a complete or unbroken logbook, receipt authenticity, or eligibility.

Taxpayer Signature: ___________________________        Date: ____ / ____ / ________
Tax Agent Signature: __________________________        RAN:  ______________________

====================================================================================================
STATUTORY COMPLIANCE & LEGAL DISCLAIMER (ITAA 1997 Subdivision 28-F / TPB Notice):
Calculated under ATO Logbook method (ITAA 1997 Subdivision 28-F & TR 97/11). Not tax advice.
Confirm claims with a registered tax agent. Retain for 5 years per Subdivision 28-H / Section 900-165.
KiloTax is an independent software application and is NOT affiliated with, endorsed by, or connected
to the Australian Taxation Office (ATO) or the Tax Practitioners Board (TPB).
====================================================================================================
''';
  }

  /// Generates the official HandiTax & Xero Workpaper Action Schedule CSV for Australian Tax Return Item D1.
  /// Exports exact schema for Australian Tax Return Item D1:
  /// - Labels D1A (Method Code B) and D1B (Allowable deductions)
  /// - Schedules 401 (Fuel), 402 (Repairs), 403 (Insurance/Rego), 404 (Depreciation Div 40), 405 (Interest)
  static String generateHandiTaxD1ScheduleCsv({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    List<VehicleExpense> expenses = const [],
    String taxpayerName = 'Tradie Client',
    String abn = '',
    double? customDepreciation,
    double? customInterest,
  }) {
    final buffer = StringBuffer();
    final businessPct = summary.businessPercentage;
    final activeExpenses = expenses.expand((e) => e.claimComponents).toList();

    // Schedule 401: Fuel & Oil
    final fuelGross = _catTotal(activeExpenses, ExpenseCategory.fuel);
    final effectiveFuelGross = fuelGross > 0
        ? fuelGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.45) : 0.0);
    final fuelClaim = double.parse(
        (effectiveFuelGross * (businessPct / 100.0)).toStringAsFixed(2));

    // Schedule 402: Repairs & Servicing
    final repairsGross =
        _catTotal(activeExpenses, ExpenseCategory.maintenanceTyres);
    final effectiveRepairsGross = repairsGross > 0
        ? repairsGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.25) : 0.0);
    final repairsClaim = double.parse(
        (effectiveRepairsGross * (businessPct / 100.0)).toStringAsFixed(2));

    // Schedule 403: Registration & Insurance
    final regoInsGross = _catTotal(activeExpenses, ExpenseCategory.rego) +
        _catTotal(activeExpenses, ExpenseCategory.insurance);
    final effectiveRegoInsGross = regoInsGross > 0
        ? regoInsGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.30) : 0.0);
    final regoInsClaim = double.parse(
        (effectiveRegoInsGross * (businessPct / 100.0)).toStringAsFixed(2));

    // Schedule 404: Depreciation Div 40 (Capital Allowance capped at s 40-230 car cost cap)
    final cappedCost = taxRule.carDepreciationLimit;
    final depreciationGross = customDepreciation ?? (cappedCost * 0.25);
    final depreciationClaim = double.parse(
        (depreciationGross * (businessPct / 100.0)).toStringAsFixed(2));

    // Schedule 405: Interest on Car Finance (ITAA 1997 s 8-1)
    final interestGross =
        customInterest ?? _catTotal(activeExpenses, ExpenseCategory.interest);
    final interestClaim = double.parse(
        (interestGross * (businessPct / 100.0)).toStringAsFixed(2));

    // Schedule 406: Direct Deductions (Work Tolls & Parking - 100% deductible)
    final directGross = summary.totalDirectDeductions > 0
        ? summary.totalDirectDeductions
        : _catTotal(activeExpenses, ExpenseCategory.tollsParking);
    final directClaim = directGross;

    final totalGross = double.parse((effectiveFuelGross +
            effectiveRepairsGross +
            effectiveRegoInsGross +
            depreciationGross +
            interestGross +
            directGross)
        .toStringAsFixed(2));
    final totalClaim = double.parse((fuelClaim +
            repairsClaim +
            regoInsClaim +
            depreciationClaim +
            interestClaim +
            directClaim)
        .toStringAsFixed(2));

    final fy = sanitizeCsvCell(taxRule.financialYear);
    final safeClientName = sanitizeCsvCell(taxpayerName);
    final safeAbn = sanitizeCsvCell(abn);
    final safeRego = sanitizeCsvCell(vehicle.regoPlate);
    final safeDesc = sanitizeCsvCell(vehicle.displayName);
    final pctStr = businessPct.toStringAsFixed(2);

    // CSV Header
    buffer.writeln(
      'Tax_Year,Client_Name,ABN,Vehicle_Rego,Vehicle_Description,Item_Label,Schedule_Code,Schedule_Name,Gross_Amount,Business_Percentage,Allowable_Deduction,ATO_Legislative_Reference',
    );

    // D1A: Method indicator
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1A,METHOD,"Logbook Method",0.00,$pctStr,0.00,"ITAA 1997 Subdiv 28-F (Code B)"',
    );

    // D1B Schedules
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,401,"Fuel and Oil",${effectiveFuelGross.toStringAsFixed(2)},$pctStr,${fuelClaim.toStringAsFixed(2)},"TR 97/11 Par 18"',
    );
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,402,"Repairs and Maintenance",${effectiveRepairsGross.toStringAsFixed(2)},$pctStr,${repairsClaim.toStringAsFixed(2)},"TR 97/11 Par 18"',
    );
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,403,"Registration and Insurance",${effectiveRegoInsGross.toStringAsFixed(2)},$pctStr,${regoInsClaim.toStringAsFixed(2)},"TR 97/11 Par 18"',
    );
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,404,"Depreciation Div 40",${depreciationGross.toStringAsFixed(2)},$pctStr,${depreciationClaim.toStringAsFixed(2)},"ITAA 1997 s 40-230"',
    );
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,405,"Interest on Car Finance",${interestGross.toStringAsFixed(2)},$pctStr,${interestClaim.toStringAsFixed(2)},"ITAA 1997 s 8-1"',
    );
    if (directGross > 0) {
      buffer.writeln(
        '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,406,"Direct Work Deductions (Tolls/Parking)",${directGross.toStringAsFixed(2)},100.00,${directClaim.toStringAsFixed(2)},"ITAA 1997 s 8-1"',
      );
    }
    buffer.writeln(
      '$fy,"$safeClientName","$safeAbn","$safeRego","$safeDesc",D1B,TOTAL,"Total Allowable Item D1 Claim",${totalGross.toStringAsFixed(2)},$pctStr,${totalClaim.toStringAsFixed(2)},"ITR Item D1 Allowable Claim"',
    );

    // Statutory Compliance Footer
    buffer.writeln('# DISCLAIMER: $statutoryDisclaimer');

    return buffer.toString();
  }

  /// Generates the Fast-Fill Workpaper Action Schedule for HandiTax & Xero Tax entry
  static String generateHandiTaxD1ScheduleText({
    required Vehicle vehicle,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    List<VehicleExpense> expenses = const [],
    String taxpayerName = 'Tradie Client',
    String abn = '',
    double? customDepreciation,
    double? customInterest,
  }) {
    final businessPct = summary.businessPercentage;
    final activeExpenses = expenses.expand((e) => e.claimComponents).toList();

    final fuelGross = _catTotal(activeExpenses, ExpenseCategory.fuel);
    final effectiveFuelGross = fuelGross > 0
        ? fuelGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.45) : 0.0);
    final fuelClaim = effectiveFuelGross * (businessPct / 100.0);

    final repairsGross =
        _catTotal(activeExpenses, ExpenseCategory.maintenanceTyres);
    final effectiveRepairsGross = repairsGross > 0
        ? repairsGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.25) : 0.0);
    final repairsClaim = effectiveRepairsGross * (businessPct / 100.0);

    final regoInsGross = _catTotal(activeExpenses, ExpenseCategory.rego) +
        _catTotal(activeExpenses, ExpenseCategory.insurance);
    final effectiveRegoInsGross = regoInsGross > 0
        ? regoInsGross
        : (expenses.isEmpty ? (summary.totalRunningExpenses * 0.30) : 0.0);
    final regoInsClaim = effectiveRegoInsGross * (businessPct / 100.0);

    final cappedCost = taxRule.carDepreciationLimit;
    final depreciationGross = customDepreciation ?? (cappedCost * 0.25);
    final depreciationClaim = depreciationGross * (businessPct / 100.0);

    final interestGross =
        customInterest ?? _catTotal(activeExpenses, ExpenseCategory.interest);
    final interestClaim = interestGross * (businessPct / 100.0);

    final directGross = summary.totalDirectDeductions > 0
        ? summary.totalDirectDeductions
        : _catTotal(activeExpenses, ExpenseCategory.tollsParking);
    final directClaim = directGross;

    final totalGross = effectiveFuelGross +
        effectiveRepairsGross +
        effectiveRegoInsGross +
        depreciationGross +
        interestGross +
        directGross;
    final totalClaim = fuelClaim +
        repairsClaim +
        regoInsClaim +
        depreciationClaim +
        interestClaim +
        directClaim;

    return '''
====================================================================================================
⚡ HANDITAX & XERO WORKPAPER ACTION SCHEDULE • AUSTRALIAN TAX RETURN ITEM D1
For 30-Second Fast-Fill Lodgement into HandiTax, Xero Tax, and MYOB Practice:
----------------------------------------------------------------------------------------------------
Taxpayer Name:       $taxpayerName
ABN / Trading Name:  ${abn.isNotEmpty ? abn : 'Registered Sole Trader'}
Vehicle Rego / Name: ${vehicle.regoPlate} (${vehicle.displayName})
Financial Year:      ${taxRule.financialYear}
ATO Item D1 Method:  [ B ] (Logbook Method - review required)
Recorded Business%: ${businessPct.toStringAsFixed(2)}%

ITEM D1 MOTOR VEHICLE SCHEDULE BREAKDOWN:
Code  Schedule Category             Gross Amount      Biz %    Allowable Claim   ATO Authority
----  --------------------------  --------------    -------    ---------------   -------------------
401   Fuel and Oil                ${Formatters.currency(effectiveFuelGross).padLeft(14)}    ${businessPct.toStringAsFixed(1)}%    ${Formatters.currency(fuelClaim).padLeft(15)}   TR 97/11 Par 18
402   Repairs and Maintenance     ${Formatters.currency(effectiveRepairsGross).padLeft(14)}    ${businessPct.toStringAsFixed(1)}%    ${Formatters.currency(repairsClaim).padLeft(15)}   TR 97/11 Par 18
403   Registration & Insurance    ${Formatters.currency(effectiveRegoInsGross).padLeft(14)}    ${businessPct.toStringAsFixed(1)}%    ${Formatters.currency(regoInsClaim).padLeft(15)}   TR 97/11 Par 18
404   Depreciation Div 40         ${Formatters.currency(depreciationGross).padLeft(14)}    ${businessPct.toStringAsFixed(1)}%    ${Formatters.currency(depreciationClaim).padLeft(15)}   ITAA 1997 s 40-230
405   Interest on Car Finance     ${Formatters.currency(interestGross).padLeft(14)}    ${businessPct.toStringAsFixed(1)}%    ${Formatters.currency(interestClaim).padLeft(15)}   ITAA 1997 s 8-1
406   Work Tolls & Parking (100%) ${Formatters.currency(directGross).padLeft(14)}   100.0%    ${Formatters.currency(directClaim).padLeft(15)}   ITAA 1997 s 8-1
----------------------------------------------------------------------------------------------------
TOTAL ITEM D1 ALLOWABLE DEDUCTION: ${Formatters.currency(totalGross).padLeft(13)}              ${Formatters.currency(totalClaim).padLeft(15)}   Box D1 Label B
====================================================================================================
''';
  }

  static double _catTotal(List<VehicleExpense> list, ExpenseCategory cat) {
    return list
        .where((e) => e.category == cat && !e.isVaultOnly)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  static double _catGst(List<VehicleExpense> list, ExpenseCategory cat) {
    return list
        .where((e) => e.category == cat && !e.isVaultOnly)
        .fold(0.0, (sum, e) => sum + e.effectiveGst);
  }
}
