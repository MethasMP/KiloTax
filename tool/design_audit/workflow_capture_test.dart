import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/workflow/workflow_screen.dart';
import 'package:kiloclaim/ui/screens/workflow/workflow_trip_editor.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await inter.load();
    final bytes = await File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await icons.load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('workflow screens at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState();
      addTearDown(state.dispose);
      state.addVehicle(Vehicle(
          id: 'v',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'JOB123',
          initialOdometer: 100,
          taxMethod: TaxMethod.logbook));
      await state.addJobSite(JobSite(
          id: 'job',
          name: 'Smith renovation',
          clientName: 'Smith',
          latitude: 0,
          longitude: 0,
          trackingEnabled: false));
      state.recordTrip(Trip(
          id: 't',
          vehicleId: 'v',
          date: DateTime(2026, 8, 1, 10),
          distanceKm: 20,
          startOdometer: 100,
          endOdometer: 120,
          purpose: '?',
          classification: TripClassification.unclassified));
      state.recordExpense(VehicleExpense(
          id: 'e',
          vehicleId: 'v',
          amount: 85,
          supplier: 'Hardware supplies',
          category: ExpenseCategory.toolsMaterials,
          date: DateTime(2026, 8, 1)));
      Widget wrap(Widget child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: child);
      await tester.pumpWidget(wrap(WorkflowScreen(appState: state)));
      await tester.pumpAndSettle();
      for (final step in ['1. Trips', '2. Jobs', '3. Receipts', '4. Pack']) {
        await tester.tap(find.text(step));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: step);
        if (scale == 1) {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'workflow/${step.substring(3).toLowerCase()}.png'));
        }
      }
      await tester.pumpWidget(
          wrap(WorkflowTripEditor(appState: state, trip: state.trips.single)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mixed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('workflow/mixed-review.png'));
      }
    });
  }
}
