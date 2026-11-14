import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/trips/trip_detail_screen.dart';
import 'package:kilotax/ui/screens/trips/widgets/bulky_tools_toggle_chip.dart';

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState();
    appState.addVehicle(
      Vehicle(
        id: 'v1',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'TRD-999',
        initialOdometer: 15000.0,
        tradeToolsRegisteredAt: DateTime.now(),
      ),
    );
  });

  group('TripDetailScreen Smart Auto-Suggestion & Thumb Orbit', () {
    testWidgets(
        'displays deduction tip callout when stop involves trade supplier',
        (tester) async {
      final trip = Trip(
        id: 't_bunnings_detail',
        vehicleId: 'v1',
        date: DateTime.now(),
        distanceKm: 22.0,
        purpose: '?',
        originAddress: 'Home Workshop, Melbourne',
        destinationAddress: 'Bunnings Warehouse Notting Hill',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(
            trip: trip,
            appState: appState,
          ),
        ),
      );

      // Verify calm trade stop deduction subtext is visible for home-origin trip
      expect(
        find.textContaining(
            'Required by ATO (TR 2021/1) to claim trips to/from home'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Bulky Tools toggle activates Bulky Tools',
        (tester) async {
      final trip = Trip(
        id: 't_claim_banner',
        vehicleId: 'v1',
        date: DateTime.now(),
        distanceKm: 15.0,
        purpose: 'Supplies Run',
        originAddress: 'Home',
        destinationAddress: "Middy's Electrical Supplies",
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(
            trip: trip,
            appState: appState,
          ),
        ),
      );

      // Scroll to the evidence control before tapping on compact viewports.
      await tester.ensureVisible(find.byType(BulkyToolsToggleChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BulkyToolsToggleChip));
      await tester.pumpAndSettle();

      final updatedTrip = appState.trips.firstWhere((t) => t.id == trip.id);
      expect(updatedTrip.purpose, contains('Bulky Tools Carried'));
      expect(
          find.textContaining('Bulky Tools exemption claimed'), findsOneWidget);
    });

    testWidgets('positions Done action within natural bottom thumb orbit',
        (tester) async {
      final trip = Trip(
        id: 't_thumb_orbit',
        vehicleId: 'v1',
        date: DateTime.now(),
        distanceKm: 18.0,
        purpose: '?',
        originAddress: 'Home',
        destinationAddress: 'Commercial Site, Docklands',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(
            trip: trip,
            appState: appState,
          ),
        ),
      );

      // Bottom bar has Done button
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(BulkyToolsToggleChip), findsOneWidget);

      // Verify thumb-reach bottom bar tap target
      final doneButton = find.text('Done');
      final size = tester.getSize(doneButton);
      expect(size.height, greaterThanOrEqualTo(16.0));
    });

    testWidgets(
        '1-tap classification toggle switches between Business and Personal',
        (tester) async {
      final trip = Trip(
        id: 't_toggle_class',
        vehicleId: 'v1',
        date: DateTime.now(),
        distanceKm: 14.0,
        purpose: 'Site inspection',
        originAddress: 'Home',
        destinationAddress: 'Site B',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(
            trip: trip,
            appState: appState,
          ),
        ),
      );

      // Verify initial state shows Business and Personal buttons
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      // Tap Personal toggle
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      var updated = appState.trips.firstWhere((t) => t.id == trip.id);
      expect(updated.classification, equals(TripClassification.personal));

      // Purpose and Bulky Tools should be hidden for Personal trips
      expect(find.text('Purpose'), findsNothing);
      expect(find.text('Heavy Tools & Gear (>20kg)'), findsNothing);
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Notes / Job'), findsOneWidget);

      // Tap Business toggle
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();

      updated = appState.trips.firstWhere((t) => t.id == trip.id);
      expect(updated.classification, equals(TripClassification.business));

      // Purpose and Bulky Tools should be restored for Business trips
      expect(find.text('Purpose'), findsOneWidget);
      expect(find.text('Heavy Tools & Gear (>20kg)'), findsOneWidget);
    });

    testWidgets('tapping Done button dismisses the screen', (tester) async {
      final trip = Trip(
        id: 't_done_dismiss',
        vehicleId: 'v1',
        date: DateTime.now(),
        distanceKm: 10.0,
        purpose: 'Client visit',
        classification: TripClassification.business,
      );
      appState.recordTrip(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  TripDetailScreen.show(context,
                      trip: trip, appState: appState);
                },
                child: const Text('Open Detail'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Trip detail'), findsOneWidget);

      // Scroll to Done and tap
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Screen popped back
      expect(find.text('Trip detail'), findsNothing);
      expect(find.text('Open Detail'), findsOneWidget);
    });
  });
}
