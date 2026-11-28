import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/engine/accountant_handoff_service.dart';
import 'package:kiloclaim/services/engine/accounting_export_validator.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/tax/pre_flight_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pre_flight_c2_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  AccountantHandoffPackage createDummyPackage(Vehicle vehicle) {
    final pdfFile = File('${tempDir.path}/test_report.pdf')..writeAsStringSync('dummy pdf');
    final dataFile = File('${tempDir.path}/test_data.xlsx')..writeAsStringSync('dummy xlsx');
    return AccountantHandoffPackage(
      vehicle: vehicle,
      financialYear: '2026',
      taxMethod: vehicle.taxMethod,
      pdfFile: pdfFile,
      dataFile: dataFile,
      claimAmount: 1200.0,
      businessPercentage: 80.0,
      totalTrips: 5,
      totalExpenses: 2,
      verifiedReceiptsCount: 2,
      unverifiedReceiptsCount: 0,
      unspecifiedTripsCount: 0,
      reviewIssues: const [],
    );
  }

  testWidgets('Export button is disabled when ValidationResult has errors', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final vehicle = Vehicle(
      id: 'v-c2-1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'HILUX01',
      initialOdometer: 50000,
      taxMethod: TaxMethod.logbook,
    );
    await state.addVehicle(vehicle);

    final package = createDummyPackage(vehicle);
    final errorResult = ValidationResult(
      errors: [
        const ValidationError(code: 'NO_TRIPS', message: 'No trips in selected period.'),
      ],
      warnings: [],
      canExport: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PreFlightReviewScreen(
          appState: state,
          initialPackage: package,
          validationResult: errorResult,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify error card is visible
    expect(find.text('No trips in selected period.'), findsOneWidget);

    // Verify Export button is disabled
    final exportButtonFinder = find.byKey(const Key('export_button'));
    expect(exportButtonFinder, findsOneWidget);
    final button = tester.widget<ElevatedButton>(exportButtonFinder);
    expect(button.onPressed, isNull);
  });

  testWidgets('Warning card requires "I understand" acknowledgement before export button is enabled',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final vehicle = Vehicle(
      id: 'v-c2-2',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'RANGER02',
      initialOdometer: 30000,
      taxMethod: TaxMethod.logbook,
    );
    await state.addVehicle(vehicle);

    final package = createDummyPackage(vehicle);
    final warningResult = ValidationResult(
      errors: [],
      warnings: [
        const ValidationWarning(
          code: 'SHORT_LOGBOOK',
          message: 'Logbook period is under 12 weeks. ATO requires 12 continuous representative weeks.',
        ),
      ],
      canExport: true,
    );

    bool exportInvoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PreFlightReviewScreen(
          appState: state,
          initialPackage: package,
          validationResult: warningResult,
          onExport: () async {
            exportInvoked = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Warning card is visible
    expect(
      find.text('Logbook period is under 12 weeks. ATO requires 12 continuous representative weeks.'),
      findsOneWidget,
    );
    expect(find.text('I understand'), findsOneWidget);

    // Export button is disabled before acknowledgement
    final exportButtonFinder = find.byKey(const Key('export_button'));
    expect(exportButtonFinder, findsOneWidget);
    ElevatedButton button = tester.widget<ElevatedButton>(exportButtonFinder);
    expect(button.onPressed, isNull);

    // User taps "I understand"
    final checkboxFinder = find.byKey(const Key('warning_ack_SHORT_LOGBOOK'));
    expect(checkboxFinder, findsOneWidget);
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    // Export button is now enabled
    button = tester.widget<ElevatedButton>(exportButtonFinder);
    expect(button.onPressed, isNotNull);

    // User taps export and export proceeds
    await tester.ensureVisible(exportButtonFinder);
    await tester.tap(exportButtonFinder);
    await tester.pumpAndSettle();

    expect(exportInvoked, isTrue);
  });

  testWidgets('1-tap Fix Now on NO_CLOSING_ODOMETER saves reading and unlocks export',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final vehicle = Vehicle(
      id: 'v-c2-fix',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'FIX001',
      initialOdometer: 50000,
      taxMethod: TaxMethod.centsPerKm,
    );
    await state.addVehicle(vehicle);
    state.recordTrip(
      Trip(
        id: 't-fix-1',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 10),
        distanceKm: 45.0,
        startOdometer: 50000,
        endOdometer: 50045,
        purpose: 'Site inspection',
        classification: TripClassification.business,
      ),
    );

    final package = createDummyPackage(vehicle);

    await tester.pumpWidget(
      MaterialApp(
        home: PreFlightReviewScreen(
          appState: state,
          outputDirectory: tempDir,
          initialPackage: package,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fixBtn = find.byKey(const Key('fix_error_NO_CLOSING_ODOMETER'));
    expect(fixBtn, findsOneWidget);

    ElevatedButton exportBtn =
        tester.widget<ElevatedButton>(find.byKey(const Key('export_button')));
    expect(exportBtn.onPressed, isNull);

    await tester.tap(fixBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('closing_odometer_input')), '50500');
    await tester.tap(find.byKey(const Key('closing_odometer_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fix_error_NO_CLOSING_ODOMETER')), findsNothing);
    expect(state.annualOdometers.any((a) => a.closingOdometer == 50500), isTrue);

    exportBtn =
        tester.widget<ElevatedButton>(find.byKey(const Key('export_button')));
    expect(exportBtn.onPressed, isNotNull);
  });
}
