import 'dart:io';
import 'verify_ede_invariants.dart';

/// Test-as-Debate Ground Truth Harness
/// Executes a counterexample test against the codebase to verify an Auditor's claim deterministically.
class DebateFalsificationRunner {
  final String testSandboxDir;

  DebateFalsificationRunner({this.testSandboxDir = 'test/ede/generated'});

  Future<bool> executeClaimFalsification(EvidenceClaim claim) async {
    final dir = Directory(testSandboxDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final testFile = File('$testSandboxDir/${claim.claimId}_test.dart');
    
    // Wrap the raw counterexample in a complete Flutter/Dart test scaffold if needed
    final rawTest = claim.counterexampleTest;
    final fileContent = rawTest.contains('import ')
        ? rawTest
        : '''
import 'package:flutter_test/flutter_test.dart';

void main() {
$rawTest
}
''';

    await testFile.writeAsString(fileContent);

    try {
      final result = await Process.run(
        'flutter',
        ['test', testFile.path],
        runInShell: true,
      );

      // Falsification succeeds if the test FAILS (proving the vulnerability exists)
      final didFail = result.exitCode != 0;
      return didFail;
    } finally {
      if (testFile.existsSync()) {
        testFile.deleteSync();
      }
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart run tool/ede/run_debate_falsification.dart <path-to-claim.yaml>');
    exit(1);
  }

  final claimFile = File(args.first);
  if (!claimFile.existsSync()) {
    stderr.writeln('Claim file not found: ${args.first}');
    exit(1);
  }

  final claim = EvidenceClaim.parse(await claimFile.readAsString());
  final runner = DebateFalsificationRunner();
  stdout.writeln('Running falsification for [${claim.claimId}] against ${claim.targetFile}...');

  final isFalsified = await runner.executeClaimFalsification(claim);

  if (isFalsified) {
    stdout.writeln('RESULT: FALSIFIED! The counterexample broke the system. Invariant breach confirmed.');
    exit(0);
  } else {
    stdout.writeln('RESULT: DISPROVEN. The counterexample passed. Invariant holds intact.');
    exit(0);
  }
}
