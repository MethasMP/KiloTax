import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/ui/screens/onboarding/onboarding_slides_screen.dart';
import 'package:kiloclaim/ui/widgets/folio_assembly_mark.dart';

void main() {
  Widget welcome({bool reduced = false, required VoidCallback onComplete}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
        home: OnboardingSlidesScreen(onComplete: onComplete),
      );

  testWidgets('Welcome action works immediately while entrance is running',
      (tester) async {
    var started = false;
    await tester.pumpWidget(welcome(onComplete: () => started = true));
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        0);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    expect(started, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'Reduced motion shows completed artwork immediately with no ticker',
      (tester) async {
    await tester.pumpWidget(welcome(reduced: true, onComplete: () {}));
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enabling reduced motion during entrance settles it immediately',
      (tester) async {
    await tester.pumpWidget(welcome(onComplete: () {}));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(welcome(reduced: true, onComplete: () {}));
    await tester.pump();
    expect(
        tester
            .widget<FolioAssemblyMark>(find.byType(FolioAssemblyMark))
            .progress
            .value,
        1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
