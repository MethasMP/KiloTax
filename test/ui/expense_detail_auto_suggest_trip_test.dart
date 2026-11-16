import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExpenseDetailScreen Auto Suggest Trip Tests', () {
    final baseTime = DateTime(2026, 10, 28, 14, 0);

    testWidgets(
        'Automatically suggests matching trip when receipt matches criteria and triggers checkbox card',
        (tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'veh_test_1',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TEST-01',
        taxMethod: TaxMethod.logbook,
      );
      await appState.addVehicle(vehicle);

      final matchingTrip = Trip(
        id: 'trip_work_target',
        vehicleId: 'veh_test_1',
        date: baseTime.subtract(const Duration(minutes: 20)), // 1:40 PM
        distanceKm: 12.0,
        purpose: 'Site Inspection',
        classification: TripClassification.business,
      );
      appState.recordTrip(matchingTrip);

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailScreen(
            appState: appState,
            merchant: 'BP Connect',
            amount: 88.50,
            categoryName: 'Fuel',
            receiptDate: baseTime, // 2:00 PM (20 mins after trip end)
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that the suggested trip card with key 'accept-suggested-trip' is displayed
      final suggestedCheckbox =
          find.byKey(const ValueKey('accept-suggested-trip'));
      expect(suggestedCheckbox, findsOneWidget);
      expect(find.text('Suggested trip link'), findsOneWidget);
      expect(find.textContaining('Matched work trip'), findsOneWidget);

      // Tap on the checkbox to accept the suggestion
      await Scrollable.ensureVisible(tester.element(suggestedCheckbox),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(suggestedCheckbox);
      await tester.pumpAndSettle();

      // Upon accepting, the suggestion checkbox disappears and the linked trip banner appears
      expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
      expect(find.text('Linked trip'), findsOneWidget);
      expect(find.textContaining('Matched work trip'), findsOneWidget);
    });

    testWidgets('Does not suggest trip if expense already has linkedTripId',
        (tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'veh_test_2',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TEST-02',
        taxMethod: TaxMethod.logbook,
      );
      await appState.addVehicle(vehicle);

      final matchingTrip = Trip(
        id: 'trip_work_2',
        vehicleId: 'veh_test_2',
        date: baseTime.subtract(const Duration(minutes: 15)),
        distanceKm: 8.0,
        purpose: 'Trade Supply Run',
        classification: TripClassification.business,
      );
      appState.recordTrip(matchingTrip);

      final existingLinkedExpense = VehicleExpense(
        id: 'exp_existing_1',
        vehicleId: 'veh_test_2',
        amount: 50.0,
        category: ExpenseCategory.fuel,
        date: baseTime,
        linkedTripId: 'trip_work_2',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailScreen(
            appState: appState,
            existingExpense: existingLinkedExpense,
            receiptDate: baseTime,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card for suggestion should NOT be present since it is already linked
      expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
      // But the linked trip banner should be present
      expect(find.text('Linked trip'), findsOneWidget);
    });
  });
}
