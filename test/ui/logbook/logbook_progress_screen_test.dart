import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_progress_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders unaccounted gap weeks when gap exists in logbook period', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final startDate = DateTime(2026, 1, 1);
    final vehicle = Vehicle(
      id: 'v-gap-1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'GAP001',
      initialOdometer: 50000,
      taxMethod: TaxMethod.logbook,
      logbookStartDate: startDate,
    );
    await state.addVehicle(vehicle);

    state.startLogbookPeriod(
      startDate: startDate,
      startingOdometer: 50000,
    );

    // 10 weeks covered: trips on 70 distinct days (84 - 70 = 14 days = 2 weeks gap)
    for (int i = 0; i < 70; i++) {
      state.recordTrip(Trip(
        id: 'trip_$i',
        vehicleId: 'v-gap-1',
        date: startDate.add(Duration(days: i)),
        distanceKm: 20.0,
        purpose: 'Work commute',
        startOdometer: 50000.0 + (i * 20),
        endOdometer: 50000.0 + ((i + 1) * 20),
        taxMethod: TaxMethod.logbook,
      ));
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: LogbookProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 weeks unaccounted'), findsOneWidget);
  });

  testWidgets('does not show unaccounted gap text when logbook period has no gaps', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final startDate = DateTime(2026, 1, 1);
    final vehicle = Vehicle(
      id: 'v-nogap-1',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'NOGAP1',
      initialOdometer: 20000,
      taxMethod: TaxMethod.logbook,
      logbookStartDate: startDate,
    );
    await state.addVehicle(vehicle);

    state.startLogbookPeriod(
      startDate: startDate,
      startingOdometer: 20000,
    );

    // 12 weeks covered: all 84 days have trips
    for (int i = 0; i < 84; i++) {
      state.recordTrip(Trip(
        id: 'trip_full_$i',
        vehicleId: 'v-nogap-1',
        date: startDate.add(Duration(days: i)),
        distanceKm: 15.0,
        purpose: 'Job delivery',
        startOdometer: 20000.0 + (i * 15),
        endOdometer: 20000.0 + ((i + 1) * 15),
        taxMethod: TaxMethod.logbook,
      ));
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: LogbookProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('unaccounted'), findsNothing);
  });
}
