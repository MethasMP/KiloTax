import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KiloTax Deterministic Entry State Machine Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    Widget wrap(Widget child) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('1. Fresh FTUE launch routes to OnboardingSlidesScreen',
        (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 0)));
      expect(find.byType(OnboardingSlidesScreen), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets(
        '2. Completing or skipping slides transitions to Value-First Vehicle Setup',
        (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 0)));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Should now show VehicleSetupFlow (Value-First: choose vehicle before sign-in)
      expect(find.byType(VehicleSetupFlow), findsOneWidget);
      expect(find.text('Add your vehicle'), findsOneWidget);
      expect(find.text('What do you drive?'), findsOneWidget);
    });

    testWidgets(
        '3. Step 2 in OnboardingFlowScreen renders ValueFirstGateScreen with tax value',
        (tester) async {
      final veh = Vehicle(
        id: 'test_veh',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'HILUX-01',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      );
      await appState.addVehicle(veh);

      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 2)));
      expect(find.text('Your Vehicle Is Tax-Ready'), findsOneWidget);
      expect(find.textContaining('Claim up to \$4550'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest (Device Only)'), findsOneWidget);
    });

    testWidgets('4. Step 3 renders GPS Tracking explanation & enable button',
        (tester) async {
      await appState.addVehicle(Vehicle(
        id: 'test_veh',
        make: 'Toyota',
        model: 'HiLux',
        regoPlate: 'HILUX-01',
        initialOdometer: 10000.0,
        taxMethod: TaxMethod.centsPerKm,
      ));

      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 3)));
      expect(find.textContaining('Automatically detect'), findsOneWidget);
      expect(find.text('Enable Automatic Tracking'), findsOneWidget);
    });
  });
}
