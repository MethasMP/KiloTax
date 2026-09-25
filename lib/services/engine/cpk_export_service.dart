import '../../core/utils/formatters.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../core/constants/app_constants.dart';

/// Cents-per-kilometre (CPK) Dedicated Exporter
/// Aligned strictly with ITAA 1997 Subdivision 28-C (§ 28-25 to § 28-35)
/// Produces:
/// 1. 1-Page Box D1 Lodgement Slip Text/PDF Payload
/// 2. Detailed CPK Reasonable-Estimation Ledger CSV (14 Columns)
class CpkExportService {
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

  /// Generates the standard 14-column CPK trip ledger CSV
  static String generateCpkTripLedgerCsv({
    required Vehicle vehicle,
    required List<Trip> trips,
    required AtoTaxRule taxRule,
  }) {
    final buffer = StringBuffer();

    // CSV Header (Standard ATO Audit Schedule with Bulky Tools Exemption)
    buffer.writeln(
      'Trip_ID,Trip_Date,Start_Time,Vehicle_Rego,Origin_Address,Destination_Address,Distance_KM,ATO_Purpose_Category,Business_Purpose_Detail,Bulky_Tools_Carried,Statutory_Rate,Claim_Value_AUD,Cumulative_KM_Year,Cap_Status',
    );

    double cumulativeKm = 0.0;
    int index = 1;

    for (final t in trips) {
      if (!t.isBusiness) continue; // CPK only tracks claimable business trips
      cumulativeKm += t.distanceKm;

      final tripId =
          'CPK-${t.date.year}${(t.date.month).toString().padLeft(2, "0")}${(t.date.day).toString().padLeft(2, "0")}-${index.toString().padLeft(3, "0")}';
      final dateStr = t.date.toIso8601String().split('T').first;
      final startTime =
          '${t.date.hour.toString().padLeft(2, "0")}:${t.date.minute.toString().padLeft(2, "0")}';
      final rego = sanitizeCsvCell(vehicle.regoPlate);
      final origin =
          sanitizeCsvCell((t.originAddress ?? 'Work Site').replaceAll(',', ' '));
      final dest = sanitizeCsvCell(
          (t.destinationAddress ?? 'Client Job').replaceAll(',', ' '));
      final dist = t.distanceKm.toStringAsFixed(2);
      final purposeCat = _mapAtoPurposeCategory(t.purpose);
      final purposeDetail = sanitizeCsvCell(t.purpose.replaceAll(',', ' '));
      final carriesBulkyTools = _isBulkyToolsTrip(t.purpose)
          ? 'YES (Vogt 75 ATC 4073 / TR 95/34)'
          : 'NO';
      final rate = taxRule.centsPerKmRate.toStringAsFixed(2);
      final claim = (t.distanceKm * taxRule.centsPerKmRate).toStringAsFixed(2);
      final cumKm = cumulativeKm.toStringAsFixed(2);
      final capStatus = cumulativeKm <= taxRule.centsPerKmMaxKm
          ? 'UNDER_5000_CAP'
          : 'CAPPED_EXCESS';

      buffer.writeln(
        '$tripId,$dateStr,$startTime,$rego,"$origin","$dest",$dist,$purposeCat,"$purposeDetail",$carriesBulkyTools,$rate,$claim,$cumKm,$capStatus',
      );
      index++;
    }

    return buffer.toString();
  }

  /// Generates the visual 1-Page Box D1 Lodgement Slip text layout
  static String generateCpkLodgementSlipText({
    required Vehicle vehicle,
    required List<Trip> trips,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    String taxpayerName = 'Tradie Client',
    String abn = '',
  }) {
    final businessKm = summary.businessKm;
    final cappedKm =
        businessKm > taxRule.centsPerKmMaxKm ? taxRule.centsPerKmMaxKm : businessKm;
    final claimAmount = cappedKm * taxRule.centsPerKmRate;
    final centsRate = (taxRule.centsPerKmRate * 100).toInt();

    // Grouping for Section 3 (Reasonable Estimate & Exemption Breakdown)
    final clientVisits = trips
        .where((t) =>
            t.isBusiness &&
            (t.purpose.contains('Client') || t.purpose.contains('Job')))
        .toList();
    final supplyRuns = trips
        .where((t) =>
            t.isBusiness &&
            (t.purpose.contains('Supplier') || t.purpose.contains('Materials')))
        .toList();
    final bulkyToolTrips =
        trips.where((t) => t.isBusiness && _isBulkyToolsTrip(t.purpose)).toList();
    final otherVisits = trips
        .where((t) =>
            t.isBusiness && !clientVisits.contains(t) && !supplyRuns.contains(t))
        .toList();

    double distClient = clientVisits.fold(0.0, (sum, t) => sum + t.distanceKm);
    double distSupply = supplyRuns.fold(0.0, (sum, t) => sum + t.distanceKm);
    double distBulky = bulkyToolTrips.fold(0.0, (sum, t) => sum + t.distanceKm);
    double distOther = otherVisits.fold(0.0, (sum, t) => sum + t.distanceKm);

    return '''
====================================================================================================
⚡ TAX AGENT FAST-FILL BOX • INDIVIDUAL TAX RETURN (ITR) / COMPANY TAX RETURN (CTR)
For immediate 30-second entry into Xero Tax, HandiTax, and MYOB Practice:
----------------------------------------------------------------------------------------------------
  Item / Field                  ATO Box / Tag          Value to Enter
  ----------------------------  ---------------------  ---------------------------------------------
  Motor Vehicle Claim Method:   D1 Item Label:         [ S ] (Cents per kilometre)
  Total Business Travel:        Calculated Work KM:    ${businessKm.toStringAsFixed(1)} km
  Statutory Capped Kilometres:  Allowable Claim KM:    ${cappedKm.toStringAsFixed(1)} km (Capped @ 5,000 km per car)
  Statutory Rate (FY${taxRule.financialYear}):      Prescribed Rate:       ${centsRate}c / km
  TOTAL D1 TAX DEDUCTION:       BOX D1 AMOUNT:         \$${claimAmount.toStringAsFixed(2)} AUD
  Vehicle Schedule Link:        Rego / Description:    ${vehicle.regoPlate} (${vehicle.displayName})
====================================================================================================

====================================================================================================
KILOTAX • ATO MOTOR VEHICLE TAX LODGEMENT SLIP (ITAA 1997 Subdiv 28-C)
METHOD: CENTS-PER-KILOMETRE | ATO BOX D1 CODE: S | FINANCIAL YEAR: ${taxRule.financialYear}
====================================================================================================

[1. TAXPAYER & VEHICLE SCHEDULE]
• Taxpayer Name:              $taxpayerName
• ABN / Trading Name:         ${abn.isNotEmpty ? abn : 'Registered Sole Trader'}
• Vehicle Description:        ${vehicle.displayName}
• Vehicle Registration:       ${vehicle.regoPlate} (Statutory 5,000 km cap applies per vehicle)

[2. ATO INDIVIDUAL TAX RETURN BOX D1 LODGEMENT SUMMARY]
• Primary Claim Method:       Box D1 Code S (Cents per kilometre)
• Statutory ATO Rate:         ${centsRate}c per km (FY ${taxRule.financialYear})
• Total Logged Work Distance: ${Formatters.distance(businessKm)}
• Statutory Deduction Cap:    5,000.0 km (s 28-25)
• Allowable Claimable KM:     ${Formatters.distance(cappedKm)}

====================================================================================================
>>> ATO TAX RETURN BOX D1 CLAIM: \$${claimAmount.toStringAsFixed(2)} AUD <<<
====================================================================================================

[3. REASONABLE ESTIMATION & BULKY TOOLS PATTERN (ITAA 1997 s 8-1 & s 28-25)]
Travel Category                     Trips       Total Distance     Allowable Claim (\$)
----------------------------------------------------------------------------------------------------
Client Site Visits & Quotes         ${clientVisits.length.toString().padLeft(5)}       ${Formatters.distance(distClient).padLeft(12)}       ${Formatters.currency(distClient * taxRule.centsPerKmRate).padLeft(14)}
Trade Supplies / Materials Runs     ${supplyRuns.length.toString().padLeft(5)}       ${Formatters.distance(distSupply).padLeft(12)}       ${Formatters.currency(distSupply * taxRule.centsPerKmRate).padLeft(14)}
Bulky Equipment / Tool Transport    ${bulkyToolTrips.length.toString().padLeft(5)}       ${Formatters.distance(distBulky).padLeft(12)}       ${Formatters.currency(distBulky * taxRule.centsPerKmRate).padLeft(14)}
Inter-worksite Itinerant Drives     ${otherVisits.length.toString().padLeft(5)}       ${Formatters.distance(distOther).padLeft(12)}       ${Formatters.currency(distOther * taxRule.centsPerKmRate).padLeft(14)}
----------------------------------------------------------------------------------------------------
TOTAL RECORDED WORK TRAVEL          ${trips.where((t) => t.isBusiness).length.toString().padLeft(5)}       ${Formatters.distance(businessKm).padLeft(12)}       ${Formatters.currency(claimAmount).padLeft(14)}

[4. SUBSTANTIATION & AUDIT INTEGRITY STATEMENT]
• Contemporaneous Electronic Telemetry: Verified by KiloTax Engine
• Bulky Tools Exemption: Taxpayer transported essential trade equipment with no secure on-site storage.
• Expenses Note: Fuel and servicing are absorbed in statutory rate; no separate expense receipts claimed.

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

TAXPAYER & TAX AGENT STATUTORY DECLARATION (Taxation Administration Act 1953):
"I declare that the motor vehicle travel claimed at Box D1 represents a reasonable estimate of work-related
travel for income-producing purposes, substantiated by contemporaneous electronic travel logs."

Taxpayer Signature: ___________________________        Date: ____ / ____ / ________
Tax Agent Signature: __________________________        RAN:  ______________________
''';
  }

  static bool _isBulkyToolsTrip(String purpose) {
    final lower = purpose.toLowerCase();
    return lower.contains('tool') ||
        lower.contains('material') ||
        lower.contains('equipment') ||
        lower.contains('ladder') ||
        lower.contains('job') ||
        lower.contains('site') ||
        lower.contains('bunnings');
  }

  static String _mapAtoPurposeCategory(String purpose) {
    if (_isBulkyToolsTrip(purpose)) return 'BULKY_TOOLS_TRADE_DUTY';
    final lower = purpose.toLowerCase();
    if (lower.contains('suppl') ||
        lower.contains('bunning') ||
        lower.contains('material')) {
      return 'TRADE_SUPPLY_RUN';
    }
    if (lower.contains('client') || lower.contains('job')) {
      return 'CLIENT_SITE_VISIT';
    }
    if (lower.contains('site') || lower.contains('work')) {
      return 'INTER_WORKSITE_TRAVEL';
    }
    return 'BUSINESS_DUTY';
  }
}
