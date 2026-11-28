import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/accountant_workpaper_generator.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';

void main() {
  group('AccountantWorkpaperGenerator 3-State Receipt Verification', () {
    test(
        'distinguishes between reference, accessible file, and user-verified receipts',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('workpaper_test_');
      final validFile = File('${tempDir.path}/valid_receipt.jpg');
      await validFile.writeAsBytes([1, 2, 3, 4]);

      final expenses = [
        // 1. Fully verified: has path, file exists, user confirmed
        VehicleExpense(
          id: 'exp-1',
          vehicleId: 'v1',
          amount: 150.0,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 3, 1),
          receiptPath: validFile.path,
          receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.confirmed,
            capturedAt: DateTime(2026, 3, 1),
            imageSha256: 'dummy_hash_1',
          ),
        ),
        // 2. Attached & accessible, but NOT verified by user
        VehicleExpense(
          id: 'exp-2',
          vehicleId: 'v1',
          amount: 80.0,
          category: ExpenseCategory.maintenanceTyres,
          date: DateTime(2026, 3, 5),
          receiptPath: validFile.path,
          receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.needsReview,
            capturedAt: DateTime(2026, 3, 5),
          ),
        ),
        // 3. Has path reference, but file MISSING on disk
        VehicleExpense(
          id: 'exp-3',
          vehicleId: 'v1',
          amount: 60.0,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 3, 10),
          receiptPath: '${tempDir.path}/non_existent_file.jpg',
        ),
        // 4. Missing receipt entirely
        VehicleExpense(
          id: 'exp-4',
          vehicleId: 'v1',
          amount: 45.0,
          category: ExpenseCategory.tollsParking,
          date: DateTime(2026, 3, 15),
        ),
      ];

      final generator = AccountantWorkpaperGenerator();
      final inspections = {
        'exp-1':
            const ReceiptFileInspection(status: ReceiptFileStatus.available),
        'exp-2':
            const ReceiptFileInspection(status: ReceiptFileStatus.available),
        'exp-3': const ReceiptFileInspection(status: ReceiptFileStatus.missing),
        'exp-4': const ReceiptFileInspection(status: ReceiptFileStatus.missing),
      };

      final result = generator.generateWorkpaper(
        clientName: 'Dave Tradie',
        abn: '51 824 753 556',
        vehicleModel: 'Toyota Hilux SR5',
        trips: [
          Trip(
            id: 't-1',
            vehicleId: 'v1',
            date: DateTime(2026, 3, 1),
            startOdometer: 10000,
            endOdometer: 10100,
            distanceKm: 100,
            classification: TripClassification.business,
            purpose: 'Emergency plumbing at 42 Smith St',
          ),
        ],
        expenses: expenses,
        financialYear: '2025-2026',
        receiptInspections: inspections,
      );

      expect(result.contains('Attached receipt references: 3 of 4'), isTrue);
      expect(result.contains('Accessible on disk: 2 of 4'), isTrue);
      expect(
          result.contains(
              'Human-confirmed with available files: 1 of 4'),
          isTrue);
      expect(
          result.contains('Missing or unconfirmed receipts: 3 of 4'), isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}
