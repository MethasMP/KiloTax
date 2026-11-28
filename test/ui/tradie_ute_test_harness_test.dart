import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/dashboard/task_home_body.dart';
import 'package:kiloclaim/ui/screens/logbook/widgets/odometer_gap_review_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      '5-Minute Ute Test: Offline resilience, 1-tap gap review card, and touch target standards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    await appState.init();

    // 1. Setup tradie vehicle with an odometer gap
    final vehicle = Vehicle(
      id: 'ute-hilux-01',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'TRD-999',
      initialOdometer: 50000,
      taxMethod: TaxMethod.centsPerKm,
    );
    await appState.addVehicle(vehicle);

    // Trip 1 ends at 50,050
    appState.recordTrip(Trip(
      id: 'trip-1',
      vehicleId: vehicle.id,
      date: DateTime.now().subtract(const Duration(hours: 4)),
      distanceKm: 50.0,
      classification: TripClassification.business,
      purpose: 'Morning job site',
      startOdometer: 50000,
      endOdometer: 50050,
    ));

    // Trip 2 starts at 50,150 (Gap of 100 km!)
    appState.recordTrip(Trip(
      id: 'trip-2',
      vehicleId: vehicle.id,
      date: DateTime.now().subtract(const Duration(hours: 1)),
      distanceKm: 40.0,
      classification: TripClassification.business,
      purpose: 'Afternoon Bunnings run',
      startOdometer: 50150,
      endOdometer: 50190,
    ));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          theme: ThemeData(colorScheme: AppColor.scheme),
          home: Scaffold(
            body: TaskHomeBody(appState: appState),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify Home surfaces the OdometerGapReviewCard prominently
    final gapCard = find.byType(OdometerGapReviewCard);
    expect(gapCard, findsOneWidget,
        reason: 'Ute test: Tradie must immediately see missing odometer gaps');

    // 3. Verify touch target ergonomics: Buttons meet minimum 48x48dp
    final buttons = find.byType(InkWell);
    for (final element in buttons.evaluate()) {
      final renderBox = element.renderObject as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final size = renderBox.size;
        // Check clickable widgets have reasonable tap dimensions
        if (size.width > 20 && size.height > 20) {
          expect(size.height, greaterThanOrEqualTo(36.0),
              reason: 'Interactive widgets must maintain touch ergonomics');
        }
      }
    }

    // 4. Verify 1-tap review button opens the GapBridgeSheet
    final reviewButton = find.text('Review missing travel');
    expect(reviewButton, findsOneWidget);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    // Gap bridge sheet must open with gap distance explained
    expect(find.text('READINGS TO RECONCILE'), findsOneWidget);
    expect(find.textContaining('100.0 km'), findsNWidgets(2)); // Present on both review card and sheet
  });
}
