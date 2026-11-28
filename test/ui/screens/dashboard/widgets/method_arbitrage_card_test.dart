import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/theme/app_motion.dart';
import 'package:kiloclaim/ui/screens/dashboard/widgets/method_arbitrage_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('MethodArbitrageCard', () {
    testWidgets('returns SizedBox.shrink when businessKm < 4000 km', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 3999.0,
              centsPerKmClaim: 3400.0,
              logbookClaim: 4500.0,
            ),
          ),
        ),
      );

      expect(find.byType(MethodArbitrageCard), findsOneWidget);
      expect(find.text('METHOD ARBITRAGE'), findsNothing);
      expect(find.text('Unlock Logbook'), findsNothing);
      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
    });

    testWidgets('returns SizedBox.shrink when logbook claim is less than or equal to CPK claim', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4500.0,
              centsPerKmClaim: 3825.0,
              logbookClaim: 3825.0,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
      expect(find.text('METHOD ARBITRAGE'), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when logbook claim advantage is below threshold (< \$250)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4200.0,
              centsPerKmClaim: 3570.0,
              logbookClaim: 3770.0, // Difference: $200 (< $250)
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
    });

    testWidgets('renders split telemetry gauge hierarchy when eligible (< 5,000 km)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4200.0,
              centsPerKmClaim: 3570.0,
              logbookClaim: 4990.0, // Difference: $1,420
            ),
          ),
        ),
      );

      // Header
      expect(find.text('METHOD ARBITRAGE'), findsOneWidget);
      expect(find.text('Claim Comparison Telemetry'), findsOneWidget);
      expect(find.byIcon(LucideIcons.gauge), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);

      // Callout Badge (High-contrast delta pill)
      expect(find.text('+\$1,420 Difference'), findsOneWidget);
      expect(find.text('~\$454 est. cash back in pocket (at 32% marginal rate)'), findsOneWidget);

      // Split Telemetry Presentation
      expect(find.text('CPK (Capped @ 5,000 km)'), findsOneWidget);
      expect(find.text('4,200 km | \$3,570 Cap'), findsOneWidget);
      expect(find.text('Logbook (Uncapped)'), findsOneWidget);
      expect(find.text('4,200 km | \$4,990 Est'), findsOneWidget);

      // Dual-track Gauge Labels
      expect(find.text('CPK'), findsOneWidget);
      expect(find.text('LOG'), findsOneWidget);

      // Action Buttons
      expect(find.text('Unlock Logbook'), findsOneWidget);
      expect(find.text('Keep Cents/km'), findsOneWidget);
    });

    testWidgets('renders split telemetry gauge with statutory 5,000 km cap (> 5,000 km)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 8400.0,
              centsPerKmClaim: 4550.0,
              logbookClaim: 6820.0, // Difference: $2,270
            ),
          ),
        ),
      );

      // Callout Badge
      expect(find.text('+\$2,270 Difference'), findsOneWidget);

      // Split Telemetry Presentation
      expect(find.text('CPK (Capped @ 5,000 km)'), findsOneWidget);
      expect(find.text('5,000 km | \$4,550 Cap'), findsOneWidget);
      expect(find.text('Logbook (Uncapped)'), findsOneWidget);
      expect(find.text('8,400 km | \$6,820 Est'), findsOneWidget);

      // Action Buttons
      expect(find.text('Unlock Logbook'), findsOneWidget);
      expect(find.text('Keep Cents/km'), findsOneWidget);
    });

    testWidgets('tapping Keep Cents/km dismisses card and invokes onDismiss', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4500.0,
              centsPerKmClaim: 3500.0,
              logbookClaim: 5000.0,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Keep Cents/km'), findsOneWidget);
      await tester.tap(find.text('Keep Cents/km'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
    });

    testWidgets('tapping X icon dismisses card and invokes onDismiss', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4500.0,
              centsPerKmClaim: 3500.0,
              logbookClaim: 5000.0,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
    });

    testWidgets('tapping Unlock Logbook fires onExplore callback', (tester) async {
      bool explored = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 4500.0,
              centsPerKmClaim: 3500.0,
              logbookClaim: 5000.0,
              onExplore: () => explored = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Unlock Logbook'));
      await tester.pumpAndSettle();

      expect(explored, isTrue);
    });

    testWidgets('all tap targets satisfy >= 48 pt touch target bounds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MethodArbitrageCard(
                businessKm: 4500.0,
                centsPerKmClaim: 3500.0,
                logbookClaim: 5000.0,
              ),
            ),
          ),
        ),
      );

      // Unlock Logbook CTA
      final exploreFinder = find.widgetWithText(InkWell, 'Unlock Logbook');
      expect(exploreFinder, findsOneWidget);
      final exploreSize = tester.getSize(exploreFinder);
      expect(exploreSize.height, greaterThanOrEqualTo(48.0));
      expect(exploreSize.width, greaterThanOrEqualTo(48.0));

      // Keep Cents/km action
      final keepFinder = find.widgetWithText(InkWell, 'Keep Cents/km');
      expect(keepFinder, findsOneWidget);
      final keepSize = tester.getSize(keepFinder);
      expect(keepSize.height, greaterThanOrEqualTo(48.0));
      expect(keepSize.width, greaterThanOrEqualTo(48.0));

      // Close X button
      final closeFinder = find.widgetWithIcon(InkWell, LucideIcons.x);
      expect(closeFinder, findsOneWidget);
      final closeSize = tester.getSize(closeFinder);
      expect(closeSize.height, greaterThanOrEqualTo(48.0));
      expect(closeSize.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('primary action scales by AppMotion.pressScale on press and settles on release', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MethodArbitrageCard(
                businessKm: 4500.0,
                centsPerKmClaim: 3500.0,
                logbookClaim: 5000.0,
              ),
            ),
          ),
        ),
      );

      final exploreFinder = find.widgetWithText(InkWell, 'Unlock Logbook');
      final gesture = await tester.startGesture(tester.getCenter(exploreFinder));
      await tester.pump();
      await tester.pump(AppMotion.press);

      final scaleFinder = find.descendant(
        of: exploreFinder,
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);
      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidget.scale.value, closeTo(AppMotion.pressScale, 0.01));

      await gesture.up();
      await tester.pump();
      await tester.pump(AppMotion.release);
      expect(scaleWidget.scale.value, closeTo(1.0, 0.01));
    });

    testWidgets(
        'renders proactively via annualized projection when businessKm >= 500 and annualized >= 5000',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 650.0,
              centsPerKmClaim: 4400.0,
              logbookClaim: 6200.0,
              annualizedBusinessKm: 15800.0,
              trackingDays: 15,
            ),
          ),
        ),
      );

      expect(find.text('METHOD ARBITRAGE'), findsOneWidget);
      expect(find.text('+\$1,800 Difference'), findsOneWidget);
      expect(find.text('Unlock Logbook'), findsOneWidget);
    });

    testWidgets(
        'stays hidden when annualizedBusinessKm < 5000 even with >= 14 tracking days',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 550.0,
              centsPerKmClaim: 3000.0,
              logbookClaim: 3800.0,
              annualizedBusinessKm: 4200.0,
              trackingDays: 45,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(MethodArbitrageCard)), Size.zero);
    });

    testWidgets(
        'displays ute benchmark disclosure when isBenchmarkEstimate is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MethodArbitrageCard(
              businessKm: 700.0,
              centsPerKmClaim: 4400.0,
              logbookClaim: 6400.0,
              annualizedBusinessKm: 16000.0,
              trackingDays: 15,
              isBenchmarkEstimate: true,
            ),
          ),
        ),
      );

      expect(find.text('METHOD ARBITRAGE'), findsOneWidget);
      expect(
        find.text(
          'Estimated from typical AU ute running costs. Add receipts to refine.',
        ),
        findsOneWidget,
      );
    });
  });
}
