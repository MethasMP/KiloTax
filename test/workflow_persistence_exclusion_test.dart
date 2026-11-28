import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/storage/local_backup_service.dart';
import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'package:kiloclaim/state/app_state.dart';

class DelayedExpenseStorage extends LocalStorageService {
  DelayedExpenseStorage(super.preferences);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> saveExpenses(List<VehicleExpense> expenses) async {
    started.complete();
    await release.future;
    return super.saveExpenses(expenses);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('backup cannot snapshot a pending receipt write', () async {
    SharedPreferences.setMockInitialValues({});
    final storage =
        DelayedExpenseStorage(await SharedPreferences.getInstance());
    final state = AppState(storageService: storage);
    await state.restoreLocalBackup({
      'vehicles': [
        Vehicle(
                id: 'car',
                make: 'Toyota',
                model: 'Hilux',
                regoPlate: 'TEST',
                initialOdometer: 0)
            .toJson()
      ],
      'trips': [],
      'expenses': [],
      'evidence': [],
    });
    final backup = LocalBackupService.createBackupPayload(state);
    final expense = VehicleExpense(
        id: 'e',
        vehicleId: 'car',
        amount: 10,
        currency: 'AUD',
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 1));
    final saving = state.saveWorkflowReceipt(expense);
    await storage.started.future;
    await expectLater(
        state.restoreLocalBackup(backup),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('A record is being saved'))));
    storage.release.complete();
    await saving;
    expect(state.expenses.single.id, 'e');
    expect(storage.loadExpenses().single.id, 'e');
    await state.restoreLocalBackup(backup);
    expect(state.expenses.single.id, 'e');
    expect(storage.loadExpenses().single.id, 'e');
    state.dispose();
  });

  test('sign out waits for pending receipt before clearing session data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage =
        DelayedExpenseStorage(await SharedPreferences.getInstance());
    final state = AppState(storageService: storage);
    final saving = state.saveWorkflowReceipt(VehicleExpense(
        id: 'e',
        vehicleId: 'car',
        amount: 10,
        currency: 'AUD',
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 1)));
    await storage.started.future;
    final signingOut = state.signOut();
    await Future<void>.delayed(Duration.zero);
    await expectLater(
        state.saveWorkflowReceipt(VehicleExpense(
            id: 'other',
            vehicleId: 'car',
            amount: 10,
            currency: 'AUD',
            category: ExpenseCategory.fuel,
            date: DateTime(2026, 1))),
        throwsStateError);
    storage.release.complete();
    await saving;
    await signingOut;
    expect(state.expenses, isEmpty);
    state.dispose();
  });
}
