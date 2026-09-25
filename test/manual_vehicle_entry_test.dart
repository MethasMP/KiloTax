import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Manual vehicle entry dialog renders Make (Brand), Model, and full-width Body Type without Year', (tester) async {
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

    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Tap "Can't find your vehicle? Enter manually"
    final manualButton = find.text("Can't find your vehicle? Enter manually");
    await tester.ensureVisible(manualButton);
    await tester.tap(manualButton);
    await tester.pumpAndSettle();

    // Verify Make (Brand) and Model fields exist with clear helper labels
    expect(find.text('Make (Brand)'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Toyota, Ford'), findsOneWidget);
    expect(find.text('HiLux, Ranger'), findsOneWidget);

    // Verify Body Type selector exists
    expect(find.text('Body Type (for ATO Tax Classification)'), findsOneWidget);

    // Verify Year field is NOT present in the manual entry dialog
    expect(find.text('Year'), findsNothing);

    // Fill Make & Model
    await tester.enterText(find.widgetWithText(TextField, 'Make (Brand)'), 'Isuzu');
    await tester.enterText(find.widgetWithText(TextField, 'Model'), 'D-Max');
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Dialog dismissed and navigated to confirmVehicle stage
    expect(find.text('Your Vehicle'), findsOneWidget);
    expect(find.text('Isuzu D-Max'), findsOneWidget);
  });
}
