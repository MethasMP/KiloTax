import 'dart:io';

/// Prepares an isolated audit sandbox payload (<4k tokens)
/// Extracts target file content and git diff for adversarial auditor models.
void main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart run tool/ede/prepare_audit_payload.dart <target-file-path> [role]');
    exit(1);
  }

  final targetPath = args[0];
  final role = args.length > 1 ? args[1] : 'tax-lawyer';
  final targetFile = File(targetPath);

  if (!targetFile.existsSync()) {
    stderr.writeln('Target file not found: $targetPath');
    exit(1);
  }

  // Get git diff for the target file if modified
  String diffOutput = '';
  try {
    final diffRes = await Process.run('git', ['diff', targetPath]);
    diffOutput = diffRes.stdout.toString().trim();
  } catch (_) {}

  final targetContent = await targetFile.readAsString();

  final payloadDir = Directory('.ede/payloads');
  if (!payloadDir.existsSync()) {
    payloadDir.createSync(recursive: true);
  }

  final payloadPath = '.ede/payloads/audit_${role}_${targetFile.uri.pathSegments.last}.md';
  final buffer = StringBuffer();

  buffer.writeln('# EDE Isolated Audit Payload');
  buffer.writeln('**Role:** $role');
  buffer.writeln('**Target File:** $targetPath');
  buffer.writeln('**Timestamp:** ${DateTime.now().toUtc().toIso8601String()}');
  buffer.writeln('');
  buffer.writeln('## Adversarial Objective');
  buffer.writeln('Falsify this file against its architectural invariants. Generate an executable counterexample test.');
  buffer.writeln('');
  if (diffOutput.isNotEmpty) {
    buffer.writeln('## Proposed Git Diff');
    buffer.writeln('```diff');
    buffer.writeln(diffOutput);
    buffer.writeln('```');
    buffer.writeln('');
  }
  buffer.writeln('## File Content');
  buffer.writeln('```dart');
  buffer.writeln(targetContent);
  buffer.writeln('```');

  await File(payloadPath).writeAsString(buffer.toString());
  stdout.writeln('Isolated payload created: $payloadPath');
  stdout.writeln('Tokens: ~${(buffer.length / 4).round()} tokens (Safe for isolated subagent sandbox)');
}
