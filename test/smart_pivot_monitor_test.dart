import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/money_left_on_table_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Pivot Monitor (5,000 km Cap & Vault Realization)', () {
    testWidgets('Displays strategic pivot card when approaching 5,000 km cap with Vault evidence',
        (WidgetTester tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_pivot_1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TRADIE-99',
        initialOdometer: 40000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);

      // 1. Add 4,200 km business driving (approaching 5,000 km cap)
      appState.recordTrip(
        Trip(
          id: 't_pivot_1',
          vehicleId: vehicle.id,
          distanceKm: 4200.0,
          date: DateTime.now(),
          purpose: 'Commercial projects across Sydney',
          startOdometer: 40000.0,
          endOdometer: 44200.0,
          classification: TripClassification.business,
        ),
      );

      // 2. Add 2 fuel receipts stored in Vault under CPK mode
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_vault_1',
          vehicleId: vehicle.id,
          amount: 140.0,
          category: ExpenseCategory.fuel,
          date: DateTime.now(),
          isVaultOnly: true,
          vaultReason: 'cents_per_km_running_cost',
        ),
      );
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_vault_2',
          vehicleId: vehicle.id,
          amount: 160.0,
          category: ExpenseCategory.fuel,
          date: DateTime.now(),
          isVaultOnly: true,
          vaultReason: 'cents_per_km_running_cost',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyLeftOnTableCard(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Smart Pivot Card renders with humanized concise mobile copy (Chris Voss loss aversion + glovebox)
      expect(find.text('MONEY LEFT ON THE TABLE'), findsOneWidget);
      expect(find.textContaining('800 km until trips earn \$0'), findsOneWidget);
      expect(find.textContaining('fuel receipts in the glovebox'), findsOneWidget);
      expect(find.text('Claim My Fuel'), findsOneWidget);
    });

    test('Unvaults CPK fuel expenses when user switches to Logbook, but keeps prior-year receipts in vault', () async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_pivot_2',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'KILO-123',
        initialOdometer: 50000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);

      // Expense 1: CPK fuel expense (stored in vault to prevent double-dip)
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_cpk_fuel',
          vehicleId: vehicle.id,
          amount: 250.0,
          category: ExpenseCategory.fuel,
          date: DateTime.now(),
          isVaultOnly: true,
          vaultReason: 'cents_per_km_running_cost',
        ),
      );

      // Expense 2: Prior tax year receipt (stored in vault because of year mismatch)
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_prior_year',
          vehicleId: vehicle.id,
          amount: 500.0,
          category: ExpenseCategory.maintenanceTyres,
          date: DateTime(2021, 5, 1),
          isVaultOnly: true,
          vaultReason: 'prior_tax_year',
        ),
      );

      // Verify before switch: both are vault-only
      expect(appState.expenses.where((e) => e.isVaultOnly).length, equals(2));

      // Act: User switches to Logbook
      appState.startLogbookPeriod(
        startDate: DateTime.now(),
        startingOdometer: 50000.0,
      );

      // Verify after switch:
      // 1. CPK fuel expense is unvaulted and now 100% active in logbook claim!
      final cpkExp = appState.expenses.firstWhere((e) => e.id == 'exp_cpk_fuel');
      expect(cpkExp.isVaultOnly, isFalse);
      expect(cpkExp.vaultReason, isNull);

      // 2. Prior tax year receipt stays safely held in Vault for accountant
      final priorExp = appState.expenses.firstWhere((e) => e.id == 'exp_prior_year');
      expect(priorExp.isVaultOnly, isTrue);
      expect(priorExp.vaultReason, equals('prior_tax_year'));
    });
  });
}
