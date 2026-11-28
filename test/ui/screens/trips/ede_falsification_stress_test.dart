import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/trip_quick_resolve_sheet.dart';

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState();
    appState.addVehicle(
      Vehicle(
        id: 'v_test',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'TRD-123',
        initialOdometer: 10000.0,
      ),
    );
  });

  Future<void> openSheet(WidgetTester tester, Trip trip,
      {void Function(Trip)? onTripResolved}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TripQuickResolveSheet.show(
                context,
                trip: trip,
                appState: appState,
                onTripResolved: onTripResolved,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(TripQuickResolveSheet), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  }

  testWidgets('Home to Bunnings address alone does not confirm tools',
      (tester) async {
    final trip = Trip(
      id: 'ede_supplier_address_only',
      vehicleId: 'v_test',
      date: DateTime(2026, 11, 6, 9),
      distanceKm: 12,
      purpose: '?',
      originAddress: 'Home',
      destinationAddress: 'Bunnings Warehouse Alexandria',
    );

    await openSheet(tester, trip);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse,
        reason: 'A supplier destination supplies context, not evidence that '
            'heavy tools were on board.');
  });

  testWidgets('supplier preset cannot manufacture tools evidence',
      (tester) async {
    final trip = Trip(
      id: 'ede_supplier_preset',
      vehicleId: 'v_test',
      date: DateTime(2026, 11, 6, 9),
      distanceKm: 12,
      purpose: '?',
      originAddress: 'Home',
      destinationAddress: 'Bunnings Warehouse Alexandria',
    );
    appState.recordTrip(trip);
    Trip? resolved;
    await openSheet(tester, trip,
        onTripResolved: (updated) => resolved = updated);

    await tester.ensureVisible(find.text('Supplier / Bunnings'));
    await tester.tap(find.text('Supplier / Bunnings'));
    await tester.pumpAndSettle();

    expect(resolved, isNotNull);
    expect(resolved!.purpose, 'Supplier / Materials');
  });

  testWidgets('explicit existing tools evidence stays selected when editing',
      (tester) async {
    final trip = Trip(
      id: 'ede_explicit_tools',
      vehicleId: 'v_test',
      date: DateTime(2026, 11, 6, 9),
      distanceKm: 12,
      purpose: 'Client visit (Bulky Tools Carried)',
      originAddress: 'Home',
      destinationAddress: '44 Spencer Street',
    );
    appState.recordTrip(trip);
    Trip? resolved;
    await openSheet(tester, trip,
        onTripResolved: (updated) => resolved = updated);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(resolved, isNotNull);
    expect(resolved!.purpose, 'Client visit (Bulky Tools Carried)');
  });
}
