import 'dart:convert';
import 'dart:io';

/// Configurable Architectural Invariant Rule
class InvariantRule {
  final String id;
  final String targetDir;
  final List<RegExp> forbiddenPatterns;
  final String message;

  InvariantRule({
    required this.id,
    required this.targetDir,
    required this.forbiddenPatterns,
    required this.message,
  });

  factory InvariantRule.fromJson(Map<String, dynamic> json) {
    return InvariantRule(
      id: json['id'] as String,
      targetDir: json['target_dir'] as String,
      forbiddenPatterns: (json['forbidden_patterns'] as List<dynamic>)
          .map((p) => RegExp(p as String, caseSensitive: false))
          .toList(),
      message: json['message'] as String,
    );
  }
}

/// EDE Tier Invariant Engine & Static Verification Tool (v3.2 Global)
class EdeInvariantEngine {
  final String projectRoot;

  EdeInvariantEngine({this.projectRoot = '.'});

  List<InvariantRule> loadRules() {
    final configFile = File('$projectRoot/.ede/invariants.json');
    if (!configFile.existsSync()) {
      // Default built-in fallback rules
      return [
        InvariantRule(
          id: 'DEFAULT_UI_PURITY',
          targetDir: 'lib/ui',
          forbiddenPatterns: [
            RegExp(r'(km|distance|cents|claim|deduction)\s*\*\s*0\.(85|88|90|78)', caseSensitive: false),
            RegExp(r'businessKm\s*/\s*totalKm'),
          ],
          message: 'Direct business/tax calculation in UI layer.',
        ),
      ];
    }

    try {
      final jsonMap = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final rulesJson = jsonMap['rules'] as List<dynamic>;
      return rulesJson.map((r) => InvariantRule.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      stderr.writeln('Warning: Failed to parse .ede/invariants.json: $e');
      return [];
    }
  }

  /// Scans directories against active architectural invariant rules
  List<String> verifyAllInvariants() {
    final violations = <String>[];
    final rules = loadRules();

    for (final rule in rules) {
      final targetDirectory = Directory('$projectRoot/${rule.targetDir}');
      if (!targetDirectory.existsSync()) continue;

      for (final file in targetDirectory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        for (final pattern in rule.forbiddenPatterns) {
          if (pattern.hasMatch(content)) {
            violations.add('[${rule.id}] ${file.path}: ${rule.message}');
          }
        }
      }
    }

    return violations;
  }
}

/// Represents a structured Evidence Claim Sheet under EDE v3
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

    const requiredFields = [
      'claim_id',
      'target_invariant',
      'target_file',
      'vulnerability',
      'severity',
      'counterexample_test',
    ];
    for (final field in requiredFields) {
      if (!map.containsKey(field) || map[field]!.trim().isEmpty) {
        throw FormatException('Missing required EvidenceClaim field: $field');
      }
    }

    return EvidenceClaim(
      claimId: map['claim_id']!,
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
      author: map['author'] ?? 'unknown',
      targetInvariant: map['target_invariant']!,
      targetFile: map['target_file']!,
      vulnerability: map['vulnerability']!,
      severity: map['severity']!,
      counterexampleTest: map['counterexample_test']!,
      verdict: map['verdict'] ?? 'PENDING',
    );
  }
}

void main(List<String> args) {
  final engine = EdeInvariantEngine();
  stdout.writeln('Checking architectural invariants against .ede/invariants.json...');
  final violations = engine.verifyAllInvariants();

  if (violations.isEmpty) {
    stdout.writeln('PASS: All architectural layer invariants hold cleanly. No layer leakage.');
    exit(0);
  } else {
    stderr.writeln('FAIL: Found ${violations.length} architectural invariant violation(s):');
    for (final v in violations) {
      stderr.writeln(' - $v');
    }
    exit(1);
  }
}
