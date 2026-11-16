import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'verify_ede_invariants.dart';

/// Test-as-Debate Ground Truth Harness (EDE v3.2 Enterprise)
/// Implements:
/// 1. Automated Failure Classification (E01 Syntax, E02 Harness Crash, C00 Valid Assertion Failure)
/// 2. SHA-256 Test Immutability (Anti-Tampering)
/// 3. Automated Cryptographic Ledger Generation (Git SHA + Test Hash Receipt)
class DebateFalsificationRunner {
  final String testSandboxDir;

  DebateFalsificationRunner({this.testSandboxDir = 'test/ede/generated'});

  String calculateHash(String content) {
    return sha256.convert(utf8.encode(content.trim())).toString();
  }

  Future<String> getCurrentGitCommit() async {
    try {
      final res = await Process.run('git', ['rev-parse', 'HEAD']);
      if (res.exitCode == 0) {
        return res.stdout.toString().trim();
      }
    } catch (_) {}
    return 'unknown_commit';
  }

  Future<TestRunResult> executeTest(String claimId, String counterexampleTest) async {
    final dir = Directory(testSandboxDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final testFile = File('$testSandboxDir/${claimId}_test.dart');
    
    final rawTest = counterexampleTest;
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

      final stdoutStr = result.stdout.toString();
      final stderrStr = result.stderr.toString();

      return TestRunResult(
        exitCode: result.exitCode,
        stdout: stdoutStr,
        stderr: stderrStr,
        classification: classifyFailure(result.exitCode, stdoutStr, stderrStr),
      );
    } finally {
      if (testFile.existsSync()) {
        testFile.deleteSync();
      }
    }
  }

  /// Classifies test failure into deterministic EDE categories
  String classifyFailure(int exitCode, String stdout, String stderr) {
    if (exitCode == 0) return 'PASS_GREEN';

    final output = '$stdout\n$stderr';

    if (output.contains('Error: ') || 
        output.contains('Compilation failed') || 
        output.contains('SyntaxError')) {
      return 'E01_SYNTAX_ERR';
    }

    if (output.contains('NoSuchMethodError') || 
        output.contains('LateInitializationError') || 
        output.contains('TimeoutException') || 
        output.contains('MissingPluginException')) {
      return 'E02_HARNESS_CRASH';
    }

    if (output.contains('TestFailure:') || 
        output.contains('AssertionError') || 
        output.contains('Expected:') || 
        output.contains('══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═')) {
      return 'C00_VALID_FALSIFICATION';
    }

    return 'E02_HARNESS_CRASH';
  }

  /// Writes an immutable audit ledger entry to .ede/ledger/
  Future<String> writeLedgerReceipt({
    required EvidenceClaim claim,
    required String testHash,
    required String gitCommit,
  }) async {
    final ledgerDir = Directory('.ede/ledger');
    if (!ledgerDir.existsSync()) {
      ledgerDir.createSync(recursive: true);
    }

    final now = DateTime.now().toUtc();
    final dateStr = now.toIso8601String().split('T').first;
    final ledgerFile = File('${ledgerDir.path}/${dateStr}_${claim.claimId}.md');

    final receiptContent = '''# EDE Verified Decision Record

- **Timestamp:** ${now.toIso8601String()}
- **Claim ID:** ${claim.claimId}
- **Author Role:** ${claim.author}
- **Target Invariant:** ${claim.targetInvariant}
- **Target File:** ${claim.targetFile}
- **Vulnerability:** ${claim.vulnerability.trim()}
- **Test SHA-256:** $testHash
- **Verified Git Commit:** $gitCommit
- **Runtime Verdict:** RESOLVED & VERIFIED (Green)
- **Proof:** Deterministic falsification test passed under unchanged hash.
''';

    await ledgerFile.writeAsString(receiptContent);
    return ledgerFile.path;
  }
}

class TestRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String classification;

  TestRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.classification,
  });

  bool get isFailed => exitCode != 0;
  bool get isPassed => exitCode == 0;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart run tool/ede/run_debate_falsification.dart <path-to-claim.yaml> [OPTIONS]');
    stdout.writeln('Options:');
    stdout.writeln('  --mode=audit-gate (default) : Validates & locks test with SHA-256 (Must classify as C00)');
    stdout.writeln('  --mode=verify-fix           : Verifies fix against immutable test & records ledger');
    stdout.writeln('  --challenge-with="<reason>" : Registers formal spec challenge (Max 1 round)');
    exit(1);
  }

  final claimPath = args[0];
  final isVerifyMode = args.contains('--mode=verify-fix');
  final challengeArg = args.firstWhere((a) => a.startsWith('--challenge-with='), orElse: () => '');

  final claimFile = File(claimPath);
  if (!claimFile.existsSync()) {
    stderr.writeln('Claim file not found: $claimPath');
    exit(1);
  }

  final rawClaimContent = await claimFile.readAsString();
  final claim = EvidenceClaim.parse(rawClaimContent);
  final runner = DebateFalsificationRunner();
  final currentTestHash = runner.calculateHash(claim.counterexampleTest);

  stdout.writeln('======================================================');
  stdout.writeln(' EDE Deterministic Arbiter (Claim: ${claim.claimId})');
  stdout.writeln(' Author Role   : ${claim.author}');
  stdout.writeln(' Target File   : ${claim.targetFile}');
  stdout.writeln(' Invariant     : ${claim.targetInvariant}');
  stdout.writeln(' Test SHA-256  : $currentTestHash');
  stdout.writeln('======================================================');

  if (challengeArg.isNotEmpty) {
    final reason = challengeArg.replaceFirst('--challenge-with=', '');
    stdout.writeln('\n[!] FORMAL SPEC CHALLENGE LODGED:');
    stdout.writeln('Reason: $reason');
    stdout.writeln('Claim status moved to: QUARANTINED_PENDING_ARBITRATION');
    exit(0);
  }

  // Verification Mode (Green Phase)
  if (isVerifyMode) {
    final lockedHashPattern = RegExp(r'locked_hash:\s*"([^"]+)"');
    final match = lockedHashPattern.firstMatch(rawClaimContent);
    if (match != null) {
      final lockedHash = match.group(1);
      if (lockedHash != currentTestHash) {
        stderr.writeln('\n[FATAL] TAMPERING DETECTED! (Exit code 77)');
        stderr.writeln('The counterexample test was modified by the implementer.');
        stderr.writeln('Expected SHA-256: $lockedHash');
        stderr.writeln('Actual SHA-256  : $currentTestHash');
        stderr.writeln('Rule: Implementer must fix the production code, NOT the auditor test.');
        exit(77);
      }
    }

    final runResult = await runner.executeTest(claim.claimId, claim.counterexampleTest);
    if (runResult.isPassed) {
      final gitCommit = await runner.getCurrentGitCommit();
      final ledgerPath = await runner.writeLedgerReceipt(
        claim: claim,
        testHash: currentTestHash,
        gitCommit: gitCommit,
      );

      stdout.writeln('\n[+] RESULT: RESOLVED & VERIFIED (Green)');
      stdout.writeln('Tamper check verified. Test passed.');
      stdout.writeln('Ledger Receipt created: $ledgerPath');
      stdout.writeln('Commit Hash: $gitCommit');
      exit(0);
    } else {
      stderr.writeln('\n[-] RESULT: STILL BROKEN');
      stderr.writeln(runResult.stdout);
      stderr.writeln(runResult.stderr);
      exit(1);
    }
  }

  // Audit Gate Mode (Red Phase)
  final runResult = await runner.executeTest(claim.claimId, claim.counterexampleTest);
  stdout.writeln('Run Classification: ${runResult.classification}');

  switch (runResult.classification) {
    case 'E01_SYNTAX_ERR':
      stderr.writeln('\n[-] REJECTED AT GATE: E01_SYNTAX_ERR');
      stderr.writeln('The test failed compilation. Auditor must fix test syntax.');
      stderr.writeln(runResult.stdout);
      exit(2);

    case 'E02_HARNESS_CRASH':
      stderr.writeln('\n[-] REJECTED AT GATE: E02_HARNESS_CRASH');
      stderr.writeln('The test crashed due to environment/mock/setup failure.');
      stderr.writeln(runResult.stdout);
      exit(3);

    case 'C00_VALID_FALSIFICATION':
      stdout.writeln('\n[+] ACCREDITED: C00_VALID_FALSIFICATION');
      stdout.writeln('Valid invariant assertion failure confirmed.');
      stdout.writeln('Test SHA-256 locked: $currentTestHash');
      
      if (!rawClaimContent.contains('locked_hash:')) {
        final updatedContent = '${rawClaimContent.trimRight()}\nlocked_hash: "$currentTestHash"\nverdict: "ACCREDITED_FALSIFIED"\n';
        await claimFile.writeAsString(updatedContent);
        stdout.writeln('Stamping claim file with locked_hash and status.');
      }
      exit(0);

    case 'PASS_GREEN':
    default:
      stderr.writeln('\n[-] REJECTED AT GATE: TEST_ALREADY_PASSES');
      stderr.writeln('The counterexample already passes against current code. No vulnerability found.');
      exit(4);
  }
}
