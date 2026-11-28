import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/bulky_tools_suggestion_engine.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/trips/trip_quick_resolve_sheet.dart';
import 'package:kiloclaim/ui/screens/trips/widgets/bulky_tools_toggle_chip.dart';

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

  group('BulkyToolsSuggestionEngine Heuristics', () {
    test('detects Bunnings hardware supplier stop', () {
      final trip = Trip(
        id: 't1',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        destinationAddress: 'Bunnings Warehouse Alexandria, NSW',
      );

      final suggestion = BulkyToolsSuggestionEngine.evaluate(trip);
      expect(suggestion.isSuggested, isTrue);
      expect(suggestion.isSupplierStop, isTrue);
      expect(suggestion.badgeText, equals('Stopped at trade supplier'));
    });

    test('detects Middy electrical trade wholesaler stop', () {
      final trip = Trip(
        id: 't2',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        originAddress: "Middy's Electrical Supplies Notting Hill",
      );

      final suggestion = BulkyToolsSuggestionEngine.evaluate(trip);
      expect(suggestion.isSuggested, isTrue);
      expect(suggestion.isSupplierStop, isTrue);
      expect(suggestion.badgeText, equals('Stopped at trade supplier'));
    });

    test('detects Rexel and Trade suppliers', () {
      final tripRexel = Trip(
        id: 't3',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        destinationAddress: 'Rexel Electrical Supplies',
      );
      expect(BulkyToolsSuggestionEngine.isSuggested(tripRexel), isTrue);

      final tripTrade = Trip(
        id: 't4',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        destinationAddress: 'TradeTools Sunshine Coast Depot',
      );
      expect(BulkyToolsSuggestionEngine.isSuggested(tripTrade), isTrue);
    });

    test('detects Construction Site and Job locations', () {
      final tripSite = Trip(
        id: 't5',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        destinationAddress: 'Main Construction Site, 44 Spencer St',
      );
      final suggestion = BulkyToolsSuggestionEngine.evaluate(tripSite);
      expect(suggestion.isSuggested, isTrue);
      expect(suggestion.isSupplierStop, isFalse);

      final tripJob = Trip(
        id: 't6',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        destinationAddress: 'Commercial Client Job 12B',
      );
      expect(BulkyToolsSuggestionEngine.isSuggested(tripJob), isTrue);
    });

    test('does not suggest bulky tools for general office or standard street',
        () {
      final generalTrip = Trip(
        id: 't7',
        vehicleId: 'v_test',
        date: DateTime.now(),
        purpose: '?',
        originAddress: '100 Collins St, Melbourne',
        destinationAddress: '500 Bourke St, Melbourne',
      );

      final suggestion = BulkyToolsSuggestionEngine.evaluate(generalTrip);
      expect(suggestion.isSuggested, isFalse);
    });
  });

  group('TripQuickResolveSheet Smart Auto-Suggestion', () {
    testWidgets(
        'supplier-only route does not request a home-commute tools confirmation',
        (tester) async {
      final bunningsTrip = Trip(
        id: 't_bunnings',
        vehicleId: 'v_test',
        date: DateTime.now(),
        distanceKm: 14.5,
        purpose: '?',
        destinationAddress: 'Bunnings Warehouse Alexandria',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TripQuickResolveSheet.show(
                      ctx,
                      trip: bunningsTrip,
                      appState: appState,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify the sheet opened
      expect(find.byType(TripQuickResolveSheet), findsOneWidget);

      expect(find.byType(BulkyToolsToggleChip), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Supplier / Bunnings'), findsOneWidget);
    });

    testWidgets(
        'supplier preset records purpose without inventing tools evidence',
        (tester) async {
      final bunningsTrip = Trip(
        id: 't_bunnings_resolve',
        vehicleId: 'v_test',
        date: DateTime.now(),
        distanceKm: 12.0,
        purpose: '?',
        destinationAddress: 'Bunnings Warehouse Hawthorn',
      );
      appState.recordTrip(bunningsTrip);

      Trip? resolvedTrip;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TripQuickResolveSheet.show(
                      ctx,
                      trip: bunningsTrip,
                      appState: appState,
                      onTripResolved: (res) {
                        resolvedTrip = res;
                      },
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap Supplier / Bunnings purpose button (1 tap verification!)
      await tester.tap(find.text('Supplier / Bunnings'));
      await tester.pumpAndSettle();

      expect(resolvedTrip, isNotNull);
      expect(resolvedTrip!.classification, equals(TripClassification.business));
      expect(resolvedTrip!.purpose, 'Supplier / Materials');
      expect(appState.trips.single.purpose, 'Supplier / Materials');
    });

    testWidgets('supplier origin alone does not add tools evidence',
        (tester) async {
      final supplierTrip = Trip(
        id: 't_middy',
        vehicleId: 'v_test',
        date: DateTime.now(),
        distanceKm: 8.0,
        purpose: '?',
        originAddress: "Middy's Electrical Wholesaler",
      );
      appState.recordTrip(supplierTrip);

      Trip? resolvedTrip;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TripQuickResolveSheet.show(
                      ctx,
                      trip: supplierTrip,
                      appState: appState,
                      onTripResolved: (res) => resolvedTrip = res,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      // Now tap purpose button
      await tester.tap(find.text('Supplier / Bunnings'));
      await tester.pumpAndSettle();

      expect(resolvedTrip, isNotNull);
      expect(resolvedTrip!.purpose, isNot(contains('Bulky Tools')));
    });

    testWidgets('meets thumb reach ergonomics with tap targets >= 48x48 pt',
        (tester) async {
      final testTrip = Trip(
        id: 't_reach',
        vehicleId: 'v_test',
        date: DateTime.now(),
        distanceKm: 10.0,
        purpose: '?',
        destinationAddress: 'Rexel Electrical Wholesaler',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TripQuickResolveSheet.show(
                      ctx,
                      trip: testTrip,
                      appState: appState,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final button = find
          .ancestor(
              of: find.text('Supplier / Bunnings'),
              matching: find.byType(GestureDetector))
          .first;
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets(
        'pre-fills suggestedPurpose, shows evidence chip, and offers 1-tap confirm for receipt-backed trip',
        (tester) async {
      final receiptTrip = Trip(
        id: 't_receipt_backed',
        vehicleId: 'v_test',
        date: DateTime(2026, 10, 5, 11, 0),
        distanceKm: 18.5,
        purpose: '?',
        originAddress: '100 Collins St, Melbourne',
        destinationAddress: 'Bunnings Warehouse Alexandria',
        linkedExpenseIds: const ['exp_bunnings_1'],
      );
      appState.recordExpense(
        VehicleExpense(
          id: 'exp_bunnings_1',
          vehicleId: 'v_test',
          date: DateTime(2026, 10, 5, 11, 10),
          amount: 145.0,
          category: ExpenseCategory.toolsMaterials,
          supplier: 'Bunnings',
        ),
      );

      Trip? resolvedTrip;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TripQuickResolveSheet.show(
                      ctx,
                      trip: receiptTrip,
                      appState: appState,
                      onTripResolved: (t) => resolvedTrip = t,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt Backed'), findsOneWidget);
      final confirmBtn =
          find.byKey(const ValueKey('btn-quick-resolve-1tap-confirm'));
      expect(confirmBtn, findsOneWidget);
      expect(find.textContaining('Supplies Run (Bunnings)'), findsWidgets);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(resolvedTrip, isNotNull);
      expect(resolvedTrip!.classification, TripClassification.business);
      expect(resolvedTrip!.purpose, 'Supplies Run (Bunnings)');
    });
  });
}
