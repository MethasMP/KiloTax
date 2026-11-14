import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PR-11: Receipts Storage Bucket & RLS Migration Verification', () {
    test('Migration file creates receipts bucket with strict auth.uid() folder RLS', () {
      final migrationFile = File(
        'supabase/migrations/20261008_storage_receipts_rls.sql',
      );
      expect(migrationFile.existsSync(), isTrue);

      final content = migrationFile.readAsStringSync();
      expect(content.contains("INSERT INTO storage.buckets"), isTrue);
      expect(content.contains("'receipts'"), isTrue);
      expect(content.contains("storage.foldername(name)"), isTrue);
      expect(content.contains("auth.uid()"), isTrue);
      expect(content.contains("FOR SELECT"), isTrue);
      expect(content.contains("FOR INSERT"), isTrue);
      expect(content.contains("FOR UPDATE"), isTrue);
      expect(content.contains("FOR DELETE"), isTrue);
    });
  });
}
