import 'package:flutter_test/flutter_test.dart';
import '../../.agents/skills/ede/templates/tool/triage_risk_gate.dart';

void main() {
  group('EDE Risk-Tier Triage Gate Classifier (Lean)', () {
    test('classifies tax calculation engines as Tier 1', () {
      final files = [
        'lib/services/tax_calculator_service.dart',
        'lib/views/home_page.dart',
      ];
      final (isTier1, critical, standard) = classifyRisk(files);
      expect(isTier1, isTrue);
      expect(critical, contains('lib/services/tax_calculator_service.dart'));
      expect(standard, contains('lib/views/home_page.dart'));
    });

    test('classifies core data models as Tier 1', () {
      final files = [
        'lib/models/trip.dart',
        'lib/models/vehicle.dart',
      ];
      final (isTier1, critical, _) = classifyRisk(files);
      expect(isTier1, isTrue);
      expect(critical.length, equals(2));
    });

    test('classifies UI views and widgets as Tier 2 (Fast-Track)', () {
      final files = [
        'lib/views/trip_history_view.dart',
        'lib/widgets/stat_card.dart',
        'lib/theme/colors.dart',
      ];
      final (isTier1, critical, standard) = classifyRisk(files);
      expect(isTier1, isFalse);
      expect(critical, isEmpty);
      expect(standard.length, equals(3));
    });

    test('classifies tool/ede infrastructure updates as Tier 1', () {
      final files = [
        'tool/ede/verify_ede_invariants.dart',
      ];
      final (isTier1, _, _) = classifyRisk(files);
      expect(isTier1, isTrue);
    });
  });
}
