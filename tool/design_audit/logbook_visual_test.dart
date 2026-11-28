import 'package:kiloclaim/ui/screens/home/widgets/scaffold_bottom_nav_bar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/core/theme/app_color.dart';
import 'package:kiloclaim/core/theme/app_typography.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_home_body.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_setup_screen.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_progress_screen.dart';
import 'package:kiloclaim/ui/screens/logbook/logbook_trip_entry_screen.dart';

const _fontCache =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
const _lucideCache =
    '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets';
Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async {
    final data = await File(path).readAsBytes();
    return ByteData.view(Uint8List.fromList(data).buffer);
  }

  Future<void> register(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(bytes(f));
    }
    await loader.load();
  }

  const sans = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ];

  // The app now bundles Inter (assets/fonts) — load the real thing so these
  // renders match what ships, including the 400/500/600/700/800/900 cuts.
  await register(
    'Inter',
    ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']
        .map((w) => 'assets/fonts/Inter-$w.ttf')
        .toList(),
  );
  await register('Roboto', sans.map((f) => '$_fontCache/$f').toList());
  await register('MaterialIcons', ['$_fontCache/MaterialIcons-Regular.otf']);
  await register(
      'packages/lucide_icons_flutter/Lucide', ['$_lucideCache/lucide.ttf']);
  await register('Lucide', ['$_lucideCache/lucide.ttf']);
}

void main() {
  setUpAll(_loadFonts);
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final page in ['home', 'setup', 'entry', 'progress', 'gap']) {
        testWidgets('$page width=$width scale=$scale', (tester) async {
          // ignore: invalid_use_of_visible_for_testing_member
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width * 2, 844 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final state = AppState();
          state.addVehicle(Vehicle(
              id: 'visual',
              make: 'Toyota',
              model: 'HiLux',
              regoPlate: 'DL 42 AX',
              initialOdometer: 42150,
              taxMethod: TaxMethod.logbook,
              logbookStartDate:
                  DateTime.now().subtract(const Duration(days: 24))));
          state.recordTrip(Trip(
              id: 'trip',
              vehicleId: 'visual',
              distanceKm: 24.6,
              date: DateTime.now(),
              purpose: 'Client Site',
              classification: TripClassification.business,
              startOdometer: 42150,
              endOdometer: 42174.6,
              originAddress: 'Alexandria Depot',
              destinationAddress: 'Bondi Job Site'));
          if (page == 'gap') {
            state.recordTrip(Trip(
                id: 'after-gap',
                vehicleId: 'visual',
                distanceKm: 20,
                date: DateTime.now(),
                purpose: 'Client Site',
                classification: TripClassification.business,
                startOdometer: 42204.6,
                endOdometer: 42224.6,
                taxMethod: TaxMethod.logbook));
          }
          final Widget screen = switch (page) {
            'setup' => LogbookSetupScreen(appState: state),
            'entry' => LogbookTripEntryScreen(appState: state),
            'progress' || 'gap' => const LogbookProgressScreen(),
            _ => Scaffold(
                backgroundColor: AppColor.canvas,
                bottomNavigationBar: ScaffoldBottomNavBar(
                    currentIndex: 0,
                    taxMethod: TaxMethod.logbook,
                    onTabSelected: (_) {},
                    onCenterActionTap: () {}),
                body: SafeArea(child: LogbookHomeBody(appState: state))),
          };
          await tester.pumpWidget(ChangeNotifierProvider.value(
              value: state,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                      useMaterial3: true,
                      fontFamily: 'Inter',
                      colorScheme: AppColor.scheme,
                      textTheme: AppType.textTheme),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: screen)));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          if (page == 'gap') {
            await tester.tap(find.text('Review missing travel').first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (width == 390 && scale == 1) {
            await expectLater(find.byType(MaterialApp),
                matchesGoldenFile('logbook_2026_11_06/$page.png'));
          }
          if (page == 'setup' || page == 'entry') {
            final field = find.byType(TextField).first;
            await tester.ensureVisible(field);
            await tester.tap(field);
            tester.view.viewInsets = const FakeViewPadding(bottom: 600);
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
            final label =
                page == 'setup' ? 'Start 12-week logbook' : 'Save trip';
            expect(find.text(label).hitTestable(), findsOneWidget);
            expect(tester.getBottomLeft(find.text(label)).dy,
                lessThanOrEqualTo(544));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
