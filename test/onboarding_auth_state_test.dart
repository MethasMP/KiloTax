import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/auth/sign_in_screen.dart';
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

    testWidgets('1. Fresh FTUE launch routes to OnboardingSlidesScreen', (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 0)));
      expect(find.byType(OnboardingSlidesScreen), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('2. Completing or skipping slides transitions to canonical SignInScreen without duplicate UI', (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 0)));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Should now show canonical SignInScreen
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.textContaining('Continue with Apple'), findsOneWidget);
      expect(find.textContaining('Continue with Google'), findsOneWidget);
    });

    testWidgets('3. Step 2 in OnboardingFlowScreen directly renders VehicleSetupFlow', (tester) async {
      await tester.pumpWidget(wrap(const OnboardingFlowScreen(initialStep: 2)));
      expect(find.byType(VehicleSetupFlow), findsOneWidget);
      expect(find.text('Add your vehicle'), findsOneWidget);
      expect(find.text('What do you drive?'), findsOneWidget);
    });

    testWidgets('4. Step 3 renders GPS Tracking explanation & enable button', (tester) async {
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
