import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/money_left_on_table_card.dart';
import 'package:kilotax/ui/screens/trips/widgets/tax_savings_ticker_dialog.dart';

void main() {
  group('KiloTax Strategic Differentiation & Moat Tests', () {
    testWidgets('TaxSavingsTickerDialog renders added claim dopamine payoff and s 8-1 reference',
        (WidgetTester tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_diff_1',
        make: 'Toyota',
        model: 'HiLux Rugged X',
        regoPlate: 'KILO-001',
        initialOdometer: 15000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  TaxSavingsTickerDialog.show(
                    context,
                    tripDistanceKm: 42.0,
                    appState: appState,
                    bulkyToolsCarried: true,
                  );
                },
                child: const Text('Open Ticker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Ticker'));
      await tester.pumpAndSettle();

      // Verify Ticker Dialog Contents
      expect(find.text('TRIP RECORDED'), findsOneWidget);
      expect(find.text('42.0 km Work Drive'), findsOneWidget);
      expect(find.text('Estimated Tax Deduction Added'), findsOneWidget);
      // 42 km * $0.91 = $38.22
      expect(find.text('+\$38.22'), findsOneWidget);
      // Verify statutory bulky tools reference
      expect(find.textContaining('ITAA 1997 s 8-1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('TRIP RECORDED'), findsNothing);
    });

    testWidgets('MoneyLeftOnTableCard detects unlogged trip gap and computes lost dollars',
        (WidgetTester tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_diff_2',
        make: 'Ford',
        model: 'Ranger Raptor',
        regoPlate: 'TRADIE-99',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);

      // Add 1 missing purpose trip (e.g. 50 km missing work reason -> 50 * 0.91 = $45.50)
      appState.recordTrip(
        Trip(
          id: 'unlogged_trip_1',
          vehicleId: vehicle.id,
          distanceKm: 50.0,
          date: DateTime.now(),
          purpose: '?',
          startOdometer: 10000.0,
          endOdometer: 10050.0,
          classification: TripClassification.unclassified,
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

      // Verify Money Left on the Table Card warns about lost claim
      expect(find.text('MONEY LEFT ON THE TABLE'), findsOneWidget);
      expect(find.text('-\$45.50 AT RISK'), findsOneWidget);
      expect(find.textContaining('TR 97/11'), findsOneWidget);
      expect(find.textContaining('Recover \$45.50 in 1 Tap'), findsOneWidget);
    });

    testWidgets('MoneyLeftOnTableCard shows method arbitrage opportunity and switches to Logbook',
        (WidgetTester tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'v_diff_3',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'UTE-777',
        initialOdometer: 30000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(vehicle);

      // Add trips with 100% business use (e.g. 3,000 km)
      appState.recordTrip(
        Trip(
          id: 'biz_trip_1',
          vehicleId: vehicle.id,
          distanceKm: 3000.0,
          date: DateTime.now(),
          purpose: 'Commercial worksites all month',
          startOdometer: 30000.0,
          endOdometer: 33000.0,
          classification: TripClassification.business,
        ),
      );

      // Add high running expenses ($8,000 in fuel, repairs, insurance)
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_1',
          vehicleId: vehicle.id,
          amount: 8000.0,
          category: ExpenseCategory.fuel,
          date: DateTime.now(),
        ),
      );

      // CPK claim = 3000 * 0.91 = $2,730
      // Logbook claim = 100% * $8,000 = $8,000
      // Diff = $5,270 in favor of Logbook!

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyLeftOnTableCard(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MONEY LEFT ON THE TABLE'), findsOneWidget);
      expect(find.textContaining('Switching to Logbook unlocks +\$5,270.00'), findsOneWidget);

      // Tap Switch -> Now properly routes to LogbookSetupScreen for user confirmation
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(find.text('Set Up Your Logbook'), findsOneWidget);
      expect(find.text('Start 12-Week Logbook'), findsOneWidget);

      // Scroll into view and confirm starting logbook
      await tester.ensureVisible(find.text('Start 12-Week Logbook'));
      await tester.tap(find.text('Start 12-Week Logbook'));
      await tester.pumpAndSettle();

      expect(appState.primaryVehicle?.taxMethod, equals(TaxMethod.logbook));
    });
  });
}
