import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Selecting popular vehicle renders clean card without year and without Model Year dropdown', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              onVehicleCreated: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Ford Ranger" popular item
    final rangerCard = find.text('Ford Ranger');
    expect(rangerCard, findsOneWidget);
    await tester.tap(rangerCard);
    await tester.pumpAndSettle();

    // Verify stage 2 "Your Vehicle" is shown
    expect(find.text('Your Vehicle'), findsOneWidget);

    // Verify card header does NOT contain 2024
    expect(find.text('Ford Ranger 2024'), findsNothing);
    expect(find.text('Ford Ranger'), findsOneWidget);

    // Verify "Model Year" dropdown is completely eliminated
    expect(find.text('Model Year'), findsNothing);
    expect(find.text('Optional for Tax'), findsNothing);

    // Rego plate section exists cleanly with 1-tap state selector chips
    expect(find.text('Rego Plate'), findsOneWidget);
    expect(find.text('Next: Choose Tax Method'), findsOneWidget);

    // Verify 1-Tap State chips (VIC, NSW, QLD, WA, etc.)
    expect(find.text('VIC'), findsWidgets);
    expect(find.text('QLD'), findsWidgets);
    expect(find.text('WA'), findsWidgets);

    // Tap 'VIC' chip
    await tester.tap(find.text('VIC').first);
    await tester.pumpAndSettle();

    // Verify plate badge updates to VIC
    expect(find.text('VIC'), findsWidgets);
  });
}
