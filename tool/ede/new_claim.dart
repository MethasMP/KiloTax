import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart run tool/ede/new_claim.dart <short_description> [role]');
    stdout.writeln('Roles: tax-lawyer (default) | cso | edge-breaker | concurrency');
    exit(1);
  }

  final desc = args[0].replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  final role = args.length > 1 ? args[1] : 'tax-lawyer';
  final now = DateTime.now().toUtc();
  final timestampStr = now.toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.').first;
  final claimId = 'claim_${timestampStr}_$desc';

  final claimsDir = Directory('.ede/claims');
  if (!claimsDir.existsSync()) {
    claimsDir.createSync(recursive: true);
  }

  final filePath = '.ede/claims/$claimId.yaml';

  final template = '''claim_id: "$claimId"
timestamp: "${now.toIso8601String()}"
author: "$role"
target_invariant: "Tier A | Tier B | Tier C | Tier D"
target_file: "lib/services/..."
vulnerability: >
  Concise explanation of the potential bug, regulatory breach, or invariant violation.
severity: "CRITICAL | MAJOR | MINOR"
counterexample_test: |
  void main() {
    test('Falsification counterexample for $desc', () {
      // Step 1 (Red): Minimal test proving the vulnerability currently fails
      expect(true, isFalse);
    });
  }
verdict: "PENDING"
''';

  File(filePath).writeAsStringSync(template);
  stdout.writeln('Created claim sheet: $filePath');
  stdout.writeln('Next step: Fill in vulnerability & counterexample_test, then run:');
  stdout.writeln('  dart run tool/ede/run_debate_falsification.dart $filePath');
}
