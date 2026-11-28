import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_theme.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(File('assets/fonts/Inter-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    }
    await inter.load();
    for (final family in {
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
      theme: AppTheme.light,
      home: RepaintBoundary(
          key: const ValueKey('frame'),
          child: OnboardingSlidesScreen(onComplete: () {})),
    ));
    for (var frame = 0; frame <= 20; frame++) {
      if (frame > 0) await tester.pump(const Duration(milliseconds: 40));
      await expectLater(find.byKey(const ValueKey('frame')),
          matchesGoldenFile('folio_motion_captures/frame_$frame.png'));
    }
    expect(tester.takeException(), isNull);
  });
}
