import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/accountant_workpaper_generator.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';

void main() {
  group('AccountantWorkpaperGenerator', () {
    late AccountantWorkpaperGenerator generator;

    setUp(() {
      generator = AccountantWorkpaperGenerator();
    });

    test('Generates a recorded-data workpaper without certifying receipts', () {
      final trips = [
        Trip(
          id: 't1',
          vehicleId: 'veh_hilux',
          date: DateTime(2026, 8, 1),
          startOdometer: 20000.0,
          endOdometer: 20080.0,
          distanceKm: 80.0,
          purpose: 'Site Delivery & Bunnings',
          classification: TripClassification.business,
          linkedExpenseIds: ['exp_bunnings_1'],
        ),
        Trip(
          id: 't2',
          vehicleId: 'veh_hilux',
          date: DateTime(2026, 8, 2),
          startOdometer: 20080.0,
          endOdometer: 20100.0,
          distanceKm: 20.0,
          purpose: 'Weekend family outing',
          classification: TripClassification.personal,
        ),
      ];

      final expenses = [
        VehicleExpense(
          id: 'exp_bunnings_1',
          vehicleId: 'veh_hilux',
          amount: 350.00,
          category: ExpenseCategory.toolsMaterials,
          date: DateTime(2026, 8, 1),
          notes: 'Bunnings Building Supplies',
          receiptPath: '/vault/bunnings_001.jpg',
        ),
        VehicleExpense(
          id: 'exp_fuel_1',
          vehicleId: 'veh_hilux',
          amount: 120.00,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 8, 5),
          notes: 'Ampol Diesel',
          receiptPath: '/vault/ampol_001.jpg',
        ),
      ];

      final workpaper = generator.generateWorkpaper(
        clientName: 'Mick Dundee (Sparky)',
        abn: '12 345 678 901',
        vehicleModel: '2024 Toyota Hilux SR5 (Rego: 1TR-8DE)',
        trips: trips,
        expenses: expenses,
        financialYear: '2026-2027',
      );

      expect(workpaper.contains('KILOCLAIM RECORDED DATA WORKPAPER'), true);
      expect(workpaper.contains(r'Mick Dundee \(Sparky\)'), true);
      expect(workpaper.contains('12 345 678 901'), true);
      expect(workpaper.contains('Total Logged: 100.0 km'), true);
      expect(workpaper.contains('Business Kilometres: 80.0 km'), true);
      expect(workpaper.contains('Business Use Percentage: 80.00%'), true);
      expect(
          workpaper
              .contains('Expenses with a saved receipt reference: \$470.00'),
          true);
      expect(workpaper, isNot(contains('Tax deductions are substantiated')));
      expect(workpaper, isNot(contains('Verified business claim')));
      expect(
          workpaper
              .contains('Review records and tax treatment with your tax agent'),
          true);
    });
  });
  test('OCR matches and changed files never become human-confirmed claims', () {
    VehicleExpense expense(String id, ReceiptReviewStatus status) =>
        VehicleExpense(
          id: id,
          vehicleId: 'v1',
          amount: 20,
          date: DateTime(2026, 8, 1),
          category: ExpenseCategory.fuel,
          receiptPath: '/private/receipt',
          receiptAudit: ReceiptAuditTrail(
              reviewStatus: status, capturedAt: DateTime(2026, 8, 1)),
        );
    final text = AccountantWorkpaperGenerator().generateWorkpaper(
      clientName: 'Not provided',
      abn: 'Not provided',
      vehicleModel: 'Toyota',
      trips: [],
      financialYear: '2026-27',
      expenses: [
        expense('ocr', ReceiptReviewStatus.verified),
        expense('changed', ReceiptReviewStatus.confirmed),
        expense('human', ReceiptReviewStatus.confirmed),
        expense('missing', ReceiptReviewStatus.confirmed),
      ],
      receiptInspections: const {
        'ocr': ReceiptFileInspection(status: ReceiptFileStatus.available),
        'changed': ReceiptFileInspection(status: ReceiptFileStatus.changed),
        'human': ReceiptFileInspection(status: ReceiptFileStatus.available),
        'missing': ReceiptFileInspection(status: ReceiptFileStatus.missing),
      },
    );
    expect(text, contains('Human-confirmed with available files: 1 of 4'));
    expect(text, contains('OCR-matched with available files: 1 of 4'));
    expect(text, contains('Missing or unconfirmed receipts: 3 of 4'));
    expect(text, isNot(contains('Verified business claim')));
    expect(text, isNot(contains('/private/receipt')));
  });
  test('workpaper renders user text as literal Markdown table content', () {
    final text = AccountantWorkpaperGenerator().generateWorkpaper(
      clientName: '[click](https://example.com)|<script>',
      abn: 'Not provided',
      vehicleModel: 'Toyota',
      trips: [],
      expenses: [],
      financialYear: '2026-27',
    );
    expect(text,
        contains(r'\[click\]\(https://example.com\)&#124;&lt;script&gt;'));
  });
}
