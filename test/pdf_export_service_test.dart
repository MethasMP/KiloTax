import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/services/engine/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PdfExportService cleanly exports PDF with unicode bullet symbols without font fallback error', () async {
    final vehicle = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Hilux • SR5 Work Rig',
      regoPlate: 'ABC•123',
      initialOdometer: 10000,
    );

    final summary = TaxSummary(
      totalKm: 1200,
      businessKm: 900,
      personalKm: 300,
      businessPercentage: 75.0,
      totalRunningExpenses: 2500,
      totalDirectDeductions: 120,
      centsPerKmClaim: 819.0,
      logbookClaim: 1995.0,
      recommendedMethod: RecommendedMethod.centsPerKm,
      taxSavingsDiff: 0,
    );

    final bytes = await PdfExportService.generateBoxD1SummaryPdf(
      vehicle: vehicle,
      trips: [],
      summary: summary,
      taxRule: AppConstants.activeTaxRule,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
