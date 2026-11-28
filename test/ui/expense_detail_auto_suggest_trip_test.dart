import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/expenses/expense_detail_screen.dart';

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
        purpose: 'Materials Pickup',
        destinationAddress: 'Bunnings Warehouse Alexandria',
        classification: TripClassification.business,
      );
      appState.recordTrip(matchingTrip);

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailScreen(
            appState: appState,
            merchant: 'Bunnings Warehouse',
            amount: 88.50,
            categoryName: 'Tools & Job Materials (Bunnings)',
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
      expect(find.textContaining('Matched trade supply stop'), findsOneWidget);

      // Tap on the checkbox to accept the suggestion
      await Scrollable.ensureVisible(tester.element(suggestedCheckbox),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(suggestedCheckbox);
      await tester.pumpAndSettle();

      // Upon accepting, the suggestion checkbox disappears and the linked trip banner appears
      expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
      expect(find.text('Linked trip'), findsOneWidget);
      expect(find.textContaining('Matched trade supply stop'), findsOneWidget);
    });

    testWidgets(
        'Does not suggest individual trip for pooled fuel expense (ATO 2-Bucket Rule)',
        (tester) async {
      final appState = AppState();
      final vehicle = Vehicle(
        id: 'veh_test_fuel',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TEST-03',
        taxMethod: TaxMethod.logbook,
      );
      await appState.addVehicle(vehicle);

      appState.recordTrip(Trip(
        id: 'trip_work_fuel',
        vehicleId: 'veh_test_fuel',
        date: baseTime.subtract(const Duration(minutes: 20)),
        distanceKm: 12.0,
        purpose: 'Site Inspection',
        classification: TripClassification.business,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailScreen(
            appState: appState,
            merchant: 'BP Connect',
            amount: 88.50,
            categoryName: 'Fuel',
            receiptDate: baseTime,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('accept-suggested-trip')), findsNothing);
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
      // Incompatible historical links remain visible only as legacy context
      expect(find.text('Linked trip'), findsOneWidget);
      expect(find.text('Legacy link — unlink or review'), findsWidgets);
    });
  });
}
