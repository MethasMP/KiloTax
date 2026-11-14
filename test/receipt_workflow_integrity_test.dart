import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/receipts/receipt_workflow_policy.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const policy = ReceiptWorkflowPolicy();
  VehicleExpense expense(
          {String? currency = 'AUD', ReceiptAuditTrail? audit}) =>
      VehicleExpense(
          id: 'e',
          vehicleId: 'car',
          amount: 90,
          supplier: 'Ampol',
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 11, 1),
          currency: currency,
          receiptAudit: audit);

  test('mixed items remain blocked after ordinary editing until allocated', () {
    const raw =
        'AMPOL\n01/11/2026\nDIESEL 40L 80.00\nCHOCOLATE 10.00\nTOTAL AUD 90.00\nGST 8.18';
    expect(const ReceiptIntelligenceService().analyseText(raw).hasMixedItems,
        isTrue);
    final mixed = expense(
        audit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.needsReview,
            capturedAt: DateTime(2026, 11, 1),
            rawOcrText: raw));
    expect(policy.reviewIssues(mixed, extractionReviewed: true),
        contains('Split mixed vehicle and private items'));
    final allocated = mixed.copyWith(allocations: const [
      ReceiptAllocation(
          description: 'Fuel',
          amount: 80,
          purpose: AllocationPurpose.work,
          category: ExpenseCategory.fuel),
      ReceiptAllocation(
          description: 'Chocolate',
          amount: 10,
          purpose: AllocationPurpose.private),
    ]);
    expect(policy.reviewIssues(allocated, extractionReviewed: true), isEmpty);
  });
  test('unknown currency and foreign currency cannot become AUD silently', () {
    expect(policy.coreIssues(expense(currency: null)),
        contains('Confirm receipt currency'));
    expect(policy.coreIssues(expense(currency: 'USD')), isNotEmpty);
  });
  test(
      'confirmed value changes are rejected even when caller reuses audit revision',
      () async {
    final e = expense(
            audit: ReceiptAuditTrail(
                reviewStatus: ReceiptReviewStatus.confirmed,
                capturedAt: DateTime(2026, 11, 1),
                revision: 2,
                reviewedRevision: 2,
                currentFields: const {'amount': 90.0, 'currency': 'AUD'}))
        .copyWith(amount: 100);
    expect(policy.approvalIssues(e),
        contains('Review changed amount before saving'));
    final state = AppState();
    await expectLater(
        state.saveWorkflowReceipt(e), throwsA(isA<FormatException>()));
    expect(state.expenses, isEmpty);
  });
  test(
      'corrupt ledger cannot be overwritten and a validated restore recovers it',
      () async {
    SharedPreferences.setMockInitialValues(
        {'kilotax_expenses_v1': 'broken json'});
    final storage = await LocalStorageService.init();
    expect(storage.loadExpenses(), isEmpty);
    expect(storage.expenseRecoveryWarning, isNotNull);
    expect(await storage.saveExpenses([expense()]), isFalse);
    expect(storage.loadRawString('kilotax_expenses_v1'), 'broken json');
    await storage.restoreSnapshot({
      'vehicles': [],
      'trips': [],
      'expenses': [expense().toJson()],
      'evidence': []
    });
    expect(storage.loadExpenses().single.amount, 90);
    expect(storage.expenseRecoveryWarning, isNull);
    expect(
        storage.loadRawString('kilotax_expenses_recovery_v1'), 'broken json');
  });
  test('restart rolls forward an authorized interrupted restore intent',
      () async {
    SharedPreferences.setMockInitialValues({
      'kilotax_restore_intent_v2': jsonEncode({
        'kilotax_expenses_v1': jsonEncode([expense().toJson()]),
        'kilotax_primary_vehicle_id_v1': 'car',
      })
    });
    final storage = await LocalStorageService.init();
    await storage.recoverRestoreIntent();
    expect(storage.loadExpenses().single.id, 'e');
    expect(storage.loadPrimaryVehicleId(), 'car');
    expect(storage.loadRawString('kilotax_restore_intent_v2'), isNull);
  });
}
