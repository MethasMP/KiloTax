import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/home/main_scaffold_screen.dart';

void main() {
  group('Adaptive Navigation & Database Isolation Tests (CPK vs Logbook)', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    Widget createTestApp(AppState state) {
      return ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: MainScaffoldScreen(),
        ),
      );
    }

    testWidgets('CPK Mode: Renders 3-Tab Lean Navigation without Expenses/Receipts', (tester) async {
      // 1. Setup vehicle with Cents-per-km tax method
      final cpkVehicle = Vehicle(
        id: 'veh_cpk_1',
        make: 'Toyota',
        model: 'Hilux Workmate',
        regoPlate: 'VIC-CPK-01',
        initialOdometer: 45000.0,
        taxMethod: TaxMethod.centsPerKm,
        isPrimary: true,
      );

      appState.addVehicle(cpkVehicle);

      await tester.pumpWidget(createTestApp(appState));
      await tester.pumpAndSettle();

      // Verify exactly 3 Tabs: Dashboard, Trips, Tax
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);

      // Verify ZERO Expenses / Receipts tab (No fuel receipt confusion)
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('Receipts'), findsNothing);
    });

    testWidgets('Logbook Mode: Renders 4-Tab Navigation + Expenses Tab', (tester) async {
      // 1. Setup vehicle with Logbook tax method
      final logbookVehicle = Vehicle(
        id: 'veh_logbook_1',
        make: 'Ford',
        model: 'Ranger XLT',
        regoPlate: 'NSW-LOG-99',
        initialOdometer: 12000.0,
        taxMethod: TaxMethod.logbook,
        isPrimary: true,
      );

      appState.addVehicle(logbookVehicle);

      await tester.pumpWidget(createTestApp(appState));
      await tester.pumpAndSettle();

      // Verify 4 Tabs: Home, Trips, Expenses, Tax
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
    });

    test('Trip Database Schema Isolation: Correctly persists taxMethod and evidenceSource', () {
      final trip = Trip(
        id: 'trip_cpk_test',
        vehicleId: 'veh_cpk_1',
        distanceKm: 28.5,
        date: DateTime(2026, 9, 19, 8, 30),
        purpose: 'Client site visit to Richmond',
        taxMethod: TaxMethod.centsPerKm,
        evidenceSource: 'auto_telemetry',
      );

      final json = trip.toJson();
      expect(json['taxMethod'], 'centsPerKm');
      expect(json['evidenceSource'], 'auto_telemetry');

      // Test deserialization
      final restored = Trip.fromJson(json);
      expect(restored.taxMethod, TaxMethod.centsPerKm);
      expect(restored.evidenceSource, 'auto_telemetry');
      expect(restored.distanceKm, 28.5);
    });
  });
}
