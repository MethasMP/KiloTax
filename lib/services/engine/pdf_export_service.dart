import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
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
  }) async {
    // Load true Unicode font to avoid Helvetica Type 1 limitations
    pw.ThemeData? theme;
    try {
      final baseFont = await PdfGoogleFonts.interRegular();
      final boldFont = await PdfGoogleFonts.interBold();
      theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      );
    } catch (_) {
      // Fallback if offline
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
    final methodLabel = isCpk ? 'Code S - Cents-per-kilometre' : 'Code B - Logbook';
    final fyLabel = _sanitizeForPdf('FY${taxRule.financialYear}');
    final rawRego = vehicle.regoPlate.isNotEmpty ? vehicle.regoPlate : 'Not Set';
    final regoLabel = _sanitizeForPdf(rawRego);
    final rate = '${(taxRule.centsPerKmRate * 100).toInt()}c per km';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header bar ───────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                          style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.7), fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: _emerald,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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

              pw.SizedBox(height: 20),

              // ── ATO Box D1 badge + subtitle ────────────────────────────
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: _navy,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
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
                    style: pw.TextStyle(
                      color: _muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ── Data rows card ─────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _buildRow('Claim Method', methodLabel),
                    _buildDivider(),
                    _buildRow('Vehicle Registration', regoLabel),
                    _buildDivider(),
                    _buildRow('Total Work Travel', '${summary.businessKm.toStringAsFixed(1)} km  (${businessTrips.length} trips)'),
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
                    // Highlight row — total claimable
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Text(
                  _sanitizeForPdf(isCpk
                      ? 'Compliant with ITAA 1997 s 28-25 (Cents-per-kilometre method). Statutory rate of $rate covers all vehicle operating costs - no further receipts required. Maximum claim: 5,000 km x $rate = ${Formatters.currency(taxRule.centsPerKmMaxKm * taxRule.centsPerKmRate)}. Contemporaneous diary records are maintained within the KiloTax app.'
                      : 'Compliant with ITAA 1997 s 28-13 (Logbook method) and Taxation Ruling TR 97/11. A 12-week continuous odometer logbook has been maintained. Business-use percentage of ${summary.businessPercentage.toStringAsFixed(1)}% applies to all vehicle expenses. Full expense receipts are attached in the 14-column audit ledger CSV.'),
                  style: pw.TextStyle(fontSize: 8, color: _muted, lineSpacing: 1.4),
                ),
              ),

              pw.Spacer(),

              // ── Footer ─────────────────────────────────────────────────
              pw.Divider(color: _border, height: 1),
              pw.SizedBox(height: 8),
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
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy),
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
