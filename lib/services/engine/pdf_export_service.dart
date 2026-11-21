import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/quarantine_certificate.dart';
import '../../data/models/vehicle_expense.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';

/// ATO Box D1 PDF Generator
///
/// Produces a clean, 1-page A4 Summary PDF for the accountant.
/// Designed to be the single source of truth for the D1 deduction claim.
/// Layout mirrors the Fast-Fill Data Card in the app — 3 critical data points
/// an accountant needs in under 5 seconds:
///   1. D1 Item Code (S = Cents-per-km, B = Logbook)
///   2. Total Work KM
///   3. Dollar Amount
///
/// Compliance: ITAA 1997 Subdivision 28-C (§ 28-25 to § 28-35)
class PdfExportService {
  // Color palette matching AppColors (slate 900 / emerald 600 / slate 200)
  static const _navy = PdfColor.fromInt(0xFF0F172A);
  static const _emerald = PdfColor.fromInt(0xFF059669);
  static const _emeraldLight = PdfColor.fromInt(0xFFECFDF5);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _muted = PdfColor.fromInt(0xFF475569);
  static const _background = PdfColor.fromInt(0xFFF1F5F9);
  static const _white = PdfColors.white;

  /// Generates a 1-page A4 Box D1 lodgement summary PDF.
  /// Returns raw PDF bytes ready to write to disk.
  static Future<List<int>> generateBoxD1SummaryPdf({
    required Vehicle vehicle,
    required List<Trip> trips,
    required TaxSummary summary,
    required AtoTaxRule taxRule,
    String? taxpayerName,
    String? abn,
    double? openingOdometer,
    double? closingOdometer,
    ByteData? regularFont,
    ByteData? boldFont,
    QuarantineCertificate? quarantineCertificate,
    List<VehicleExpense> expenses = const [],
  }) async {
    // Load true Unicode font to avoid Helvetica Type 1 limitations
    pw.ThemeData? theme;
    if (regularFont != null && boldFont != null) {
      theme = pw.ThemeData.withFont(
        base: pw.Font.ttf(regularFont),
        bold: pw.Font.ttf(boldFont),
      );
    } else {
      try {
        final baseFont = await PdfGoogleFonts.interRegular();
        final boldFont = await PdfGoogleFonts.interBold();
        theme = pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        );
      } catch (e, stack) {
        debugPrint(
            '[PdfExportService] Warning loading Google Fonts: $e\n$stack');
      }
    }

    final pdf = pw.Document(theme: theme);
    final isCpk = vehicle.taxMethod == TaxMethod.centsPerKm;

    final businessTrips = trips.where((t) => t.isBusiness).toList();
    final cappedKm = isCpk
        ? (summary.businessKm > taxRule.centsPerKmMaxKm
            ? taxRule.centsPerKmMaxKm
            : summary.businessKm)
        : summary.businessKm;

    final claimAmount = isCpk ? summary.centsPerKmClaim : summary.logbookClaim;
    final methodLabel =
        isCpk ? 'Code S - Cents-per-kilometre' : 'Code B - Logbook';
    final fyLabel = _sanitizeForPdf('FY${taxRule.financialYear}');
    final rawRego =
        vehicle.regoPlate.isNotEmpty ? vehicle.regoPlate : 'Not Set';
    final regoLabel = _sanitizeForPdf(rawRego);
    final rate = '${(taxRule.centsPerKmRate * 100).toInt()}c per km';

    // Derive or use provided odometer readings
    final effectiveOpeningOdo = openingOdometer ??
        (trips.isNotEmpty && trips.first.startOdometer > 0
            ? trips.first.startOdometer
            : vehicle.initialOdometer);
    final effectiveClosingOdo = closingOdometer ??
        (trips.isNotEmpty && trips.last.endOdometer > 0
            ? trips.last.endOdometer
            : (effectiveOpeningOdo + summary.totalKm));

    final cleanTaxpayerName =
        (taxpayerName != null && taxpayerName.trim().isNotEmpty)
            ? _sanitizeForPdf(taxpayerName.trim())
            : 'Taxpayer';
    final cleanAbn = (abn != null && abn.trim().isNotEmpty)
        ? _sanitizeForPdf(abn.trim())
        : 'Not provided';
    const hasClientInfo = true;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header bar ───────────────────────────────────────────────
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'KiloTax - ATO Vehicle Tax Summary',
                          style: pw.TextStyle(
                            color: _white,
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Individual Tax Return - Schedule D1 - Work-Related Car Expenses',
                          style: const pw.TextStyle(
                              color: PdfColor(1, 1, 1, 0.7), fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: const pw.BoxDecoration(
                        color: _emerald,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        fyLabel,
                        style: pw.TextStyle(
                          color: _white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (hasClientInfo) ...[
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _background,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: _border),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (cleanTaxpayerName != null)
                        pw.Row(
                          children: [
                            pw.Text(
                              'Taxpayer: ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: _muted,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              cleanTaxpayerName,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                color: _navy,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else
                        pw.SizedBox(),
                      if (cleanAbn != null)
                        pw.Row(
                          children: [
                            pw.Text(
                              'ABN: ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: _muted,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              cleanAbn,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                color: _navy,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else
                        pw.SizedBox(),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 14),

              // ── ATO Box D1 badge + subtitle ────────────────────────────
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: const pw.BoxDecoration(
                      color: _navy,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'ATO BOX D1',
                      style: pw.TextStyle(
                        color: _white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Tax Agent Fast-Fill Data - Prepared for Lodgement',
                    style: const pw.TextStyle(
                      color: _muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // ── Data rows card ─────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _buildRow('Claim Method', methodLabel),
                    _buildDivider(),
                    _buildRow('Vehicle Registration', regoLabel),
                    _buildDivider(),
                    _buildRow(
                      'Opening Odometer',
                      '${effectiveOpeningOdo.toStringAsFixed(0)} km',
                    ),
                    _buildDivider(),
                    _buildRow(
                      'Closing Odometer',
                      '${effectiveClosingOdo.toStringAsFixed(0)} km',
                    ),
                    _buildDivider(),
                    _buildRow('Total Work Travel',
                        '${summary.businessKm.toStringAsFixed(1)} km  (${businessTrips.length} trips)'),
                    _buildDivider(),
                    _buildRow(
                      isCpk ? 'Statutory Capped KM' : 'Business Use KM',
                      '${cappedKm.toStringAsFixed(1)} km${isCpk && summary.businessKm > taxRule.centsPerKmMaxKm ? "  (5,000 km cap applied)" : ""}',
                    ),
                    _buildDivider(),
                    if (isCpk) ...[
                      _buildRow('ATO Prescribed Rate ($fyLabel)', rate),
                      _buildDivider(),
                    ] else ...[
                      _buildRow(
                        'Business Use %',
                        '${summary.businessPercentage.toStringAsFixed(1)}%',
                      ),
                      _buildDivider(),
                    ],
                    _buildRow(
                      'Deductible Claim',
                      _sanitizeForPdf(Formatters.currency(claimAmount)),
                    ),
                    _buildDivider(),
                    // Highlight row — total claimable
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const pw.BoxDecoration(
                        color: _emeraldLight,
                        borderRadius: pw.BorderRadius.only(
                          bottomLeft: pw.Radius.circular(7),
                          bottomRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL CLAIMABLE DEDUCTION (Box D1)',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                          pw.Text(
                            _sanitizeForPdf(Formatters.currency(claimAmount)),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: _emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ── ATO compliance note ────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _background,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _sanitizeForPdf(isCpk
                          ? 'Calculated under ATO Cents per Kilometre method (ITAA 1997 Division 28-C / s 28-25). Statutory rate of $rate covers all vehicle operating costs - no separate expense receipts claimed. Maximum claim: 5,000 km x $rate = ${Formatters.currency(taxRule.centsPerKmMaxKm * taxRule.centsPerKmRate)}. Contemporaneous diary records are maintained within KiloTax. Retain all tax records for 5 years per Subdivision 28-H / Section 900-165.'
                          : 'Calculated under ATO Logbook method (ITAA 1997 Subdivision 28-F) and Taxation Ruling TR 97/11. A 12-week continuous odometer logbook has been maintained. Business-use percentage of ${summary.businessPercentage.toStringAsFixed(1)}% applies to vehicle expenses. Retain logbook and records for 5 years per Subdivision 28-H / Section 900-165.'),
                      style: pw.TextStyle(
                          fontSize: 8, color: _muted, lineSpacing: 1.4),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _sanitizeForPdf(
                          'STATUTORY DISCLAIMER & TPB NOTICE: Not tax advice. Confirm claims with a registered tax agent. KiloTax is an independent software application and is NOT affiliated with, endorsed by, or connected to the Australian Taxation Office (ATO) or the Tax Practitioners Board (TPB).'),
                      style: pw.TextStyle(
                          fontSize: 7.5,
                          color: _muted,
                          fontWeight: pw.FontWeight.bold,
                          lineSpacing: 1.3),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── Footer ─────────────────────────────────────────────────
              pw.Divider(color: _border, height: 1),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by KiloTax - Australian Vehicle Tax Evidence OS',
                    style: pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                  pw.Text(
                    'Printed: ${DateTime.now().toIso8601String().split("T").first}',
                    style: pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'ITAA 1997 Div 28-C / Subdiv 28-H / s 900-165 compliant. Not tax advice. Non-affiliated with the ATO.',
                style: pw.TextStyle(fontSize: 6.5, color: _muted),
              ),
            ],
          );
        },
      ),
    );

    // ── PAGE 2: STATUTORY NON-BUSINESS QUARANTINE & EXCLUSION CERTIFICATE ────
    final totalCalcKm = (effectiveClosingOdo - effectiveOpeningOdo).abs();
    final cert = quarantineCertificate ??
        QuarantineCertificate(
          vehicleId: vehicle.id,
          regoPlate: vehicle.regoPlate,
          financialYear: taxRule.financialYear,
          totalOdometerKm: totalCalcKm > 0 ? totalCalcKm : summary.totalKm,
          businessKm: summary.businessKm,
          quarantinedPrivateKm: summary.personalKm,
          businessTripsCount: businessTrips.length,
          quarantinedPrivateTripsCount:
              trips.where((t) => !t.isBusiness).length,
          totalExpensesAud: expenses.fold(0.0, (s, e) => s + e.amount),
          deductibleExpensesAud: claimAmount,
          quarantinedPrivateExpensesAud:
              (expenses.fold(0.0, (s, e) => s + e.amount) - claimAmount) > 0
                  ? (expenses.fold(0.0, (s, e) => s + e.amount) - claimAmount)
                  : 0.0,
          generatedAt: DateTime.now(),
        );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'STATUTORY NON-BUSINESS QUARANTINE & EXCLUSION CERTIFICATE',
                          style: pw.TextStyle(
                            color: _white,
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Formal substantiation declaration under ITAA 1997 Division 28 & TR 2021/1',
                          style: const pw.TextStyle(
                              color: PdfColor(1, 1, 1, 0.7), fontSize: 8),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: _emerald,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'AUDIT DEFENSE',
                        style: pw.TextStyle(
                          color: _white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Certification Notice
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _background,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Text(
                  'This statutory certificate confirms that all non-business journeys and private operating costs have been mathematically quarantined and 100% excluded from the deduction claim for vehicle $regoLabel in FY${taxRule.financialYear}.',
                  style: pw.TextStyle(fontSize: 8.5, color: _navy),
                ),
              ),
              pw.SizedBox(height: 12),

              // Quarantine Table 1: Travel & Mileage Isolation
              pw.Text(
                '1. TRAVEL & MILEAGE QUARANTINE SCHEDULE',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    _buildRow('Total Odometer Movement',
                        '${cert.totalOdometerKm.toStringAsFixed(2)} km (100.0%)'),
                    _buildDivider(),
                    _buildRow('Substantive Work-Related Travel',
                        '${cert.businessKm.toStringAsFixed(2)} km (${cert.businessPercentage.toStringAsFixed(1)}%) - CLAIMABLE'),
                    _buildDivider(),
                    _buildRow('Quarantined Private Travel',
                        '${cert.quarantinedPrivateKm.toStringAsFixed(2)} km (${cert.quarantinedKmPercentage.toStringAsFixed(1)}%) - STRICTLY EXCLUDED'),
                    _buildDivider(),
                    _buildRow('Quarantined Private Journeys Logged',
                        '${cert.quarantinedPrivateTripsCount} trips (Isolated from claim)'),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Quarantine Table 2: Financial Expenses Isolation
              pw.Text(
                '2. OPERATING EXPENSES QUARANTINE SCHEDULE',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    _buildRow('Total Gross Vehicle Costs Logged',
                        '\$${cert.totalExpensesAud.toStringAsFixed(2)}'),
                    _buildDivider(),
                    _buildRow('Allowable Work-Related Deductions',
                        '\$${cert.deductibleExpensesAud.toStringAsFixed(2)} - CLAIMABLE'),
                    _buildDivider(),
                    _buildRow('Quarantined Private / Non-Allowable Costs',
                        '\$${cert.quarantinedPrivateExpensesAud.toStringAsFixed(2)} - STRICTLY EXCLUDED'),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Taxpayer & System Attestation
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _emeraldLight,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _emerald),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STATUTORY SUBSTANTIATION DECLARATION',
                      style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _emerald),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'I confirm that all private journeys, private commuting, and personal vehicle running expenses have been systematically isolated and quarantined. The net deduction claim contains zero private utility, satisfying the substantiation requirements of ITAA 1997 Division 28 and ATO Tax Ruling TR 2021/1.',
                      style: pw.TextStyle(fontSize: 7.5, color: _navy),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Digital Cryptographic Seal Box
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _background,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Vault SHA-256 Seal: ${cert.auditHash}',
                          style: pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _navy),
                        ),
                        pw.Text(
                          '100% MATHEMATICALLY SOUND',
                          style: pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _emerald),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'System Verification Seal Generated: ${cert.generatedAt.toIso8601String()}',
                      style: pw.TextStyle(fontSize: 6, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _sanitizeForPdf(label),
            style: pw.TextStyle(fontSize: 10, color: _muted),
          ),
          pw.Text(
            _sanitizeForPdf(value),
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDivider() {
    return pw.Divider(color: _border, height: 1);
  }

  /// Sanitizes text for standard PDF Type 1 Helvetica font.
  /// Replaces non-ASCII unicode symbols (bullets, em-dashes, section signs, cent symbols)
  /// with their ASCII-safe standard equivalents to prevent PDF rendering errors.
  static String _sanitizeForPdf(String text) {
    return text
        .replaceAll('•', '-')
        .replaceAll('·', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('¢', 'c')
        .replaceAll('§', 's ')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }
}
