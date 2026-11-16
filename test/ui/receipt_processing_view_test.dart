import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/theme/app_theme.dart';
import 'package:kilotax/ui/screens/expenses/widgets/receipt_processing_view.dart';

void main() {
  testWidgets('Processing describes actual work without fabricated completion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: ReceiptProcessingView(status: 'Reading receipt details…'))));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Reading receipt details…'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Nothing is saved as an expense yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-reading-sweep')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Reduced motion removes the repeating scan sweep and remains readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
            data: MediaQueryData(
                disableAnimations: true, textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: ReceiptProcessingView(
                        status: 'Reading receipt details…'))))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-reading-sweep')), findsNothing);
    expect(find.text('Reading receipt details…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
