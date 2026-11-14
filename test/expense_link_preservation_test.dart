import 'dart:async';
import 'package:kilotax/services/ocr/receipt_audit_service.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

class PausedReceiptAudit extends ReceiptAuditService {
  final completer = Completer<ReceiptAuditTrail>();
  @override
  Future<ReceiptAuditTrail> create(
          {required String merchant,
          required double amount,
          required ExpenseCategory category,
          required String? imagePath,
          ReceiptOcrResult? ocrResult,
          ReceiptAuditTrail? existingAudit,
          bool confirmedByUser = false,
          bool detailsChanged = false,
          DateTime? date,
          String? currency,
          String? abn,
          String? invoiceNumber,
          double? gstAmount,
          String? engineId,
          String? engineVersion,
          List<Map<String, dynamic>> blocks = const [],
          String? reviewedBy,
          String? batchId,
          bool imageReplacementReviewed = false,
          Map<String, dynamic> fieldValues = const {},
          DateTime? capturedAt,
          DateTime? extractedAt}) =>
      completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mixed bill editor keeps private amounts out of saved work total',
      (tester) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
        id: 'mixed-car',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'TEST',
        initialOdometer: 100,
        taxMethod: TaxMethod.logbook));
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: state,
            merchant: 'Service station',
            amount: 110,
            categoryName: 'Fuel',
            receiptDate: DateTime.now())));
    final split = find.byKey(const ValueKey('split-receipt'));
    await tester.ensureVisible(split);
    await tester.tap(split);
    await tester.pumpAndSettle();
    expect(find.text('Not sure — excluded'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('allocation-amount-0-0')), '100');
    await tester.tap(find.byKey(const ValueKey('allocation-purpose-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicle / work').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('add-receipt-item')));
    await tester.tap(find.byKey(const ValueKey('add-receipt-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('allocation-description-1-0')),
        'Personal groceries');
    await tester.enterText(
        find.byKey(const ValueKey('allocation-amount-1-0')), '10');
    await tester.tap(find.byKey(const ValueKey('allocation-purpose-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal — excluded').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Expense to Vault'));
    await tester.tap(find.text('Save Expense to Vault'));
    await tester.pumpAndSettle();
    expect(state.expenses.single.amount, 110);
    expect(state.expenses.single.allocatedWorkAmount, 100);
    expect(state.expenses.single.supplier, 'Service station');
    expect(state.expenses.single.gstAmount, isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
      'adding direct work allocations releases only the CPK running-cost vault restriction',
      (tester) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
        id: 'car',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'TEST',
        taxMethod: TaxMethod.centsPerKm));
    final receipt = VehicleExpense(
        id: 'vaulted',
        vehicleId: 'car',
        amount: 120,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
        isVaultOnly: true,
        vaultReason: 'cents_per_km_running_cost',
        allocations: const [
          ReceiptAllocation(
              description: 'Fuel',
              amount: 100,
              purpose: AllocationPurpose.work,
              category: ExpenseCategory.fuel),
          ReceiptAllocation(
              description: 'Parking',
              amount: 20,
              purpose: AllocationPurpose.work,
              category: ExpenseCategory.tollsParking)
        ]);
    state.recordExpense(receipt);
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: state,
            merchant: 'Service station',
            amount: 120,
            receiptDate: receipt.date,
            existingExpense: receipt)));
    await tester.ensureVisible(find.text('Update Expense Record'));
    await tester.tap(find.text('Update Expense Record'));
    await tester.pumpAndSettle();
    expect(state.expenses.single.isVaultOnly, isFalse);
    expect(state.expenses.single.vaultReason, isNull);
    expect(
        state.expenses.single.claimComponents
            .where((e) => e.category == ExpenseCategory.tollsParking)
            .single
            .amount,
        20);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
      'split editor cannot change items while a save is hashing the receipt',
      (tester) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
        id: 'car',
        make: 'Toyota',
        model: 'Corolla',
        taxMethod: TaxMethod.logbook));
    final receipt = VehicleExpense(
        id: 'pending',
        vehicleId: 'car',
        amount: 100,
        date: DateTime.now(),
        category: ExpenseCategory.fuel,
        allocations: const [
          ReceiptAllocation(
              description: 'Fuel', amount: 100, purpose: AllocationPurpose.work)
        ]);
    state.recordExpense(receipt);
    final audit = PausedReceiptAudit();
    await tester.pumpWidget(MaterialApp(
        home: ExpenseDetailScreen(
            appState: state,
            merchant: 'Station',
            amount: 100,
            receiptDate: receipt.date,
            existingExpense: receipt,
            receiptAuditService: audit)));
    await tester.ensureVisible(find.text('Update Expense Record'));
    await tester.tap(find.text('Update Expense Record'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('add-receipt-item')));
    await tester.tap(find.byKey(const ValueKey('add-receipt-item')),
        warnIfMissed: false);
    await tester.pump();
    expect(
        find.byKey(const ValueKey('allocation-description-1-0')), findsNothing);
    audit.completer.complete(ReceiptAuditTrail(
        reviewStatus: ReceiptReviewStatus.manualReview,
        capturedAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(state.expenses.single.allocationError, isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  group('PR-02: Preserve trip tax method during expense linking', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('linkExpenseToTrip preserves TaxMethod.logbook on trip', () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'v_logbook_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'TRADIE-01',
        taxMethod: TaxMethod.logbook,
        initialOdometer: 10000.0,
      );
      await appState.addVehicle(vehicle);

      final logbookTrip = Trip(
        id: 'trip_lb_100',
        vehicleId: vehicle.id,
        distanceKm: 45.0,
        date: DateTime(2026, 8, 10, 9, 30),
        purpose: 'Site material delivery',
        startOdometer: 10000.0,
        endOdometer: 10045.0,
        classification: TripClassification.business,
        taxMethod: TaxMethod.logbook,
        originAddress: 'Warehouse',
        destinationAddress: 'Jobsite A',
      );
      appState.recordTrip(logbookTrip);

      final expense = VehicleExpense(
        id: 'exp_bunnings_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 10),
        category: ExpenseCategory.toolsMaterials,
        amount: 320.00,
        notes: 'Bunnings timber and fasteners',
      );
      appState.recordExpense(expense);

      // Verify initial taxMethod
      expect(appState.trips.firstWhere((t) => t.id == 'trip_lb_100').taxMethod,
          equals(TaxMethod.logbook));

      // Link expense to trip
      appState.linkExpenseToTrip(
        expenseId: 'exp_bunnings_1',
        tripId: 'trip_lb_100',
      );

      // Verify trip kept its logbook taxMethod
      final updatedTrip =
          appState.trips.firstWhere((t) => t.id == 'trip_lb_100');
      expect(updatedTrip.taxMethod, equals(TaxMethod.logbook));
      expect(updatedTrip.linkedExpenseIds, contains('exp_bunnings_1'));
      expect(updatedTrip.originAddress, equals('Warehouse'));
      expect(updatedTrip.destinationAddress, equals('Jobsite A'));
    });

    test('linkExpenseToTrip preserves TaxMethod.centsPerKm on CPK trip',
        () async {
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);
      await appState.init();

      final vehicle = Vehicle(
        id: 'v_cpk_1',
        make: 'Mazda',
        model: '3',
        regoPlate: 'CPK-99',
        taxMethod: TaxMethod.centsPerKm,
        initialOdometer: 50000.0,
      );
      await appState.addVehicle(vehicle);

      final cpkTrip = Trip(
        id: 'trip_cpk_200',
        vehicleId: vehicle.id,
        distanceKm: 20.0,
        date: DateTime(2026, 8, 12, 11, 0),
        purpose: 'Client consult',
        startOdometer: 50000.0,
        endOdometer: 50020.0,
        classification: TripClassification.business,
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.recordTrip(cpkTrip);

      final expense = VehicleExpense(
        id: 'exp_parking_1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 12),
        category: ExpenseCategory.tollsParking,
        amount: 25.00,
        notes: 'CBD Parking',
      );
      appState.recordExpense(expense);

      appState.linkExpenseToTrip(
        expenseId: 'exp_parking_1',
        tripId: 'trip_cpk_200',
      );

      final updatedTrip =
          appState.trips.firstWhere((t) => t.id == 'trip_cpk_200');
      expect(updatedTrip.taxMethod, equals(TaxMethod.centsPerKm));
      expect(updatedTrip.linkedExpenseIds, contains('exp_parking_1'));
    });
  });
}
