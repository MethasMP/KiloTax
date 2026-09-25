import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/home_telemetry_capsule.dart';
import 'package:kilotax/ui/screens/trips/trip_live_tracking_screen.dart';

void main() {
  group('HomeTelemetryCapsule Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      appState.addVehicle(
        Vehicle(
          id: 'v_tesla',
          make: 'Tesla',
          model: 'Model Y Long Range',
          regoPlate: 'TESLA-1',
          initialOdometer: 1000.0,
          bluetoothDeviceName: 'Tesla Model Y BT',
        ),
      );
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: HomeTelemetryCapsule(appState: appState),
          ),
        ),
      );
    }

    testWidgets('Renders Armed state with Bluetooth device name and Start Drive button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Auto-Track Armed'), findsOneWidget);
      expect(find.text('Linked to Tesla Model Y BT'), findsOneWidget);
    });

    testWidgets('Renders Pair Bluetooth tactile button when no bluetooth device is paired', (tester) async {
      appState.updatePrimaryVehicleBluetoothDevice(null);
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Pair Vehicle Bluetooth'), findsOneWidget);
      expect(find.text('Pair Now'), findsOneWidget);
    });

    testWidgets('Transitions to Dynamic Island Driving state with live deduction counter', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger active drive
      appState.startLiveDrive();
      appState.updateLiveDriveDistance(5.0); // 5 km * 0.91 = $4.55
      await tester.pump();

      expect(find.text('Recording in background'), findsOneWidget);
      expect(find.text('5.0 km'), findsOneWidget);
      expect(find.text('+\$4.55'), findsOneWidget);
    });

    testWidgets('Tapping Start Drive navigates to TripLiveTrackingScreen', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger driving and tap capsule to navigate to HUD
      appState.startLiveDrive();
      await tester.pump();

      await tester.tap(find.text('Recording in background'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TripLiveTrackingScreen), findsOneWidget);
    });

    testWidgets('Tapping Pair Bluetooth opens Hardware Bluetooth modal sheet with scanner', (tester) async {
      appState.updatePrimaryVehicleBluetoothDevice(null);
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Pair Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Hardware Bluetooth Link'), findsOneWidget);
      expect(find.text('LINK BY BLUETOOTH NAME'), findsNothing);
    });
  });
}
