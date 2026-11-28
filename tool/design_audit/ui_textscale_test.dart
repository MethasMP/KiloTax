// DESIGN AUDIT — accessibility text-scaling probe.
//
// Renders the two primary screens at enlarged system text sizes to find where
// the fixed-height layouts break. Run:
//   flutter test tool/design_audit/ui_textscale_test.dart --update-goldens

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/ui/screens/home/main_scaffold_screen.dart';

const String _fontCache =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
const String _lucideCache =
    '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets';

AppState _seed() {
  final s = AppState();
  s.addVehicle(Vehicle(
    id: 'v',
    make: 'Ford',
    model: 'Ranger 2024',
    regoPlate: '1GTF892',
    initialOdometer: 42150.0,
    vehicleType: VehicleType.ute,
    taxMethod: TaxMethod.centsPerKm,
  ));
  s.recordTrip(Trip(
    id: 't1',
    vehicleId: 'v',
    distanceKm: 18.4,
    date: DateTime(2026, 9, 22, 7, 12),
    purpose: 'Collect timber & fixings',
    startOdometer: 42150.0,
    endOdometer: 42168.4,
    classification: TripClassification.business,
    originAddress: 'Bunnings Trade, Alexandria NSW',
    destinationAddress: 'Bondi Residential Reno, Bondi NSW',
  ));
  s.recordExpense(VehicleExpense(
    id: 'e1',
    vehicleId: 'v',
    amount: 184.60,
    category: ExpenseCategory.toolsMaterials,
    date: DateTime(2026, 9, 12),
    notes: 'Bunnings',
  ));
  return s;
}

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String p) async =>
      ByteData.view(Uint8List.fromList(await File(p).readAsBytes()).buffer);
  Future<void> reg(String fam, List<String> files) async {
    final l = FontLoader(fam);
    for (final f in files) {
      l.addFont(bytes(f));
    }
    await l.load();
  }

  const sans = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'];
  await reg(
    'Inter',
    ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']
        .map((w) => 'assets/fonts/Inter-$w.ttf')
        .toList(),
  );
  await reg('Roboto', sans.map((f) => '$_fontCache/$f').toList());
  await reg('MaterialIcons', ['$_fontCache/MaterialIcons-Regular.otf']);
  await reg(
      'packages/lucide_icons_flutter/Lucide', ['$_lucideCache/lucide.ttf']);
  await reg('Lucide', ['$_lucideCache/lucide.ttf']);
}

void _drain(WidgetTester t) {
  var g = 0;
  while (t.takeException() != null && g++ < 100) {}
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    debugDisableShadows = false;
  });

  for (final scale in <double>[1.0, 1.3, 2.0]) {
    testWidgets('home @ textScale $scale', (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3.0;
      t.view.padding = const FakeViewPadding(top: 141, bottom: 102);
      t.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
      addTearDown(t.view.reset);

      final s = _seed();
      await t.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: s,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              textScaler: TextScaler.linear(scale),
            ),
            child: const MainScaffoldScreen(),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 400));
      _drain(t);

      Directory('tool/design_audit/captures').createSync(recursive: true);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            'captures/a11y_textscale_${scale.toStringAsFixed(1)}.png'),
      );
    });
  }
}
