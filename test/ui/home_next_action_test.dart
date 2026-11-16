import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';
import 'package:kilotax/ui/screens/dashboard/task_home_body.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import '../support/main_menu_fixtures.dart' show AuditState;

class _FailedUploadState extends AuditState {
  int uploads = 0;
  int restores = 0;

  @override
  SyncStatus get syncStatus => SyncStatus.error;

  @override
  Future<SyncResult> triggerSyncToCloud() async {
    uploads++;
    return SyncResult(
        success: true, syncedTrips: 0, syncedExpenses: 0, rejectedOrIgnored: 0);
  }

  @override
  Future<CloudRestoreResult> restoreFromCloud() async {
    restores++;
    throw StateError('Retry must preserve pending local edits');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> records({required bool pending}) async {
    final state = AuditState();
    await state.addVehicle(Vehicle(
      id: 'home-next',
      make: 'Toyota',
      model: 'Corolla',
      initialOdometer: 1000,
      taxMethod: TaxMethod.centsPerKm,
    ));
    state.recordTrip(Trip(
      id: 'trip-next',
      vehicleId: 'home-next',
      date: DateTime.now(),
      startOdometer: 1000,
      endOdometer: 1010,
      distanceKm: 10,
      purpose: pending ? '' : 'Visit client site',
      classification: pending
          ? TripClassification.unclassified
          : TripClassification.business,
    ));
    return state;
  }

  Future<void> pump(WidgetTester tester, AppState state,
      {VoidCallback? review, VoidCallback? tax}) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
          home: Scaffold(
              body: TaskHomeBody(
        appState: state,
        onReviewTrips: review,
        onViewTax: tax,
      ))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'sync retry uploads local records without restoring stale cloud data',
      (tester) async {
    final state = _FailedUploadState();
    addTearDown(state.dispose);
    await pump(tester, state);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(state.uploads, 1);
    expect(state.restores, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending trip is the first task and routes to review',
      (tester) async {
    final state = await records(pending: true);
    addTearDown(state.dispose);
    var reviewed = false;
    await pump(tester, state, review: () => reviewed = true);
    expect(find.text('Review 1 trip'), findsOneWidget);
    expect(find.text('Your records are up to date'), findsNothing);
    await tester.tap(find.text('Review trips'));
    expect(reviewed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reviewed records offer tax summary without claiming export readiness',
      (tester) async {
    final state = await records(pending: false);
    addTearDown(state.dispose);
    var openedTax = false;
    await pump(tester, state, tax: () => openedTax = true);
    expect(find.text('Your records are up to date'), findsOneWidget);
    expect(find.textContaining('Check your tax summary before exporting.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'View tax summary'));
    expect(openedTax, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home starts vehicle setup before offering trip capture',
      (tester) async {
    final state = AuditState();
    addTearDown(state.dispose);
    await pump(tester, state);
    expect(find.text('Add your first trip'), findsNothing);
    await tester.ensureVisible(find.text('Add your vehicle'));
    await tester.tap(find.text('Add your vehicle'));
    await tester.pumpAndSettle();
    expect(find.byType(VehicleSetupFlow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
