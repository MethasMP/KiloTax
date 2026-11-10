import 'dart:io';

/// EDE Tier Invariant Engine & Static Verification Tool
/// Enforces:
/// 1. Tier C -> Tier D purity (UI code in lib/ui/ must not calculate tax arithmetic directly)
/// 2. Evidence Claim Sheet integrity
class EdeInvariantEngine {
  final String projectRoot;

  EdeInvariantEngine({this.projectRoot = '.'});

  /// Scans lib/ui/ to ensure no screens perform raw tax arithmetic or ATO rate multiplications
  List<String> verifyTierDPurity() {
    final violations = <String>[];
    final uiDir = Directory('$projectRoot/lib/ui');
    if (!uiDir.existsSync()) return violations;

    final taxPatterns = [
      RegExp(r'(km|distance|cents|claim|deduction)\s*\*\s*0\.(85|88|90|78)', caseSensitive: false), // Hardcoded ATO cents/km rates against distance
      RegExp(r'businessKm\s*/\s*totalKm'), // Raw business % calculations
    ];

    for (final file in uiDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      for (final pattern in taxPatterns) {
        if (pattern.hasMatch(content)) {
          violations.add('Violation in ${file.path}: Direct tax arithmetic found in Tier D presentation layer.');
        }
      }
    }

    return violations;
  }
}

/// Represents a structured Evidence Claim Sheet under EDE v2.0
class EvidenceClaim {
  final String claimId;
  final String timestamp;
  final String author;
  final String targetInvariant;
  final String targetFile;
  final String vulnerability;
  final String severity;
  final String counterexampleTest;
  String verdict;

  EvidenceClaim({
    required this.claimId,
    required this.timestamp,
    required this.author,
    required this.targetInvariant,
    required this.targetFile,
    required this.vulnerability,
    required this.severity,
    required this.counterexampleTest,
    required this.verdict,
  });

  /// Parses a YAML-like structured Markdown claim string
  factory EvidenceClaim.parse(String raw) {
    final lines = raw.split('\n');
    final map = <String, String>{};
    String? multiLineKey;
    final multiLineBuffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (multiLineKey != null) {
        if (line.startsWith('  ') || line.startsWith('\t') || line.isEmpty) {
          multiLineBuffer.writeln(line.trimLeft());
          continue;
        } else {
          map[multiLineKey] = multiLineBuffer.toString().trim();
          multiLineKey = null;
          multiLineBuffer.clear();
        }
      }

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex != -1) {
        final key = trimmed.substring(0, colonIndex).trim();
        var val = trimmed.substring(colonIndex + 1).trim();

        if (val == '|' || val == '>') {
          multiLineKey = key;
        } else {
          if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
            val = val.substring(1, val.length - 1);
          } else if (val.startsWith("'") && val.endsWith("'") && val.length >= 2) {
            val = val.substring(1, val.length - 1);
          }
          map[key] = val;
        }
      }
    }

    if (multiLineKey != null) {
      map[multiLineKey] = multiLineBuffer.toString().trim();
    }

    final requiredFields = [
      'claim_id',
      'timestamp',
      'author',
      'target_invariant',
      'target_file',
      'vulnerability',
      'severity',
      'counterexample_test',
      'verdict',
    ];

    for (final req in requiredFields) {
      if (!map.containsKey(req) || map[req]!.isEmpty) {
        throw FormatException('Missing required Evidence Claim field: $req');
      }
    }

    return EvidenceClaim(
      claimId: map['claim_id']!,
      timestamp: map['timestamp']!,
      author: map['author']!,
      targetInvariant: map['target_invariant']!,
      targetFile: map['target_file']!,
      vulnerability: map['vulnerability']!,
      severity: map['severity']!,
      counterexampleTest: map['counterexample_test']!,
      verdict: map['verdict']!,
    );
  }

  String toYaml() {
    return '''
claim_id: "$claimId"
timestamp: "$timestamp"
author: "$author"
target_invariant: "$targetInvariant"
target_file: "$targetFile"
vulnerability: >
  $vulnerability
severity: "$severity"
counterexample_test: |
${counterexampleTest.split('\n').map((l) => '  $l').join('\n')}
verdict: "$verdict"
''';
  }
}

void main(List<String> args) {
  final engine = EdeInvariantEngine();
  stdout.writeln('Checking EDE Tier Invariants...');

  final violations = engine.verifyTierDPurity();
  if (violations.isEmpty) {
    stdout.writeln('ALL TIER INVARIANTS SATISFIED (Tier D is pure).');
    exit(0);
  } else {
    stderr.writeln('TIER INVARIANT BREACH DETECTED:');
    for (final v in violations) {
      stderr.writeln('  - $v');
    }
    exit(1);
  }
}
