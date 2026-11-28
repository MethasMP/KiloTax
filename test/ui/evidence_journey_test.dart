import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';

class ControlledInspection extends EvidenceReviewService {
  final calls = <Completer<Map<String, ReceiptFileInspection>>>[];
  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) {
    final call = Completer<Map<String, ReceiptFileInspection>>();
    calls.add(call);
    return call.future;
  }
}

class CountingInspection extends EvidenceReviewService {
  int calls = 0;
  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) async {
    calls++;
    return {
      for (final expense in expenses)
        expense.id:
            const ReceiptFileInspection(status: ReceiptFileStatus.available)
    };
  }
}

void main() {
  testWidgets('trip-only notifications do not repeat receipt file inspection',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(
        Vehicle(id: 'v', make: 'Toyota', model: 'HiLux', initialOdometer: 100));
    final service = CountingInspection();
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [
      Expanded(child: TaskHomeBody(appState: state, evidenceService: service)),
      Expanded(
          child: EvidenceReviewScreen(
              appState: state,
              vehicleId: 'v',
              financialYear: state.activeTaxRule.financialYear,
              evidenceService: service)),
    ])));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    state.recordTrip(Trip(
        id: 't',
        vehicleId: 'v',
        date: DateTime.now(),
        purpose: 'Visit Smith renovation',
        distanceKm: 10));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    state.recordExpense(VehicleExpense(
        id: 'e',
        vehicleId: 'v',
        date: DateTime.now(),
        amount: 12,
        category: ExpenseCategory.tollsParking));
    await tester.pumpAndSettle();
    expect(service.calls, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy private trip links stay generic in scoped Review',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await state.addVehicle(
        Vehicle(id: 'v', make: 'Toyota', model: 'HiLux', initialOdometer: 100));
    state.recordTrip(Trip(
        id: 'private',
        vehicleId: 'v',
        date: DateTime.now(),
        purpose: 'PRIVATE SECRET',
        destinationAddress: 'PRIVATE LOCATION',
        classification: TripClassification.personal));
    state.recordExpense(VehicleExpense(
        id: 'e',
        vehicleId: 'v',
        date: DateTime.now(),
        amount: 12,
        category: ExpenseCategory.tollsParking,
        linkedTripId: 'private'));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: state,
            vehicleId: 'v',
            financialYear: state.activeTaxRule.financialYear)));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.textContaining('Existing link needs review'), findsOneWidget);
    expect(find.text('Related receipt'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'week filtering keeps older linked issue as context and conflicts do not duplicate receipts',
      (tester) async {
    final state = AppState();
    await state.addVehicle(
        Vehicle(id: 'v', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    final now = DateTime.now();
    state.recordTrip(Trip(
        id: 'old',
        vehicleId: 'v',
        date: now.subtract(const Duration(days: 14)),
        distanceKm: 10,
        purpose: 'Business',
        destinationAddress: 'Older site',
        linkedExpenseIds: ['e']));
    state.recordTrip(Trip(
        id: 'new',
        vehicleId: 'v',
        date: now,
        distanceKm: 10,
        purpose: 'Business',
        destinationAddress: 'New site',
        linkedExpenseIds: ['e']));
    state.recordExpense(VehicleExpense(
        id: 'e',
        vehicleId: 'v',
        amount: 12,
        category: ExpenseCategory.tollsParking,
        date: now,
        linkedTripId: 'old'));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: state,
            vehicleId: 'v',
            financialYear: state.activeTaxRule.financialYear)));
    await tester.pumpAndSettle();
    expect(find.text('Related receipt'), findsOneWidget);
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.text('Older site'), findsOneWidget);
    expect(find.text('Add a business purpose'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('View all pending'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View all pending'));
    await tester.pumpAndSettle();
    expect(find.text('View all pending'), findsOneWidget);
    await tester.tap(find.text('View all pending'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('3 items need attention'), findsOneWidget);
  });

  testWidgets(
      'Home checking and failure never claim complete and retry can finish',
      (tester) async {
    final state = AppState();
    await state.addVehicle(
        Vehicle(id: 'v', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    state.recordTrip(Trip(
        id: 't',
        vehicleId: 'v',
        date: DateTime.now(),
        purpose: 'Deliver timber to client',
        distanceKm: 10));
    final service = ControlledInspection();
    var reviewed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskHomeBody(
                appState: state,
                evidenceService: service,
                onReviewTrips: () => reviewed = true))));
    expect(find.text('Checking receipt files…'), findsOneWidget);
    expect(find.text('No outstanding record checks'), findsNothing);
    service.calls.single.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Receipt files could not be checked'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry receipt check'));
    await tester.tap(find.text('Retry receipt check'));
    service.calls.last.complete({});
    await tester.pumpAndSettle();
    expect(
        find.text('No outstanding app checks in this scope'), findsOneWidget);
    await tester.ensureVisible(find.text('Review records'));
    await tester.tap(find.text('Review records'));
    expect(reviewed, isTrue);
  });

  testWidgets('Review ignores old inspection result after scope changes',
      (tester) async {
    final state = AppState();
    await state.addVehicle(
        Vehicle(id: 'a', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    await state.addVehicle(
        Vehicle(id: 'b', make: 'Ford', model: 'Ranger', initialOdometer: 100));
    final year = state.activeTaxRule.financialYear;
    final service = ControlledInspection();
    Future<void> scope(String id) => tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: state,
            vehicleId: id,
            financialYear: year,
            evidenceService: service)));
    await scope('a');
    await scope('b');
    service.calls.first.completeError(StateError('old scope'));
    await tester.pump();
    expect(find.text('Checking receipt files…'), findsOneWidget);
    expect(find.text('Retry receipt check'), findsNothing);
    service.calls.last.complete({});
    await tester.pumpAndSettle();
    expect(find.text('Ford Ranger'), findsOneWidget);
  });

  testWidgets('all destinations persist and capture keeps selected destination',
      (tester) async {
    final state = AppState();
    await state.addVehicle(
        Vehicle(id: 'v', make: 'Toyota', model: 'Hilux', initialOdometer: 100));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state, child: const MaterialApp(home: MainScaffoldScreen())));
    await tester.pumpAndSettle();
    final nav = find.byType(ScaffoldBottomNavBar);
    for (final label in ['Review', 'Records', 'Pack', 'Home']) {
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pumpAndSettle();
      final before = tester.widget<ScaffoldBottomNavBar>(nav).currentIndex;
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Capture')));
      await tester.pumpAndSettle();
      expect(find.text('Capture a record'), findsOneWidget);
      expect(tester.widget<ScaffoldBottomNavBar>(nav).currentIndex, before);
      Navigator.of(tester.element(find.text('Capture a record'))).pop();
      await tester.pumpAndSettle();
    }
    expect(find.byType(TaxSummaryScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
      'linked receipt context appears once and editing preserves active vehicle',
      (tester) async {
    final state = AppState();
    state.addVehicle(Vehicle(
        id: 'a',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'A',
        initialOdometer: 100));
    state.addVehicle(Vehicle(
        id: 'b',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'B',
        initialOdometer: 100));
    state.selectVehicle('a');
    final year = state.activeTaxRule.financialYear;
    final date = DateTime(int.parse(year.substring(0, 4)), 8, 2);
    state.recordTrip(Trip(
        id: 't',
        vehicleId: 'b',
        date: date,
        distanceKm: 10,
        purpose: 'Business',
        destinationAddress: 'Smith Street',
        linkedExpenseIds: ['e']));
    state.recordExpense(VehicleExpense(
        id: 'e',
        vehicleId: 'b',
        amount: 12,
        category: ExpenseCategory.tollsParking,
        date: date,
        linkedTripId: 't'));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceReviewScreen(
            appState: state, vehicleId: 'b', financialYear: year)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Smith Street'), findsOneWidget);
    expect(find.text('Related receipt'), findsOneWidget);
    await tester.tap(find.text('Add a business purpose'));
    await tester.pumpAndSettle();
    expect(state.primaryVehicle?.id, 'a');
  });
}
