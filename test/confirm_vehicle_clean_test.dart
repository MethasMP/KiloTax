import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Selecting popular vehicle renders clean card without year and without Model Year dropdown',
      (tester) async {
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

    // Verify stage 2 "Confirm Details" is shown
    expect(find.text('Confirm Details'), findsOneWidget);

    // Verify card header does NOT contain 2024
    expect(find.text('Ford Ranger 2024'), findsNothing);
    expect(find.text('Ford Ranger'), findsOneWidget);

    // Verify "Model Year" dropdown is completely eliminated
    expect(find.text('Model Year'), findsNothing);
    expect(find.text('Optional for Tax'), findsNothing);

    // Evidence fields are directly available, with an integrated state selector.
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Number plate'), findsOneWidget);
    expect(find.text('Opening odometer'), findsOneWidget);
    expect(find.text('NSW'), findsWidgets);

    // Vehicle details remain optional and the user can reach method selection.
    await tester.ensureVisible(find.text('Save & Continue'));
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tax Method'), findsOneWidget);
  });
}
