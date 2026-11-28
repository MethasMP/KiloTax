import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/accountant_handoff_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/tax/pre_flight_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pre_flight_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
      'PreFlightReviewScreen renders vehicle header, claim card and 2 deliverables for CPK',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final vehicle = Vehicle(
      id: 'v-cpk-test',
      make: 'Ford',
      model: 'Ranger',
      regoPlate: 'RANGER99',
      initialOdometer: 10000,
      taxMethod: TaxMethod.centsPerKm,
    );
    await state.addVehicle(vehicle);

    final trip = Trip(
      id: 't-1',
      vehicleId: 'v-cpk-test',
      date: DateTime.now(),
      distanceKm: 40.0,
      purpose: 'Site inspection',
      startOdometer: 10000,
      endOdometer: 10040,
      taxMethod: TaxMethod.centsPerKm,
    );
    state.recordTrip(trip);

    final pdfFile =
        File('${tempDir.path}/CPK_2026_Ford_RANGER99_Summary_Declaration.pdf')
          ..writeAsStringSync('pdf');
    final xlsxFile =
        File('${tempDir.path}/CPK_2026_Ford_RANGER99_Tax_Ledger.xlsx')
          ..writeAsStringSync('xlsx');

    final package = AccountantHandoffPackage(
      vehicle: vehicle,
      financialYear: '2026',
      taxMethod: TaxMethod.centsPerKm,
      pdfFile: pdfFile,
      dataFile: xlsxFile,
      claimAmount: 34.0,
      businessPercentage: 100.0,
      totalTrips: 1,
      totalExpenses: 0,
      verifiedReceiptsCount: 0,
      unverifiedReceiptsCount: 0,
      unspecifiedTripsCount: 0,
      reviewIssues: [],
    );

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

    expect(find.text('Pre-flight Tax Review'), findsOneWidget);
    expect(find.text('Ford Ranger'), findsOneWidget);
    expect(find.text('Cents/KM'), findsOneWidget);
    expect(find.text('ESTIMATED BOX D1 DEDUCTION'), findsOneWidget);
    expect(find.text('Pre-flight Health Checklist'), findsOneWidget);
    expect(
        find.text('Accountant Deliverables (Exact 2 Files)'), findsOneWidget);
    expect(
        find.text('2-Tab Workbook: Summary, Trip Ledger (XLSX)'), findsOneWidget);
    expect(find.text('Preview PDF'), findsOneWidget);
    expect(find.text('Share records'), findsOneWidget);
  });

  testWidgets(
      'PreFlightReviewScreen renders Logbook 3-tab workbook deliverable row',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    final vehicle = Vehicle(
      id: 'v-lb-test',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'HILUX01',
      initialOdometer: 50000,
      taxMethod: TaxMethod.logbook,
    );
    await state.addVehicle(vehicle);

    final trip = Trip(
      id: 't-1',
      vehicleId: 'v-lb-test',
      date: DateTime.now(),
      distanceKm: 50.0,
      purpose: 'Plumbing repair',
      startOdometer: 50000,
      endOdometer: 50050,
      taxMethod: TaxMethod.logbook,
    );
    state.recordTrip(trip);

    final expense = VehicleExpense(
      id: 'exp-1',
      vehicleId: 'v-lb-test',
      date: DateTime.now(),
      amount: 150.0,
      category: ExpenseCategory.fuel,
    );
    state.recordExpense(expense);

    final pdfFile = File(
        '${tempDir.path}/Logbook_2026_Toyota_HILUX01_Master_Tax_Report.pdf')
      ..writeAsStringSync('pdf');
    final xlsxFile =
        File('${tempDir.path}/Logbook_2026_Toyota_HILUX01_Tax_Ledger.xlsx')
          ..writeAsStringSync('xlsx');

    final package = AccountantHandoffPackage(
      vehicle: vehicle,
      financialYear: '2026',
      taxMethod: TaxMethod.logbook,
      pdfFile: pdfFile,
      dataFile: xlsxFile,
      claimAmount: 150.0,
      businessPercentage: 100.0,
      totalTrips: 1,
      totalExpenses: 1,
      verifiedReceiptsCount: 1,
      unverifiedReceiptsCount: 0,
      unspecifiedTripsCount: 0,
      reviewIssues: [],
    );

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

    expect(find.text('Logbook'), findsOneWidget);
    expect(find.textContaining('3-Tab Workbook'), findsOneWidget);
    expect(find.textContaining('Master Tax Report'), findsOneWidget);
  });
}
