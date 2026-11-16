import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kilotax/ui/screens/onboarding/widgets/permission_preprompt_screen.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/first_trip_card.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/home_telemetry_capsule.dart';
import 'package:kilotax/ui/screens/tracking/tracking_setup_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late AppState state;
  setUp(() => state = AppState());
  Widget wrap(Widget child) => ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('Welcome exposes returning sign-in and one direct start action',
      (tester) async {
    await tester.pumpWidget(wrap(const OnboardingFlowScreen()));
    expect(find.byType(OnboardingSlidesScreen), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('No account needed to get started.'), findsNothing);
    expect(find.textContaining('Step 1 of'), findsNothing);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Continue without an account'), findsOneWidget);
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrepromptScreen), findsOneWidget);
    await tester.tap(find.text('I’ll log trips manually instead'));
    await tester.pumpAndSettle();
    expect(find.byType(VehicleSetupFlow), findsOneWidget);
    expect(
        tester
            .widget<VehicleSetupFlow>(find.byType(VehicleSetupFlow))
            .includeBluetoothSetup,
        isFalse);
  });

  testWidgets(
      'Initial vehicle setup finishes without Bluetooth or account gate',
      (tester) async {
    Vehicle? result;
    await tester.pumpWidget(wrap(VehicleSetupFlow(
      initialStage: VehicleSetupStage.taxMethod,
      includeBluetoothSetup: false,
      onVehicleCreated: (vehicle) => result = vehicle,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.tap(find.text('Save vehicle'));
    await tester.pump();
    expect(result, isNotNull);
    expect(result!.bluetoothDeviceName, isNull);
    expect(find.text('Car Bluetooth'), findsNothing);
  });

  testWidgets('Guest chooses manual tracking before saving the first vehicle',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
          home: Consumer<AppState>(
        builder: (_, appState, __) => appState.hasVehicle
            ? const Scaffold(body: Text('Home destination'))
            : const OnboardingFlowScreen(initialStep: 1),
      )),
    ));
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();
    expect(state.isGuestMode, isTrue);
    expect(find.byType(PermissionPrepromptScreen), findsOneWidget);
    await tester.tap(find.text('I’ll log trips manually instead'));
    await tester.pumpAndSettle();
    final setup =
        tester.widget<VehicleSetupFlow>(find.byType(VehicleSetupFlow));
    await setup
        .onVehicleCreated(Vehicle(id: 'first', make: 'Toyota', model: 'Yaris'));
    await tester.pumpAndSettle();
    expect(state.hasVehicle, isTrue);
    expect(state.isGuestMode, isTrue);
    expect(state.isAuthenticated, isFalse);
    expect(find.text('Home destination'), findsOneWidget);
    expect(find.byType(PermissionPrepromptScreen), findsNothing);
  });

  testWidgets('Denied foreground access proceeds without a background request',
      (tester) async {
    const location = MethodChannel('flutter.baseflow.com/geolocator');
    var requests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(location, (call) async {
      if (call.method == 'isLocationServiceEnabled') return true;
      if (call.method == 'checkPermission') return 0;
      if (call.method == 'requestPermission') {
        requests++;
        return 0;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(location, null));
    await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 2)));
    await tester.tap(find.text('Enable automatic tracking'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(VehicleSetupFlow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'First trip entry exposes GPS and manual paths before requesting access',
      (tester) async {
    await tester.pumpWidget(wrap(FirstTripCard(appState: state)));
    await tester.tap(find.text('Record your first trip'));
    await tester.pumpAndSettle();
    expect(find.text('Record with GPS'), findsOneWidget);
    expect(find.text('Add a past trip'), findsOneWidget);
  });

  testWidgets(
      'Paired Bluetooth alone never claims automatic recording is armed',
      (tester) async {
    await state.addVehicle(Vehicle(
        id: 'car',
        make: 'Toyota',
        model: 'HiLux',
        bluetoothDeviceName: 'Car audio'));
    await tester.pumpWidget(wrap(HomeTelemetryCapsule(appState: state)));
    expect(find.text('Location setup incomplete'), findsOneWidget);
    expect(find.text('Auto-Track Armed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Automatic setup keeps manual fallback and gates background access',
      (tester) async {
    await tester.pumpWidget(wrap(const TrackingSetupScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1. Location access'), findsOneWidget);
    final backgroundButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Open app settings'));
    expect(backgroundButton.onPressed, isNull);
    await tester.scrollUntilVisible(find.text('Back to Home'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('You can still add trips manually.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
