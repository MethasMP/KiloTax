import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/quarantine_certificate.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/engine/pdf_export_service.dart';

String _extractPdfStreams(List<int> pdfBytes) {
  final latin = latin1.decode(pdfBytes);
  final buffer = StringBuffer();
  var searchIndex = 0;
  while (true) {
    final streamStart = latin.indexOf('stream\n', searchIndex);
    if (streamStart == -1) break;
    final dataStart = streamStart + 'stream\n'.length;
    final streamEnd = latin.indexOf('\nendstream', dataStart);
    if (streamEnd == -1) break;

    final streamBytes = pdfBytes.sublist(dataStart, streamEnd);
    try {
      final decompressed = zlib.decode(streamBytes);
      buffer.write(latin1.decode(decompressed));
    } catch (_) {
      buffer.write(latin.substring(dataStart, streamEnd));
    }
    searchIndex = streamEnd + '\nendstream'.length;
  }
  return buffer.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfExportService Statutory Quarantine Certificate Page', () {
    test('PDF includes Page 2 with Statutory Quarantine Certificate and SHA-256 seal', () async {
      final vehicle = Vehicle(
        id: 'v-hilux-quarantine',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TRD-777',
        initialOdometer: 20000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 't-b1',
          vehicleId: vehicle.id,
          date: DateTime(2025, 8, 1),
          distanceKm: 80.0,
          purpose: 'Commercial site visit',
          classification: TripClassification.business,
          startOdometer: 20000,
          endOdometer: 20080,
        ),
        Trip(
          id: 't-p1',
          vehicleId: vehicle.id,
          date: DateTime(2025, 8, 2),
          distanceKm: 20.0,
          purpose: 'Weekend personal groceries',
          classification: TripClassification.personal,
          startOdometer: 20080,
          endOdometer: 20100,
        ),
      ];

      final summary = TaxSummary(
        totalKm: 100.0,
        businessKm: 80.0,
        personalKm: 20.0,
        totalRunningExpenses: 1000.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 0.0,
        logbookClaim: 800.0,
      );

      final cert = QuarantineCertificate(
        vehicleId: vehicle.id,
        regoPlate: vehicle.regoPlate,
        financialYear: '2025-26',
        totalOdometerKm: 100.0,
        businessKm: 80.0,
        quarantinedPrivateKm: 20.0,
        businessTripsCount: 1,
        quarantinedPrivateTripsCount: 1,
        totalExpensesAud: 1000.0,
        deductibleExpensesAud: 800.0,
        quarantinedPrivateExpensesAud: 200.0,
        generatedAt: DateTime(2025, 9, 1),
      );

      final pdfBytes = await PdfExportService.generateBoxD1SummaryPdf(
        vehicle: vehicle,
        trips: trips,
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'Jack Builder',
        abn: '51 824 753 556',
        openingOdometer: 20000,
        closingOdometer: 20100,
        quarantineCertificate: cert,
      );

      expect(pdfBytes, isNotEmpty);
      final rawStreams = _extractPdfStreams(pdfBytes);
      final wordRegex = RegExp(r'\(([^)]+)\)');
      final pdfContent = wordRegex
          .allMatches(rawStreams)
          .map((m) => m.group(1)!)
          .join(' ');

      // Verify Page 2 Statutory Quarantine Certificate presence
      expect(pdfContent, contains('STATUTORY NON-BUSINESS QUARANTINE'));
      expect(pdfContent, contains('ITAA 1997 Division 28'));
      expect(pdfContent, contains('TR 2021/1'));
      expect(pdfContent, contains('Quarantined Private Travel'));
      expect(pdfContent, contains('20.00 km'));
      expect(pdfContent, contains('Vault SHA-256 Seal'));
      expect(pdfContent, contains(cert.auditHash.substring(0, 16)));
    });
  });
}
