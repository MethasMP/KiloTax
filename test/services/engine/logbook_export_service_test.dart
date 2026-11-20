import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/audit_evidence.dart';
import 'package:kilotax/data/models/tax_summary.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/logbook_export_service.dart';

void main() {
  group('LogbookExportService Tab 3 & Provenance (INV-B05)', () {
    test(
        'build logbook export with one expense; parse Tab 3 row; assert all 10 column values non-empty',
        () async {
      final service = LogbookExportService();
      final vehicle = Vehicle(
        id: 'v-1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'INV-B05',
        initialOdometer: 10000,
        taxMethod: TaxMethod.logbook,
      );

      final trips = [
        Trip(
          id: 'trip-1',
          vehicleId: vehicle.id,
          date: DateTime(2026, 8, 1),
          distanceKm: 50.0,
          purpose: 'Trade job site',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10050,
          taxMethod: TaxMethod.logbook,
          evidenceLinks: [
            TripEvidenceLink(
              id: 'link-1',
              tripId: 'trip-1',
              expenseId: 'exp-1',
              evidenceId: 'ev-999',
            ),
          ],
        ),
      ];

      final expense = VehicleExpense(
        id: 'exp-1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 1),
        amount: 110.0,
        gstAmount: 10.0,
        supplier: 'Bunnings Warehouse',
        supplierAbn: '26 008 672 179',
        category: ExpenseCategory.fuel,
        receiptPath: 'https://storage.kilotax.com/receipts/exp-1.webp',
        businessPercentage: 80.0,
        sha256Hash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final evidence = AuditEvidence(
        id: 'ev-999',
        entityId: 'exp-1',
        storagePath: 'receipts/user1/2026/08/exp-1.webp',
        imageSha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        capturedAt: DateTime(2026, 8, 1),
        evidenceType: EvidenceType.expenseReceipt,
      );

      final summary = TaxSummary(
        totalKm: 50,
        businessKm: 50,
        personalKm: 0,
        totalRunningExpenses: 110,
        totalDirectDeductions: 0,
        centsPerKmClaim: 0,
        logbookClaim: 88,
      );

      final bytes = await service.buildWorkbook(
        vehicle: vehicle,
        trips: trips,
        expenses: [expense],
        summary: summary,
        taxRule: AppConstants.activeTaxRule,
        auditEvidenceList: [evidence],
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet3File = archive.findFile('xl/worksheets/sheet3.xml')!;
      final content = utf8.decode(sheet3File.content as List<int>);

      const requiredColumns = [
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
      ];

      for (final col in requiredColumns) {
        expect(content, contains(col),
            reason: 'Sheet 3 must contain column: $col');
      }

      // Assert all 10 column values are non-empty and present
      expect(content, contains('Bunnings Warehouse'),
          reason: 'Merchant_Name value missing');
      expect(content, contains('26 008 672 179'),
          reason: 'Merchant_ABN value missing');
      expect(content, contains('110'), reason: 'Gross_Amount_AUD value missing');
      expect(content, contains('10'), reason: 'GST_Amount_AUD value missing');
      expect(content, contains('100'), reason: 'Net_Amount_AUD value missing');
      expect(content, contains('80'), reason: 'Business_Percent value missing');
      expect(content, contains('88'),
          reason: 'Deductible_Amount_AUD value missing');
      expect(content, contains('https://storage.kilotax.com/receipts/exp-1.webp'),
          reason: 'Cloud_Receipt_URL value missing');
      expect(content, contains('ev-999'),
          reason: 'AuditEvidence_Id value missing');
      expect(
          content,
          contains(
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
          reason: 'Image_SHA256 value missing');
    });
  });
}
