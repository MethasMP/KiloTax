import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/vehicle/australian_vehicle_catalog.dart';
import 'package:kilotax/ui/screens/vehicle/vehicle_setup_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vehicle Setup Flow - Stage 3: Tax Method Selection (Gestalt & Poteto)',
      () {
    testWidgets(
        'Renders CPK and Logbook with Gestalt visual parity and domain substantiation',
        (tester) async {
      Vehicle? createdVehicle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              initialStage: VehicleSetupStage.taxMethod,
              onVehicleCreated: (v) => createdVehicle = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a record-keeping method'), findsOneWidget);
      expect(find.text('Logbook Method'), findsOneWidget);
      expect(find.text('Cents per Kilometre'), findsOneWidget);
      expect(find.text('RECOMMENDED FOR UTES'), findsNothing);
      expect(find.textContaining('representative 12-week'), findsNothing);
      await tester.ensureVisible(find.text('Compare methods'));
      await tester.tap(find.text('Compare methods'));
      await tester.pumpAndSettle();
      expect(find.textContaining('representative 12-week'), findsOneWidget);
      await tester.tap(find.text('Compare methods'));
      await tester.pumpAndSettle();

      // Verify Logbook is default selected and proceed to Bluetooth step
      final nextBtn = find.text('Continue to Auto-Track');
      await tester.ensureVisible(nextBtn);
      await tester.pump();
      await tester.tap(nextBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Finish vehicle creation from Bluetooth screen
      final finishBtn = find.text('Save car connection');
      await tester.ensureVisible(finishBtn);
      await tester.pump();
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify domain vehicle produced has Logbook method by default
      expect(createdVehicle, isNotNull);
      expect(createdVehicle!.taxMethod, equals(TaxMethod.logbook));
      expect(createdVehicle!.logbookStartDate, isNull);
    });

    testWidgets(
        'Explicitly selecting Cents per Km produces CPK vehicle when submitted',
        (tester) async {
      Vehicle? createdVehicle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              initialStage: VehicleSetupStage.taxMethod,
              onVehicleCreated: (v) => createdVehicle = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select CPK method
      final cpkCard = find.text('Cents per Kilometre');
      await tester.ensureVisible(cpkCard);
      await tester.pumpAndSettle();
      await tester.tap(cpkCard);
      await tester.pumpAndSettle();

      // Tap next CTA to Bluetooth step
      final nextBtn = find.text('Continue to Auto-Track');
      await tester.ensureVisible(nextBtn);
      await tester.pump();
      await tester.tap(nextBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Finish vehicle creation
      final finishBtn = find.text('Save car connection');
      await tester.ensureVisible(finishBtn);
      await tester.pump();
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(createdVehicle, isNotNull);
      expect(createdVehicle!.taxMethod, equals(TaxMethod.centsPerKm));
      expect(createdVehicle!.logbookStartDate, isNull);
    });

    testWidgets(
        'Commercial vehicle (truck) displays Section 8-1 Actual Expenses instead of CPK',
        (tester) async {
      Vehicle? createdVehicle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleSetupFlow(
              initialStage: VehicleSetupStage.taxMethod,
              initialVehicle: const AustralianVehicleCatalogEntry(
                make: 'Isuzu',
                model: 'NPR 45-155',
                vehicleType: VehicleType.truck,
                fuelType: 'Diesel',
              ),
              onVehicleCreated: (v) => createdVehicle = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ATO s 995-1 commercial callout is displayed
      expect(find.textContaining('Section 8-1'), findsWidgets);
      expect(find.text('Actual Expenses (s 8-1)'), findsOneWidget);
      expect(find.textContaining('Record expenses and business use'),
          findsOneWidget);

      // Verify Cents per km is not shown
      expect(find.text('Cents per Kilometre'), findsNothing);

      // Tap next CTA to Bluetooth step
      final nextBtn = find.text('Continue to Auto-Track');
      await tester.ensureVisible(nextBtn);
      await tester.pump();
      await tester.tap(nextBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Finish vehicle creation
      final finishBtn = find.text('Save car connection');
      await tester.ensureVisible(finishBtn);
      await tester.pump();
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(createdVehicle, isNotNull);
      expect(createdVehicle!.taxMethod, equals(TaxMethod.actualExpenses));
    });
  });
}
