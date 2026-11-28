import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/vehicle/australian_vehicle_catalog.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';
import 'package:kiloclaim/ui/screens/vehicle/widgets/tax_option_card.dart';
import 'package:kiloclaim/ui/widgets/tactile_primary_button.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle
              .load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, truck: false, name: 'car'),
    (
      size: const Size(320, 568),
      scale: 2.0,
      truck: false,
      name: 'compact_text2'
    ),
    (
      size: const Size(844, 390),
      scale: 2.0,
      truck: false,
      name: 'landscape_text2'
    ),
    (size: const Size(390, 844), scale: 1.0, truck: true, name: 'commercial'),
  ]) {
    testWidgets('Tax method explicit selection and details ${scenario.name}',
        (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Vehicle? created;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scenario.scale),
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('method-capture'),
          child: VehicleSetupFlow(
            initialStage: VehicleSetupStage.taxMethod,
            includeBluetoothSetup: false,
            initialVehicle: scenario.truck
                ? const AustralianVehicleCatalogEntry(
                    make: 'Isuzu',
                    model: 'NPR',
                    vehicleType: VehicleType.truck,
                    fuelType: 'Diesel',
                  )
                : null,
            onVehicleCreated: (vehicle) => created = vehicle,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester
              .widget<TactilePrimaryButton>(find.byType(TactilePrimaryButton))
              .onPressed,
          isNull);
      expect(
          tester
              .widgetList<TaxOptionCard>(find.byType(TaxOptionCard))
              .every((card) => !card.isSelected),
          isTrue);
      final buttonBounds = tester.getRect(find.text('Save vehicle'));
      expect(buttonBounds.bottom, lessThan(scenario.size.height - 34));
      await tester.tap(find.text('Save vehicle'));
      expect(created, isNull);
      await expectLater(find.byKey(const ValueKey('method-capture')),
          matchesGoldenFile('goldens/tax_method/${scenario.name}.png'));

      final details = find
          .text(scenario.truck ? 'What records do I need?' : 'Compare methods');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      if (scenario.truck) {
        expect(find.text('Logbook Method'), findsNothing);
        expect(find.text('Cents per Kilometre'), findsNothing);
        expect(find.textContaining('representative logbook'), findsNothing);
      } else {
        expect(find.text('Actual expenses'), findsNothing);
        expect(find.textContaining('at least 12 continuous weeks'),
            findsOneWidget);
      }
      expect(tester.getRect(find.text('Save vehicle')), buttonBounds,
          reason: 'Expanding guidance never moves the primary action');
      expect(tester.takeException(), isNull);
      await tester.tap(details);
      await tester.pumpAndSettle();
      final selection = find
          .text(scenario.truck ? 'Actual Expenses (s 8-1)' : 'Logbook Method');
      await tester.ensureVisible(selection);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();
      expect(created?.taxMethod,
          scenario.truck ? TaxMethod.actualExpenses : TaxMethod.logbook);
      expect(tester.takeException(), isNull);
    });
  }
}
