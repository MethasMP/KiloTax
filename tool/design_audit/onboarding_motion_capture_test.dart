import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/theme/app_color.dart';
import 'package:kilotax/ui/screens/onboarding/onboarding_slides_screen.dart';

void main() {
  setUpAll(() async {
    for (final family in {
      'Inter': 'assets/fonts/Inter-Regular.ttf',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(family.key)
        ..addFont(File(family.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  testWidgets('Capture one-shot welcome entrance frames', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'Inter',
          colorScheme: AppColor.scheme,
          useMaterial3: true),
      home: RepaintBoundary(
          key: const ValueKey('frame'),
          child: OnboardingSlidesScreen(onComplete: () {})),
    ));
    for (var frame = 0; frame <= 10; frame++) {
      if (frame > 0) await tester.pump(const Duration(milliseconds: 80));
      await expectLater(find.byKey(const ValueKey('frame')),
          matchesGoldenFile('motion_captures/frame_$frame.png'));
    }
    expect(tester.takeException(), isNull);
  });
}
