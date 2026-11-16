import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/home/widgets/trips_ledger_tab.dart';
import 'package:provider/provider.dart';

void main() {
  group('TripsLedgerTab Surgical Refactor Verification', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      appState.addVehicle(
        Vehicle(
          id: 'v_hilux',
          make: 'Toyota',
          model: 'HiLux',
          regoPlate: 'TT222 (NSW)',
          initialOdometer: 15000.0,
          taxMethod: TaxMethod.centsPerKm,
        ),
      );
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: TripsLedgerTab(appState: appState),
        ),
      );
    }

    testWidgets(
        '1. AppBar displays clean activeVehicle.displayName without duplicate rego',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Vehicle display name is "Toyota HiLux (TT222 (NSW))"
      // Verify no duplicate like "Toyota HiLux (TT222 (NSW)) • TT222 (NSW)"
      expect(find.text('Toyota HiLux (TT222 (NSW))'), findsOneWidget);
      expect(find.textContaining('• TT222 (NSW)'), findsNothing);
    });

    testWidgets(
        '2. One toolbar add-trip action is available without a floating overlay',
        (tester) async {
      // Add a trip so that the screen is not in empty state
      appState.recordTrip(
        Trip(
          id: 'trip_1',
          vehicleId: 'v_hilux',
          distanceKm: 14.8,
          date: DateTime(2026, 10, 30),
          purpose: 'Client Site Inspection',
          startOdometer: 15000.0,
          endOdometer: 15014.8,
          classification: TripClassification.business,
          originAddress: 'Bunnings Port Melbourne',
          destinationAddress: 'Job Site, 42 Church St',
          taxMethod: TaxMethod.centsPerKm,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // No FloatingActionButton
      expect(find.byType(FloatingActionButton), findsNothing);

      // In AppBar actions, there should be no '+' icon button
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);
      expect(
        find.descendant(of: appBar, matching: find.byIcon(LucideIcons.plus)),
        findsOneWidget,
      );
    });

    testWidgets(
        '3. Trip cards show the destination, distance and a separate day heading',
        (tester) async {
      final tripCpk = Trip(
        id: 'trip_cpk',
        vehicleId: 'v_hilux',
        distanceKm: 14.8,
        date: DateTime(2026, 10, 30),
        purpose: 'Client Site Inspection & Materials Drop',
        startOdometer: 15000.0,
        endOdometer: 15014.8,
        classification: TripClassification.business,
        originAddress: 'Bunnings Port Melbourne',
        destinationAddress: 'Job Site Richmond',
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.recordTrip(tripCpk);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Row 1: Destination on left, distance & date on right
      expect(find.text('Job Site Richmond'), findsOneWidget);
      expect(find.textContaining('14.8 km ·'), findsOneWidget);
      expect(find.textContaining('October 30, 2026'), findsOneWidget);

      // Row 2: Origin on left, claim badge on right for CPK
      expect(find.text('from Bunnings Port Melbourne'), findsOneWidget);
      // 14.8 km * $0.91 = $13.47
      expect(find.text('+\$13.47'), findsOneWidget);
    });

    testWidgets('4. Logbook vehicle trips do not show arbitrary dollar amounts',
        (tester) async {
      final logbookVehicle = Vehicle(
        id: 'v_ranger',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'LOG-888',
        initialOdometer: 20000.0,
        taxMethod: TaxMethod.logbook,
      );
      appState.addVehicle(logbookVehicle);
      appState.selectVehicle(logbookVehicle.id);

      final tripLogbook = Trip(
        id: 'trip_logbook',
        vehicleId: 'v_ranger',
        distanceKm: 25.0,
        date: DateTime(2026, 10, 30),
        purpose: 'Site Delivery',
        startOdometer: 20000.0,
        endOdometer: 20025.0,
        classification: TripClassification.business,
        originAddress: 'Warehouse',
        destinationAddress: 'Site B',
        taxMethod: TaxMethod.logbook,
      );
      appState.recordTrip(tripLogbook);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show 'Work Drive' badge, not arbitrary cents-per-km dollar amount
      expect(find.text('Work Drive'), findsOneWidget);
      expect(find.text('+\$22.75'), findsNothing);
    });

    testWidgets('5. Trip needing review displays Review button',
        (tester) async {
      final unclassifiedTrip = Trip(
        id: 'trip_unclassified',
        vehicleId: 'v_hilux',
        distanceKm: 8.5,
        date: DateTime(2026, 10, 30),
        purpose: '',
        startOdometer: 15000.0,
        endOdometer: 15008.5,
        classification: TripClassification.unclassified,
        originAddress: 'Office',
        destinationAddress: 'Unknown Site',
        taxMethod: TaxMethod.centsPerKm,
      );
      appState.recordTrip(unclassifiedTrip);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
    });
  });
}
