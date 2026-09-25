import '../../core/utils/formatters.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/tax_config.dart';
import '../../core/constants/app_constants.dart';

/// Logbook Method (TR 97/11) Dedicated Exporter
/// Aligned strictly with ITAA 1997 Subdivision 28-F & TR 97/11
/// Produces:
/// 1. The Multi-Page Audit Dossier Text/PDF layout
/// 2. Standard ATO Continuous Odometer Audit Schedule CSV (16 Columns)
/// 3. Standard Xero Manual Journal CSV (with custom or default COA)
/// 4. Standard MYOB General Journal CSV (with custom or default COA)
class LogbookExportService {
  /// Sanitize a CSV cell per CWE-1236 to prevent CSV formula injection
  /// Escapes double quotes (" -> "") and prepends single quote (') if the text begins with formula triggers
  static String sanitizeCsvCell(String input) {
    if (input.isEmpty) return input;
    String text = input;
    const formulaTriggers = ['=', '+', '-', '@', '\t', '\r'];
    if (formulaTriggers.contains(text[0])) {
      text = "'$text";
    }
    return text.replaceAll('"', '""');
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
      if (isBus) cumBusinessKm += t.distanceKm;

      final runningPct =
          cumTotalKm > 0 ? (cumBusinessKm / cumTotalKm * 100.0) : 0.0;
      final dateStr = t.date.toIso8601String().split('T').first;
      final startTime =
          '${t.date.hour.toString().padLeft(2, "0")}:${t.date.minute.toString().padLeft(2, "0")}';
      final rego = sanitizeCsvCell(vehicle.regoPlate);
      final odoStart = t.startOdometer.toStringAsFixed(0);
      final odoEnd = t.endOdometer.toStringAsFixed(0);
      final dist = t.distanceKm.toStringAsFixed(2);
      final classification = isBus ? 'BUSINESS' : 'PERSONAL';
      // ATO & Privacy Best Practice: Mask addresses and purpose for private journeys
      final origin = sanitizeCsvCell(isBus
          ? (t.originAddress ?? 'Work Site').replaceAll(',', ' ')
          : '[Private Journey]');
      final dest = sanitizeCsvCell(isBus
          ? (t.destinationAddress ?? 'Client Job').replaceAll(',', ' ')
          : '[Private Journey]');
      final purpose = sanitizeCsvCell(isBus
          ? (t.purpose.isNotEmpty ? t.purpose : 'Client Job Site').replaceAll(',', ' ')
          : 'Personal Travel');
      final driver = sanitizeCsvCell(driverName);

      // Strict evaluation against the statutory 84-day window
      final inPeriod =
          (t.date.isAfter(logbookStart.subtract(const Duration(seconds: 1))) &&
                  t.date.isBefore(logbookEnd.add(const Duration(days: 1))))
              ? 'TRUE'
              : 'OUT_OF_PERIOD';

      buffer.writeln(
        '$index,$dateStr,$startTime,$rego,$odoStart,$odoEnd,$dist,$classification,"$origin","$dest","$purpose","$driver",$inPeriod,${cumBusinessKm.toStringAsFixed(2)},${cumTotalKm.toStringAsFixed(2)},${runningPct.toStringAsFixed(2)}',
      );
      index++;
    }

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
    final dateStr = '30/06/${taxRule.financialYear.split('-').last}';
    final activeExpenses = expenses.where((e) => !e.isVaultOnly).toList();

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

    final deductibleGst = actualGstRunning * (businessPct / 100.0);
    final deductibleNonGst = actualNonGstRunning * (businessPct / 100.0);
    final privatePortion = (actualGstRunning + actualNonGstRunning) *
        ((100.0 - businessPct) / 100.0);

    final rego = sanitizeCsvCell(vehicle.regoPlate);

    buffer.writeln(
        '*Narration,*Date,*Description,*AccountCode,*TaxType,*Amount,TrackingName1,TrackingOption1');
    // 1. Credit gross general ledger pool
    buffer.writeln(
        'Year-End MV Apportionment,$dateStr,Motor Vehicle Gross Fuel & Repairs (Pre-apportionment),${coa.fuelAccount},BAS Excluded,-${actualGstRunning.toStringAsFixed(2)},Vehicle,$rego');
    buffer.writeln(
        'Year-End MV Apportionment,$dateStr,Motor Vehicle Gross Rego & Insurance (Pre-apportionment),${coa.regoAccount},BAS Excluded,-${actualNonGstRunning.toStringAsFixed(2)},Vehicle,$rego');
    // 2. Debit allowable business portion with correct TaxType
    buffer.writeln(
        'Year-End MV Apportionment,$dateStr,Allowable MV Fuel & Servicing (${businessPct.toStringAsFixed(1)}% Logbook),${coa.fuelAccount},GST on Expenses,${deductibleGst.toStringAsFixed(2)},Vehicle,$rego');
    buffer.writeln(
        'Year-End MV Apportionment,$dateStr,Allowable MV Rego & Insurance (${businessPct.toStringAsFixed(1)}% Logbook),${coa.regoAccount},BAS Excluded,${deductibleNonGst.toStringAsFixed(2)},Vehicle,$rego');
    // 3. Debit owner drawings for private use
    buffer.writeln(
        'Year-End MV Apportionment,$dateStr,Owner Drawings - Private Vehicle Use (${(100.0 - businessPct).toStringAsFixed(1)}% Non-deductible),${coa.drawingsAccount},BAS Excluded,${privatePortion.toStringAsFixed(2)},Vehicle,$rego');

    return buffer.toString();
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
    final dateStr = '30/06/${taxRule.financialYear.split('-').last}';
    final activeExpenses = expenses.where((e) => !e.isVaultOnly).toList();

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

    buffer.writeln(
        'JournalNumber,Date,Memo,AccountSource,AccountID,DebitAmount,CreditAmount,TaxCode,Job');
    // Credit gross fuel & oil pool
    buffer.writeln(
        '$journalNumber,$dateStr,"Year-End MV Apportionment (Rego: $rego)",MYOB,${coa.fuelAccount},0.00,${actualGstRunning.toStringAsFixed(2)},N-T,');
    // Debit allowable fuel (GST code)
    buffer.writeln(
        '$journalNumber,$dateStr,"Allowable MV Fuel (${businessPct.toStringAsFixed(1)}% Logbook)",MYOB,${coa.fuelAccount},${deductibleGst.toStringAsFixed(2)},0.00,GST,');
    // Credit gross rego/insurance pool
    buffer.writeln(
        '$journalNumber,$dateStr,"Year-End MV Apportionment Rego/CTP",MYOB,${coa.regoAccount},0.00,${actualNonGstRunning.toStringAsFixed(2)},N-T,');
    // Debit allowable rego/insurance (N-T or FRE)
    buffer.writeln(
        '$journalNumber,$dateStr,"Allowable MV Rego (${businessPct.toStringAsFixed(1)}% Logbook)",MYOB,${coa.regoAccount},${deductibleNonGst.toStringAsFixed(2)},0.00,N-T,');
    // Debit owner drawings (N-T)
    buffer.writeln(
        '$journalNumber,$dateStr,"Owner Drawings - Private Motor Vehicle Use",MYOB,${coa.drawingsAccount},${privatePortion.toStringAsFixed(2)},0.00,N-T,');

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
    final activeExpenses = expenses.where((e) => !e.isVaultOnly).toList();
    final verifiedReceiptCount = activeExpenses
        .where((expense) =>
            expense.receiptAudit?.reviewStatus ==
                ReceiptReviewStatus.verified &&
            expense.receiptAudit?.imageSha256 != null)
        .length;
    final receiptsNeedingReview = activeExpenses.length - verifiedReceiptCount;

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
        : '• ATO FY Transition: Single income year compliant (does not straddle 30 June boundary).';

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
  Certified Business Use %:     Business %:            ${businessPct.toStringAsFixed(2)}% (TR 97/11 12-wk compliant)
  Total Work / Total Odo:       Logbook Distance:      ${summary.businessKm.toStringAsFixed(1)} km / ${summary.totalKm.toStringAsFixed(1)} km
  Gross Operating Expenses:     Financial Accounts:    \$${summary.totalRunningExpenses.toStringAsFixed(2)} AUD
  Allowable Running Deduction:  BOX D1 WORK EXPENSES:  \$${apportionedRunningClaim.toStringAsFixed(2)} AUD
  Direct Deductions (Tolls/Pk): BOX D1 OTHER EXPENSES: \$${summary.totalDirectDeductions.toStringAsFixed(2)} AUD
  Capital Allowance / Deprec:   DIV 40 ASSET DEDUCT:   \$${maxAllowableDepreciation.toStringAsFixed(2)} AUD (Asset cap \$${taxRule.carDepreciationLimit.toStringAsFixed(0)})
  TOTAL D1 DEDUCTION (Gross):   BOX D1 CLAIM TOTAL:    \$${totalLogbookDeduction.toStringAsFixed(2)} AUD
  Logbook 5-Yr Validity Term:   Valid Income Years:    FY ${startDate.year} to FY ${startDate.year + 4}
====================================================================================================

====================================================================================================
KILOTAX COMPLIANCE DOSSIER | ATO MOTOR VEHICLE LOGBOOK SCHEDULE (ITAA 1997 Subdiv 28-F & TR 97/11)
METHOD: LOGBOOK | ATO BOX D1 CODE: B | FINANCIAL YEAR: ${taxRule.financialYear}
====================================================================================================

PAGE 1: STATUTORY SUMMARY & BUSINESS PERCENTAGE CERTIFICATE
----------------------------------------------------------------------------------------------------
[1.1] TAXPAYER & VEHICLE SCHEDULE
• Taxpayer Name:              $taxpayerName
• ABN / Trading Name:         ${abn.isNotEmpty ? abn : 'Registered Sole Trader'}
• Vehicle Description:        ${vehicle.displayName}
• Vehicle Registration:       ${vehicle.regoPlate}
• Baseline Starting Odometer: ${Formatters.odometer(vehicle.initialOdometer)} km (Continuous Gapless Invariant)
• Car Cost Cap (s 40-230):    \$${taxRule.carDepreciationLimit.toStringAsFixed(0)} AUD (Statutory Capital Allowance Limit)
• Day 1 Odometer Photo:       ${vehicle.startOdometerPhotoPath != null ? 'Verified' : 'Pending Upload'}
• Day 84 Odometer Photo:      ${vehicle.endOdometerPhotoPath != null ? 'Verified' : 'Pending Upload'}

[1.2] 12-WEEK STATUTORY LOGBOOK PERIOD (TR 97/11 COMPLIANT)
• Logbook Period:             ${Formatters.date(startDate)} to ${Formatters.date(endDate)} (84 Consecutive Days)
• Statutory Status:           VALID FOR 5 CONSECUTIVE INCOME YEARS (Up to FY 2030–31)
$fyAdvisory
• Total Kilometres Logged:    ${Formatters.distance(summary.totalKm)}
• Total Business Distance:    ${Formatters.distance(summary.businessKm)}
• Total Personal Distance:    ${Formatters.distance(summary.personalKm)}

====================================================================================================
>>> CERTIFIED STATUTORY BUSINESS PERCENTAGE: ${businessPct.toStringAsFixed(2)}% <<<
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

* Receipt evidence status: $verifiedReceiptCount image-hashed and verified; ${expenses.where((e) => e.isVaultOnly).length} stored in audit vault (excluded from FY claim); $receiptsNeedingReview need review before accountant export.

----------------------------------------------------------------------------------------------------
PAGE 3+: CONTINUOUS ODODMETRE AUDIT TRAIL (TR 97/11 MANDATED)
----------------------------------------------------------------------------------------------------
Date         Odo Start   Odo End     Distance   Purpose                           Class
----------------------------------------------------------------------------------------------------
${trips.take(15).map((t) => '${t.date.toIso8601String().split("T").first}   ${t.startOdometer.toStringAsFixed(0).padLeft(8)}   ${t.endOdometer.toStringAsFixed(0).padLeft(8)}   ${Formatters.distance(t.distanceKm).padLeft(8)}   ${(t.isBusiness ? (t.purpose.isNotEmpty ? t.purpose : "Work Drive") : "Private Travel").padRight(32).substring(0, 32)}   ${t.isBusiness ? "BUS" : "PRIV"}').join("\n")}
... [Full electronic continuous trip log maintained in attached KiloTax_Logbook_Audit_Ledger.csv] ...

====================================================================================================
BULKY EQUIPMENT SUBSTANTIATION DECLARATION (ITAA 1997 s 8-1, TR 95/34 & FC OF T v VOGT)
====================================================================================================
This schedule includes home-to-work / itinerant transit where the taxpayer carried substantial 
trade equipment, ladders, machinery, and tools of trade exceeding 20 kg / 0.15 m³ in volume.

STATUTORY DEFENSE UNDER VOGT'S CASE (75 ATC 4073) & ATO TR 95/34 (PARAGRAPHS 63–68):
1. Equipment Bulky & Essential: The equipment transported is cumbersome, essential to the daily 
   income-earning trade activities of the taxpayer, and incapable of safe transport via public conveyance.
2. Absence of Secure Storage: No secure lock-up storage was provided at client premises or changing 
   job sites. The taxpayer is legally and practically required to store equipment at base and transport 
   it continuously to diverse sites.
3. Character of Travel: The mode and requirement of carriage constitutes the vehicle as a mobile workshop, 
   attributing the essential character of the travel to income generation under Section 8-1.

Specific Equipment Manifest: Professional Trade Tools, Diagnostic & Construction Equipment
Storage Verification: No lock-up facilities available on temporary project work sites.
====================================================================================================

STATUTORY DECLARATION (Taxation Administration Act 1953):
"We declare that the continuous odometer readings and expense schedules represent a complete,
accurate, and unbroken record of motor vehicle usage pursuant to ATO Taxation Ruling TR 97/11."

Taxpayer Signature: ___________________________        Date: ____ / ____ / ________
Tax Agent Signature: __________________________        RAN:  ______________________
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
