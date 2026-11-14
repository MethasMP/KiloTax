import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/home_telemetry_capsule.dart';
import 'package:kilotax/ui/screens/trips/trip_live_tracking_screen.dart';
import 'package:flutter/services.dart';
import 'package:kilotax/ui/screens/tracking/tracking_setup_screen.dart';

void main() {
  group('HomeTelemetryCapsule Tests', () {
    late AppState appState;

    TestWidgetsFlutterBinding.ensureInitialized();
    const location = MethodChannel('flutter.baseflow.com/geolocator');
    var permission = 2;
    setUp(() {
      permission = 2;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(location, (call) async {
        if (call.method == 'isLocationServiceEnabled') return true;
        if (call.method == 'checkPermission') return permission;
        return null;
      });
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

    tearDown(() {
      appState.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(location, null);
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

    testWidgets(
        'Paired car with foreground access still requires background setup',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Location setup incomplete'), findsOneWidget);
      expect(find.text('Background location access is needed'), findsOneWidget);
      expect(find.text('Auto-Track Armed'), findsNothing);
    });

    testWidgets('Unpaired car offers an actionable Bluetooth setup tile',
        (tester) async {
      appState.updatePrimaryVehicleBluetoothDevice(null);
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Automatic recording is off'), findsOneWidget);
      expect(find.text("Connect to your car's Bluetooth"), findsOneWidget);
      expect(tester.getSize(find.byType(ListTile)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets(
        'Active drive shows GPS distance and defers deduction until review',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Captured distance is provisional until the trip is reviewed.
      appState.startLiveDrive();
      appState.updateLiveDriveDistance(5.0);
      await tester.pump();

      expect(find.text('RECORDING YOUR DRIVE'), findsOneWidget);
      expect(find.text('5.0 km'), findsOneWidget);
      expect(find.text('+\$4.55'), findsNothing);
      expect(find.textContaining('Your deduction is calculated after review.'),
          findsOneWidget);
      expect(find.text('Finish & review'), findsOneWidget);
    });

    testWidgets(
        'Open tracking navigates from the active drive to TripLiveTrackingScreen',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger driving and tap capsule to navigate to HUD
      appState.startLiveDrive();
      await tester.pump();

      await tester.tap(find.text('Open tracking'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TripLiveTrackingScreen), findsOneWidget);
    });

    testWidgets(
        'Setup opens permission-aware tracking setup before car pairing',
        (tester) async {
      appState.updatePrimaryVehicleBluetoothDevice(null);
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Automatic recording is off'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TrackingSetupScreen), findsOneWidget);
      expect(find.text('1. Location access'), findsOneWidget);
      expect(find.text('LINK BY BLUETOOTH NAME'), findsNothing);
    });

    testWidgets('With background access an unlinked car shows waiting state',
        (tester) async {
      permission = 3;
      await appState.refreshLocationPermission();
      appState.toggleBluetoothLink(false);
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Waiting for car connection'), findsOneWidget);
      expect(find.text('Tesla Model Y BT not connected'), findsOneWidget);
    });
  });
}
