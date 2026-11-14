import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PR-09: Append-Only Audit Evidence Migration Verification', () {
    test('Migration file exists and enforces append-only RLS policies', () {
      final migrationFile = File(
        'supabase/migrations/20261008_append_only_audit_evidence.sql',
      );
      expect(migrationFile.existsSync(), isTrue);

      final content = migrationFile.readAsStringSync();
      expect(content.contains('audit_evidence'), isTrue);
      expect(content.contains('FOR SELECT'), isTrue);
      expect(content.contains('FOR INSERT'), isTrue);
      // Confirms UPDATE and DELETE policies are dropped / not granted to authenticated
      expect(content.contains('DROP POLICY IF EXISTS "Users can update own audit evidence"'), isTrue);
      expect(content.contains('DROP POLICY IF EXISTS "Users can delete own audit evidence"'), isTrue);
      expect(content.contains('auth.uid() = user_id'), isTrue);
    });
  });
}
