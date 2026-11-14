import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/ui/screens/logbook/widgets/tax_exemption_streak_hero.dart';

void main() {
  group('UteEvolutionStage Domain Logic', () {
    test('resolves correct stage for all 12 weeks', () {
      expect(UteEvolutionStage.fromWeek(1), UteEvolutionStage.stockChassis);
      expect(UteEvolutionStage.fromWeek(2), UteEvolutionStage.stockChassis);
      expect(UteEvolutionStage.fromWeek(3),
          UteEvolutionStage.steelBullbarAlloyTray);
      expect(UteEvolutionStage.fromWeek(4),
          UteEvolutionStage.steelBullbarAlloyTray);
      expect(UteEvolutionStage.fromWeek(5),
          UteEvolutionStage.heavyDutyCanopyBatteries);
      expect(UteEvolutionStage.fromWeek(8),
          UteEvolutionStage.heavyDutyCanopyBatteries);
      expect(UteEvolutionStage.fromWeek(9), UteEvolutionStage.fullTouringRig);
      expect(UteEvolutionStage.fromWeek(11), UteEvolutionStage.fullTouringRig);
      expect(UteEvolutionStage.fromWeek(12), UteEvolutionStage.goldTaxFortress);
      expect(UteEvolutionStage.fromWeek(15), UteEvolutionStage.goldTaxFortress);
    });

    test('stage 2 contains 3-week base locked alert', () {
      final stage2 = UteEvolutionStage.steelBullbarAlloyTray;
      expect(stage2.title, 'Representative Pattern Established');
      expect(stage2.wallBreakerAlert,
          'Week 3 milestone: Representative pattern established');
      expect(stage2.badge, 'Base Locked');
    });

    test('stage 5 represents Logbook period complete', () {
      final stage5 = UteEvolutionStage.goldTaxFortress;
      expect(stage5.title, 'Logbook period complete');
      expect(stage5.badge, 'Period complete');
    });
  });

  group('TaxExemptionStreakHero Widget Tests (Clean Single-Card Architecture)',
      () {
    Widget buildSubject({
      int day = 18,
      int week = 3,
      double atRiskAmount = 12400.0,
      Set<String>? usedGraceShields,
      ValueChanged<GraceShieldType>? onShieldTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaxExemptionStreakHero(
              currentDay: day,
              currentWeek: week,
              atRiskAmount: atRiskAmount,
              usedGraceShields: usedGraceShields,
              onShieldTap: onShieldTap,
            ),
          ),
        ),
      );
    }

    testWidgets('renders Week Y of 12 correctly', (tester) async {
      await tester.pumpWidget(buildSubject(day: 21, week: 3));

      expect(find.text('Week 3 of 12'), findsOneWidget);
      expect(find.text('12-WEEK LOGBOOK'), findsOneWidget);
      expect(find.text('ATO Compliant'), findsNothing);
      expect(find.text('On Track'), findsNothing);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          21 / 84);
    });

    testWidgets('displays week progress with genuine evidence metrics',
        (tester) async {
      await tester.pumpWidget(buildSubject(week: 3));

      expect(find.text('Vehicle Odometer'), findsOneWidget);
      expect(find.textContaining('business'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('5 years'), findsNothing);
    });

    testWidgets('renders final week message on week 12', (tester) async {
      await tester.pumpWidget(buildSubject(day: 84, week: 12));

      expect(find.text('Week 12 of 12'), findsOneWidget);
      expect(find.text('Day 84 of 84 · 0 days remaining'), findsOneWidget);
      expect(find.textContaining('Certified'), findsNothing);
    });

    testWidgets('renders clean status indicator', (tester) async {
      await tester.pumpWidget(buildSubject(
        usedGraceShields: const {'rainedOut'},
      ));

      expect(find.text('Keep reviewing trips as you go.'), findsOneWidget);
      expect(find.textContaining('active & recording'), findsNothing);
    });
  });
}
