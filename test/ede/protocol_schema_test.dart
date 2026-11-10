import 'package:flutter_test/flutter_test.dart';
import '../../tool/ede/verify_ede_invariants.dart';

void main() {
  group('Evidence Claim Sheet Protocol Parser', () {
    test('correctly parses valid YAML-style Evidence Claim Sheet', () {
      const rawClaim = '''
claim_id: "claim_20261110_abc123"
timestamp: "2026-11-10T12:00:00Z"
author: "adversarial_auditor"
target_invariant: "Tier C"
target_file: "lib/services/engine/tax_calculator_service.dart"
vulnerability: "CPK 5000 km cap resets incorrectly on multiple vehicles"
severity: "CRITICAL"
counterexample_test: |
  test('falsification', () => expect(1, 2));
verdict: "PENDING"
''';

      final claim = EvidenceClaim.parse(rawClaim);

      expect(claim.claimId, 'claim_20261110_abc123');
      expect(claim.author, 'adversarial_auditor');
      expect(claim.targetInvariant, 'Tier C');
      expect(claim.targetFile, 'lib/services/engine/tax_calculator_service.dart');
      expect(claim.severity, 'CRITICAL');
      expect(claim.verdict, 'PENDING');
      expect(claim.counterexampleTest, contains("test('falsification'"));
    });

    test('throws FormatException when required fields are missing', () {
      const incompleteClaim = '''
claim_id: "claim_invalid"
author: "adversarial_auditor"
''';

      expect(() => EvidenceClaim.parse(incompleteClaim), throwsFormatException);
    });
  });
}
