import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/first_trip_card.dart';
import 'package:kilotax/ui/screens/tracking/tracking_setup_screen.dart';

void main() {
  testWidgets('Capture journey screens at phone width and check large text',
      (tester) async {
    await tester.runAsync(() async {
      for (final entry in {
        'Inter': 'assets/fonts/Inter-Regular.ttf',
        'MaterialIcons':
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        'packages/lucide_icons_flutter/Lucide':
            '/Users/methas/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.20/assets/lucide.ttf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(File(entry.value)
              .readAsBytes()
              .then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState();
    final screens = <String, Widget>{
      'welcome': OnboardingSlidesScreen(onComplete: () {}),
      'first_trip': Scaffold(
          body: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                      child: FirstTripCard(appState: state))))),
      'tracking_setup': const TrackingSetupScreen(),
    };
    for (final entry in screens.entries) {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
              theme: ThemeData(
                  fontFamily: 'Inter',
                  colorScheme: AppColor.scheme,
                  useMaterial3: true),
              home: RepaintBoundary(
                  key: const ValueKey('capture'), child: entry.value))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('capture')),
          matchesGoldenFile('journey_captures/${entry.key}.png'));
    }
    tester.view.physicalSize = const Size(320, 640);
    for (final entry in screens.entries) {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!),
              home: entry.value)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: '${entry.key} at 320pt with 200% text');
    }
  });
}
