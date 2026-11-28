import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/data/models/tax_summary.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/engine/pdf_export_service.dart';

String _extractPdfStreams(List<int> pdfBytes) {
  final latin = latin1.decode(pdfBytes);
  final buffer = StringBuffer();
  // Extract all stream...endstream blocks
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

  group('PdfExportService ATO Required Fields (ITAA 1997 Div 28)', () {
    test('PDF contains all 7 ATO required audit fields and non-empty values',
        () async {
      final vehicle = Vehicle(
        id: 'v-pdf-ato',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'ATO-777',
        initialOdometer: 12000,
        taxMethod: TaxMethod.centsPerKm,
      );

      final trips = [
        Trip(
          id: 't-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 100.0,
          purpose: 'Plumbing trade call',
          classification: TripClassification.business,
          startOdometer: 12000,
          endOdometer: 12100,
          taxMethod: TaxMethod.centsPerKm,
        ),
      ];

      final summary = TaxSummary(
        totalKm: 100.0,
        businessKm: 100.0,
        personalKm: 0.0,
        totalRunningExpenses: 0.0,
        totalDirectDeductions: 0.0,
        centsPerKmClaim: 88.0,
        logbookClaim: 0.0,
      );

      final pdfBytes = await PdfExportService.generateBoxD1SummaryPdf(
        vehicle: vehicle,
        trips: trips,
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        taxpayerName: 'Mick Tradie',
        abn: '51 824 753 556',
        openingOdometer: 12000,
        closingOdometer: 12100,
      );

      expect(pdfBytes, isNotEmpty);
      final rawStreams = _extractPdfStreams(pdfBytes);
      final wordRegex = RegExp(r'\(([^)]+)\)');
      final pdfContent = wordRegex
          .allMatches(rawStreams)
          .map((m) => m.group(1)!)
          .join(' ');

      // Verify all 7 required ATO fields:
      // 1. taxpayerName
      expect(pdfContent, contains('Mick Tradie'),
          reason: 'taxpayerName must be present');
      // 2. abn
      expect(pdfContent, contains('51 824 753 556'),
          reason: 'abn must be present');
      // 3. vehicleRego
      expect(pdfContent, contains('ATO-777'),
          reason: 'vehicleRego must be present');
      // 4. financialYear
      expect(pdfContent, contains('FY2026'),
          reason: 'financialYear must be present');
      // 5. openingOdometer
      expect(pdfContent, contains('12000'),
          reason: 'openingOdometer must be present');
      // 6. closingOdometer
      expect(pdfContent, contains('12100'),
          reason: 'closingOdometer must be present');
      // 7. deductibleClaim
      expect(pdfContent, contains('Deductible Claim'),
          reason: 'deductibleClaim label must be present');
      expect(pdfContent, contains('88.00'),
          reason: 'deductibleClaim value must be present');
    });
  });
}
