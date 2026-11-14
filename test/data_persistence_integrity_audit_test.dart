import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Persistence & Integrity Audit (Storage Verification)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Trip serialization round-trip retains exact precision, timestamps, and invariants', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final originalDate = DateTime.utc(2026, 7, 15, 8, 30, 45);
      final trip = Trip(
        id: 't_audit_001',
        vehicleId: 'v_hilux_01',
        distanceKm: 42.875,
        date: originalDate,
        purpose: 'Bunnings & Client Job Site at Alexandria',
        startOdometer: 10050.2,
        endOdometer: 10093.075,
        classification: TripClassification.business,
        originAddress: '12 Commercial Rd, Richmond VIC',
        destinationAddress: '88 O’Riordan St, Alexandria NSW',
        linkedExpenseIds: ['exp_bunnings_01', 'exp_fuel_01'],
        taxMethod: TaxMethod.logbook,
        evidenceSource: 'auto_telemetry',
        jobReference: 'JOB-2026-409',
      );

      // Save to local storage
      final saved = await storage.saveTrips([trip]);
      expect(saved, isTrue);

      // Load back from local storage
      final loadedTrips = storage.loadTrips();
      expect(loadedTrips.length, 1);

      final loaded = loadedTrips.first;
      expect(loaded.id, trip.id);
      expect(loaded.vehicleId, trip.vehicleId);
      expect(loaded.distanceKm, trip.distanceKm);
      expect(loaded.date.toIso8601String(), originalDate.toIso8601String());
      expect(loaded.purpose, trip.purpose);
      expect(loaded.startOdometer, trip.startOdometer);
      expect(loaded.endOdometer, trip.endOdometer);
      expect(loaded.classification, TripClassification.business);
      expect(loaded.isBusiness, isTrue);
      expect(loaded.originAddress, trip.originAddress);
      expect(loaded.destinationAddress, trip.destinationAddress);
      expect(loaded.linkedExpenseIds, ['exp_bunnings_01', 'exp_fuel_01']);
      expect(loaded.taxMethod, TaxMethod.logbook);
      expect(loaded.evidenceSource, 'auto_telemetry');
      expect(loaded.jobReference, 'JOB-2026-409');
    });

    test('VehicleExpense serialization round-trip retains audit trail and cents accuracy', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final originalExpense = VehicleExpense(
        id: 'exp_fuel_999',
        vehicleId: 'v_hilux_01',
        amount: 145.67,
        gstAmount: 13.24,
        category: ExpenseCategory.fuel,
        date: DateTime.utc(2026, 8, 20, 14, 10, 0),
        receiptPath: '/data/user/0/com.kilotax/receipts/fuel_999.jpg',
        businessPercentage: 100.0,
        notes: 'BP Ultimate Diesel for Job #88',
        linkedTripId: 't_audit_001',
        receiptAudit: ReceiptAuditTrail(
          capturedAt: DateTime.utc(2026, 8, 20, 14, 10, 0),
          imageSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ocrMerchant: 'BP Australia',
          ocrAmount: 145.67,
          ocrGstAmount: 13.24,
          ocrConfidence: 0.98,
          reviewStatus: ReceiptReviewStatus.verified,
        ),
      );

      final saved = await storage.saveExpenses([originalExpense]);
      expect(saved, isTrue);

      final loadedExpenses = storage.loadExpenses();
      expect(loadedExpenses.length, 1);

      final loaded = loadedExpenses.first;
      expect(loaded.id, originalExpense.id);
      expect(loaded.amount, 145.67);
      expect(loaded.gstAmount, 13.24);
      expect(loaded.category, ExpenseCategory.fuel);
      expect(loaded.receiptPath, originalExpense.receiptPath);
      expect(loaded.linkedTripId, 't_audit_001');
      expect(loaded.receiptAudit?.imageSha256, originalExpense.receiptAudit?.imageSha256);
      expect(loaded.receiptAudit?.ocrMerchant, 'BP Australia');
      expect(loaded.receiptAudit?.reviewStatus, ReceiptReviewStatus.verified);
    });

    test('Trip invariant clamps negative distance and rejects inverted odometer (Corruption Defense)', () {
      final trip = Trip(
        id: 't_corrupt_1',
        vehicleId: 'v1',
        distanceKm: -5.0,
        date: DateTime.now(),
        purpose: 'Bad Trip',
      );
      expect(trip.distanceKm, equals(0.0));

      expect(
        () => Trip(
          id: 't_corrupt_2',
          vehicleId: 'v1',
          distanceKm: 10.0,
          date: DateTime.now(),
          purpose: 'Inverted Odo',
          startOdometer: 10050.0,
          endOdometer: 10040.0, // Inverted!
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
