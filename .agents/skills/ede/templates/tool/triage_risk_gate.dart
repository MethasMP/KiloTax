// EDE Risk-Tier Triage Gate (Dart - Lean Ponytail Edition)
import 'dart:io';

void main(List<String> args) {
  final files = args.isNotEmpty ? args : getChangedFiles();
  final (isTier1, critical, standard) = classifyRisk(files);

  print('=== EDE Risk Gate ===');
  print('Verdict: ${isTier1 ? "TIER 1 (High Stakes - Full EDE Required)" : "TIER 2 (Fast-Track Permitted)"}');
  if (critical.isNotEmpty) {
    print('Critical:');
    for (final f in critical) print('  [!] $f');
  }
  if (standard.isNotEmpty) {
    print('Standard:');
    for (final f in standard) print('  [-] $f');
  }
  print('Action: ${isTier1 ? "Full Isolated Auditor claim sheet + debate falsification required." : "Fast-Track permitted (lint + static checks)."}');
  print('====================');

  exit(isTier1 ? 1 : 0);
}

List<String> getChangedFiles() {
  final res = Process.runSync('git', ['diff-index', '--name-only', 'HEAD']);
  if (res.exitCode == 0 && (res.stdout as String).trim().isNotEmpty) {
    return (res.stdout as String).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return [];
}

(bool isTier1, List<String> critical, List<String> standard) classifyRisk(List<String> files) {
  final criticalPatterns = [
    RegExp(r'^(lib|src)/services/.*(tax|audit|calc|engine|ledger|payment|billing|auth)', caseSensitive: false),
    RegExp(r'^(lib|src)/models/', caseSensitive: false),
    RegExp(r'^(lib|src|db)/data/.*(database|migration|repository)', caseSensitive: false),
    RegExp(r'^(tool|scripts)/ede/', caseSensitive: false),
  ];

  final critical = <String>[];
  final standard = <String>[];

  for (final f in files) {
    final norm = f.replaceAll(r'\', '/');
    if (criticalPatterns.any((p) => p.hasMatch(norm))) {
      critical.add(f);
    } else {
      standard.add(f);
    }
  }

  return (critical.isNotEmpty, critical, standard);
}
