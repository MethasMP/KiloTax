import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/evidence/evidence_review_screen.dart';
import 'package:kiloclaim/ui/screens/tax/tax_summary_screen.dart';
import 'package:kiloclaim/ui/screens/home/widgets/trips_ledger_tab.dart';

class _State extends AppState {
  @override
  void prewarmAuthConnection() {}
}

class _DelayedInspection extends EvidenceReviewService {
  final result = Completer<Map<String, ReceiptFileInspection>>();

  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
          List<VehicleExpense> expenses) =>
      result.future;
}

class _CountingInspection extends EvidenceReviewService {
  int calls = 0;

  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) async {
    calls++;
    return {};
  }
}

class _FailOnceInspection extends EvidenceReviewService {
  int calls = 0;

  @override
  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
      List<VehicleExpense> expenses) async {
    if (calls++ == 0) throw StateError('Inspection failed');
    return {};
  }
}

Future<AppState> _state({TaxMethod? method, bool trip = false}) async {
  final state = _State();
  if (method != null) {
    await state.addVehicle(Vehicle(
      id: 'tax-car',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'TAX',
      initialOdometer: 1000,
      taxMethod: method,
    ));
  }
  if (trip) {
    state.recordTrip(Trip(
      id: 'tax-trip',
      vehicleId: 'tax-car',
      date: DateTime.now(),
      distanceKm: 10,
      classification: TripClassification.business,
      purpose: 'Deliver materials to Jones building site',
      startOdometer: 1000,
      endOdometer: 1010,
    ));
  }
  return state;
}

Widget _wrap(AppState state,
    {EvidenceReviewService service = const EvidenceReviewService(),
    double scale = 1,
    Future<void> Function(BuildContext, AppState)? onSend}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: ThemeData(colorScheme: AppColor.scheme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: TaxSummaryScreen(
        evidenceService: service,
        onSend: onSend ?? (context, state) async {},
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Missing vehicle offers setup instead of a share action',
      (tester) async {
    final state = await _state();
    addTearDown(state.dispose);
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();
    expect(find.text('Estimated deduction'), findsNothing);
    expect(find.text('Set up vehicle'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('tax-primary-action')))
            .onPressed,
        isNull);
  });

  for (final method in TaxMethod.values) {
    testWidgets('Empty $method directs to the matching trip entry',
        (tester) async {
      final state = await _state(method: method);
      addTearDown(state.dispose);
      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();
      expect(find.text('Estimated deduction'), findsNothing);
      expect(find.text('Add your first trip'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('tax-primary-action')))
              .onPressed,
          isNull);
      await tester.ensureVisible(find.text('View records'));
      await tester.tap(find.text('View records'));
      await tester.pumpAndSettle();
      expect(find.byType(TripsLedgerTab), findsOneWidget);
    });
  }

  testWidgets(
      'Pending inspection stays visible and sharing uses accountant handoff',
      (tester) async {
    final state = await _state(method: TaxMethod.centsPerKm, trip: true);
    addTearDown(state.dispose);
    final service = _DelayedInspection();
    AppState? sentState;
    await tester
        .pumpWidget(_wrap(state, service: service, onSend: (_, state) async {
      sentState = state;
    }));
    expect(find.text('Checking receipt files…'), findsOneWidget);
    expect(find.text('No outstanding record checks'), findsNothing);
    expect(find.text('Prepare pack'), findsOneWidget);
    expect(find.text('Review records'), findsOneWidget);
    await tester.tap(find.text('Prepare pack'));
    await tester.pump();
    expect(sentState, same(state));
    service.result.complete({});
    await tester.pumpAndSettle();
    expect(find.text('No outstanding record checks'), findsOneWidget);
    await tester.tap(find.text('Prepare pack'));
    await tester.pumpAndSettle();
    expect(sentState, same(state));
    expect(find.byType(EvidenceReviewScreen), findsNothing);
  });

  testWidgets('Inspection failure offers retry without hiding records',
      (tester) async {
    final state = await _state(method: TaxMethod.centsPerKm, trip: true);
    addTearDown(state.dispose);
    final service = _FailOnceInspection();
    await tester.pumpWidget(_wrap(state, service: service));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('accountant-pack-overview')), findsOneWidget);
    expect(find.text('Prepare pack'), findsOneWidget);
    await Scrollable.ensureVisible(
        tester.element(find.text('Retry receipt check')),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry receipt check'));
    await tester.pumpAndSettle();
    expect(find.text('No outstanding record checks'), findsOneWidget);
    expect(service.calls, 2);
    await tester.scrollUntilVisible(find.text('Estimated deduction'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Estimated deduction'), findsOneWidget);
  });

  testWidgets(
      'Unclassified trips offer the canonical review queue at large text',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _state(method: TaxMethod.centsPerKm);
    addTearDown(state.dispose);
    state.recordTrip(Trip(
      id: 'pending',
      vehicleId: 'tax-car',
      date: DateTime.now(),
      distanceKm: 12,
      classification: TripClassification.unclassified,
      purpose: '',
    ));
    await tester.pumpWidget(_wrap(state, scale: 1.6));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review 1 item'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Review 1 item'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Review 1 item').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Review 1 item').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(EvidenceReviewScreen), findsOneWidget);
  });
  testWidgets(
      'Trip updates refresh readiness without rereading unchanged receipt files',
      (tester) async {
    final state = await _state(method: TaxMethod.centsPerKm, trip: true);
    addTearDown(state.dispose);
    final service = _CountingInspection();
    await tester.pumpWidget(_wrap(state, service: service));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    state.recordTrip(Trip(
        id: 'new-pending',
        vehicleId: 'tax-car',
        date: DateTime.now(),
        distanceKm: 5,
        classification: TripClassification.unclassified,
        purpose: ''));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    await tester.scrollUntilVisible(find.text('Review 1 item'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Review 1 item'), findsOneWidget);
    state.recordExpense(VehicleExpense(
        id: 'new-receipt',
        vehicleId: 'tax-car',
        date: DateTime.now(),
        amount: 10,
        category: ExpenseCategory.tollsParking));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    await tester.scrollUntilVisible(find.text('Review 2 items'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Review 2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
