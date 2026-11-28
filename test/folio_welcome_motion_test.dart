import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_motion.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kiloclaim/ui/widgets/folio_assembly_mark.dart';
import 'package:kiloclaim/ui/widgets/kiloclaim_brand_lockup.dart';

Widget welcome({bool reduced = false, VoidCallback? onComplete}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: OnboardingSlidesScreen(onComplete: onComplete ?? () {}),
    );

Future<Uint8List> pixels(WidgetTester tester, Widget artwork,
    {double size = 128, bool reduced = false}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Center(
      child: RepaintBoundary(
        key: const ValueKey('pixels'),
        child: SizedBox.square(dimension: size, child: artwork),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('pixels')));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void main() {
  testWidgets('Assembly settles at 560ms without moving wordmark or layout',
      (tester) async {
    await tester.pumpWidget(welcome());
    final mark =
        tester.widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark));
    final logoBounds = tester.getRect(find.byType(KiloClaimBrandLockup));
    final textBounds = tester.getRect(find.text('KiloClaim'));
    expect(mark.progress.value, 0);
    await tester.pump();
    await tester.pump(AppMotion.brandAssembly);
    expect(mark.progress.value, closeTo(0.7, 0.001));
    expect(tester.getRect(find.byType(KiloClaimBrandLockup)), logoBounds);
    expect(tester.getRect(find.text('KiloClaim')), textBounds);
    final boundaryFinder = find.byType(FolioAssemblyMark);
    expect(boundaryFinder, findsOneWidget);
    // The shared welcome timeline continues; the logo's own segment is done.
    await tester.pumpAndSettle();
    expect(mark.progress.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(welcome());
    await tester.pump();
    expect(tester.widget<FolioAssemblyMark>(boundaryFinder).progress.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Reduce Motion mid-flight settles permanently without replay',
      (tester) async {
    await tester.pumpWidget(welcome());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        greaterThan(0));
    await tester.pumpWidget(welcome(reduced: true));
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(welcome());
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Welcome can be removed during assembly without ticker errors',
      (tester) async {
    await tester.pumpWidget(welcome());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Default lockup stays static with one accessible brand label',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: KiloClaimBrandLockup(compact: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FolioAssemblyMark), findsNothing);
    expect(find.bySemanticsLabel('KiloClaim'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    semantics.dispose();
  });

  testWidgets('Lower plane appears before middle and upper planes',
      (tester) async {
    final frame = await pixels(
        tester,
        const FolioAssemblyMark(
            progress: AlwaysStoppedAnimation(0.1), size: 128));
    bool isOrange(int x, int y) {
      final i = (y * 128 + x) * 4;
      return frame[i] - frame[i + 1] > 30;
    }

    expect(isOrange(30, 96), isTrue);
    expect(isOrange(70, 85), isFalse);
    expect(isOrange(95, 65), isFalse);
  });

  testWidgets('Reduced mark renders complete even with zero timeline progress',
      (tester) async {
    final reference = await pixels(tester, const KiloClaimBrandMark(size: 128));
    final result = await pixels(tester,
        const FolioAssemblyMark(progress: AlwaysStoppedAnimation(0), size: 128),
        reduced: true);
    var error = 0;
    for (var i = 0; i < reference.length; i++) {
      error += (reference[i] - result[i]).abs();
    }
    expect(error / reference.length, lessThan(0.5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Finished and reduced artwork match the production SVG',
      (tester) async {
    for (final size in [44.0, 128.0]) {
      final reference =
          await pixels(tester, KiloClaimBrandMark(size: size), size: size);
      for (final progress in [0.7, 1.0]) {
        final result = await pixels(
            tester,
            FolioAssemblyMark(
                progress: AlwaysStoppedAnimation(progress), size: size),
            size: size);
        var error = 0;
        for (var i = 0; i < reference.length; i++) {
          error += (reference[i] - result[i]).abs();
        }
        // Allow only rasterizer edge-rounding, not a changed silhouette.
        expect(error / reference.length, lessThan(0.5),
            reason: 'SVG parity at ${size}px / $progress');
      }
    }
  });
}
