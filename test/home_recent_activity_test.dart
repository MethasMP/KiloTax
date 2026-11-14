import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/home_recent_activity.dart';
import 'package:provider/provider.dart';

void main() {
  group('HomeRecentActivity Empty State Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      appState.addVehicle(
        Vehicle(
          id: 'v_hilux',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'TRADIE-1',
          initialOdometer: 15000.0,
          taxMethod: TaxMethod.centsPerKm,
        ),
      );
    });

    Widget createTestWidget({
      VoidCallback? onViewAll,
      VoidCallback? onLogDrive,
    }) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: HomeRecentActivity(
              appState: appState,
              onViewAll: onViewAll,
              onLogDrive: onLogDrive,
            ),
          ),
        ),
      );
    }

    testWidgets('Renders ergonomic empty state when no trips exist',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No trips recorded yet.'), findsOneWidget);
      expect(find.text('Add a trip'), findsOneWidget);
      expect(find.text('Simulate a Test Drive'), findsNothing);
      expect(appState.trips, isEmpty);

      // Verify minimum touch target >= 44x44
      final logBtn =
          tester.getSize(find.widgetWithText(OutlinedButton, 'Add a trip'));
      expect(logBtn.height, greaterThanOrEqualTo(44.0));
      expect(logBtn.width, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Triggers onLogDrive callback when tapped', (tester) async {
      bool logged = false;
      await tester.pumpWidget(createTestWidget(
        onLogDrive: () {
          logged = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a trip'));
      await tester.pumpAndSettle();

      expect(logged, isTrue);
    });

    testWidgets(
        'Recorded trip updates recent activity without sample ledger entries',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<AppState>(
                builder: (context, state, _) =>
                    HomeRecentActivity(appState: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No trips recorded yet.'), findsOneWidget);

      expect(appState.trips, isEmpty);
      appState.recordTrip(Trip(
          id: 'real-trip',
          vehicleId: 'v_hilux',
          date: DateTime.now(),
          distanceKm: 10,
          purpose: 'Site visit',
          originAddress: 'Bunnings Warehouse',
          destinationAddress: 'Job Site'));
      await tester.pump();
      // Trips now populated, empty state replaced by latest trip hero card
      expect(appState.trips.isNotEmpty, isTrue);
      expect(find.text('No trips recorded yet.'), findsNothing);
      expect(find.text('Job Site'), findsOneWidget);
      expect(find.text('from Bunnings Warehouse'), findsOneWidget);
    });
  });
}
