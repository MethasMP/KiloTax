import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'VehicleSetupFlow transitions from taxMethod to bluetoothLink stage',
      (tester) async {
    Vehicle? createdVehicle;
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              initialStage: VehicleSetupStage.taxMethod,
              onVehicleCreated: (v) {
                createdVehicle = v;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify on Tax Method stage
    expect(find.text('How will you keep your records?'), findsOneWidget);
    expect(find.text('Continue to Auto-Track'), findsOneWidget);

    await tester.tap(find.text('Logbook Method'));
    await tester.pumpAndSettle();
    // Tap "Continue to Auto-Track"
    await tester.tap(find.text('Continue to Auto-Track'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify on Car Bluetooth stage
    expect(find.text('Car Bluetooth'), findsOneWidget);
    expect(
        find.textContaining(
            'Auto-detect work trips the moment you get in your car.'),
        findsOneWidget);
    expect(find.text('Save car connection'), findsOneWidget);
    expect(find.text("I'm not in my car right now (Skip)"), findsOneWidget);

    // Tap Skip button
    await tester.tap(find.text("I'm not in my car right now (Skip)"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify vehicle was created with null bluetooth device
    expect(createdVehicle, isNotNull);
    expect(createdVehicle!.bluetoothDeviceName, isNull);
  });

  testWidgets(
      'VehicleSetupFlow Car Bluetooth back button returns to taxMethod stage',
      (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              initialStage: VehicleSetupStage.bluetoothLink,
              onVehicleCreated: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Car Bluetooth'), findsOneWidget);

    // Tap Back button in AppBar
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    // Returns to Tax Method
    expect(find.text('How will you keep your records?'), findsOneWidget);
    expect(find.text('Continue to Auto-Track'), findsOneWidget);
  });
}
