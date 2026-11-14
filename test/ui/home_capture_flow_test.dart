import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/driving_live_ticker.dart';
import 'package:kilotax/ui/screens/expenses/expense_detail_screen.dart';
import 'package:kilotax/ui/screens/expenses/scan_receipt_screen.dart';
import 'package:kilotax/ui/screens/home/widgets/quick_capture_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> state({TaxMethod method = TaxMethod.logbook}) async {
    final result = AppState();
    await result.addVehicle(Vehicle(
        id: 'car',
        make: 'Toyota',
        model: 'Corolla',
        taxMethod: method,
        initialOdometer: 42000,
        bluetoothDeviceName: 'Car audio'));
    addTearDown(result.dispose);
    return result;
  }

  test('a saved car connection does not claim verified hardware connectivity',
      () async {
    final app = await state();
    expect(app.isBluetoothLinked, isFalse);
    await app.checkRealBluetoothConnection();
    expect(app.isBluetoothLinked, isFalse);
  });

  test(
      'finished GPS drive remains unclassified for later review and cannot duplicate',
      () async {
    final app = await state();
    app.startLiveDrive();
    app.updateLiveDriveDistance(14.2);
    final trip = app.finishLiveDriveForReview();
    expect(trip, isNotNull);
    expect(app.trips.single.distanceKm, 14.2);
    expect(app.trips.single.classification, TripClassification.unclassified);
    expect(app.trips.single.purpose, isEmpty);
    expect(app.trips.single.evidenceSource, 'gps_recorded');
    expect(app.isDriving, isFalse);
    expect(app.finishLiveDriveForReview(), isNull);
    expect(app.trips, hasLength(1));
  });

  test('zero-distance finish preserves recording without inventing a trip',
      () async {
    final app = await state();
    app.startLiveDrive();
    expect(app.finishLiveDriveForReview(), isNull);
    expect(app.trips, isEmpty);
    expect(app.isDriving, isTrue);
    app.endLiveDrive();
  });

  for (final method in TaxMethod.values) {
    testWidgets('Capture routes receipt scanner only for $method', (t) async {
      final app = await state(method: method);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () =>
                          QuickCaptureBottomSheet.show(context, app),
                      child: const Text('Capture'))))));
      await t.tap(find.text('Capture'));
      await t.pumpAndSettle();
      expect(find.text('Record with GPS'), findsOneWidget);
      expect(find.text('Add a past trip'), findsOneWidget);
      if (method == TaxMethod.logbook) {
        await t.tap(find.text('Scan a receipt'));
        await t.pumpAndSettle();
        expect(find.byType(ScanReceiptScreen), findsOneWidget);
        expect(find.text('Open camera scanner'), findsOneWidget);
      } else {
        expect(find.text('Scan a receipt'), findsNothing);
        expect(find.text('Odometer'), findsNothing);
      }
    });
  }

  testWidgets(
      'active drive shows distance and review action without money ticker',
      (t) async {
    final app = await state();
    app.startLiveDrive();
    app.updateLiveDriveDistance(14.2);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: DrivingLiveTicker(appState: app))));
    await t.pump();
    expect(find.text('14.2 km'), findsOneWidget);
    expect(find.text('Finish & review'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    app.endLiveDrive();
  });

  for (final accept in [false, true]) {
    testWidgets('receipt trip suggestion requires explicit acceptance $accept',
        (t) async {
      final app = await state();
      app.recordTrip(Trip(
          id: 'suggested',
          vehicleId: 'car',
          date: DateTime.now(),
          distanceKm: 14.2,
          startOdometer: 42000,
          endOdometer: 42014.2,
          classification: TripClassification.business,
          purpose: 'Install client kitchen'));
      await t.pumpWidget(MaterialApp(
          home: ExpenseDetailScreen(
              appState: app,
              merchant: 'Ampol',
              amount: 82.4,
              categoryName: 'Fuel',
              receiptDate: DateTime.now(),
              initialLinkedTripId: 'suggested',
              autoMatchReason: 'Same day as your drive')));
      final suggestion = find.byKey(const ValueKey('accept-suggested-trip'));
      await t.ensureVisible(suggestion);
      expect(find.text('Linked trip'), findsNothing);
      if (accept) {
        await t.tap(suggestion);
        await t.pumpAndSettle();
        expect(find.text('Linked trip'), findsOneWidget);
      }
      final save = find.text('Save Expense to Vault');
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(app.expenses.single.linkedTripId, accept ? 'suggested' : isNull);
    });
  }
}
