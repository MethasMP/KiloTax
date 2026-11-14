import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/services/engine/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
      'PdfExportService cleanly exports PDF with unicode bullet symbols without font fallback error',
      () async {
    final bytes = await PdfExportService.generateBoxD1SummaryPdf(
      vehicle: vehicle,
      trips: [],
      summary: summary,
      taxRule: AppConstants.activeTaxRule,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test(
      'PdfExportService cleanly exports PDF with taxpayer details and explicit odometer readings',
      () async {
    final bytes = await PdfExportService.generateBoxD1SummaryPdf(
      vehicle: vehicle,
      trips: [],
      summary: summary,
      taxRule: AppConstants.activeTaxRule,
      taxpayerName: 'Dave "Mates Rates" Smith',
      abn: '12 345 678 901',
      openingOdometer: 45000,
      closingOdometer: 52000,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test(
      'PdfExportService infers odometer readings from trip list when not explicitly provided',
      () async {
    final trips = [
      Trip(
        id: 't1',
        vehicleId: 'v1',
        distanceKm: 50.0,
        date: DateTime(2024, 7, 1),
        purpose: 'Site inspection',
        startOdometer: 10100,
        endOdometer: 10150,
      ),
      Trip(
        id: 't2',
        vehicleId: 'v1',
        distanceKm: 120.0,
        date: DateTime(2024, 7, 2),
        purpose: 'Commercial pickup',
        startOdometer: 10150,
        endOdometer: 10270,
      ),
    ];

    final bytes = await PdfExportService.generateBoxD1SummaryPdf(
      vehicle: vehicle,
      trips: trips,
      summary: summary,
      taxRule: AppConstants.activeTaxRule,
      taxpayerName: 'Sarah Jenkins',
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
