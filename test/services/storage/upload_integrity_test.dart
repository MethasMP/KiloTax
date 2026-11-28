import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiloclaim/data/models/audit_evidence.dart';
import 'package:kiloclaim/services/evidence/evidence_vault_service.dart';
import 'package:kiloclaim/services/storage/receipt_storage_service.dart';

void main() {
  group('Task D2: SHA-256 Upload Integrity Verification (INV-A01 & INV-A04)', () {
    const testUserId = 'usr_tradie_12345';
    final sampleBytes = utf8.encode('BUNNINGS TAX INVOICE - \$150.00 AUD - 2026-11-20');
    final expectedSha256 = ReceiptStorageService.computeSha256(sampleBytes);
    final fixedDate = DateTime(2026, 11, 20, 10, 30);

    test('INV-A04: Canonical storage path follows receipts/{auth.uid()}/{yyyy}/{mm}/{sha256}.{ext}', () {
      final canonicalPath = ReceiptStorageService.buildCanonicalStoragePath(
        userId: testUserId,
        sha256Hash: expectedSha256,
        date: fixedDate,
        extension: 'webp',
      );

      expect(
        canonicalPath,
        equals('receipts/$testUserId/2026/11/$expectedSha256.webp'),
      );

      final bucketRelativePath = ReceiptStorageService.buildBucketPath(
        userId: testUserId,
        sha256Hash: expectedSha256,
        date: fixedDate,
        extension: 'webp',
      );
      expect(
        bucketRelativePath,
        equals('$testUserId/2026/11/$expectedSha256.webp'),
      );
    });

    test('Step 1: Mock upload returning mismatched ETag marks matchesClientHash == false and aborts', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'Key': 'receipts/$testUserId/2026/11/$expectedSha256.webp'}),
            200,
            headers: {
              'etag': '"mismatched_corrupted_hash_99999999999999999999999999999999"',
              'content-type': 'application/json',
            },
          );
        }
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {
              'etag': '"mismatched_corrupted_hash_99999999999999999999999999999999"',
              'x-sha256': 'mismatched_corrupted_hash_99999999999999999999999999999999',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final storageService = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
        httpClient: mockClient,
      );

      final uploadResult = await storageService.uploadWithIntegrityVerification(
        bytes: sampleBytes,
        userId: testUserId,
        date: fixedDate,
      );

      expect(uploadResult.matchesClientHash, isFalse);
      expect(uploadResult.confirmedSha256, isNot(equals(expectedSha256)));
      expect(uploadResult.storagePath, isNull);
    });

    test('Step 2: Matching hash results in matchesClientHash == true and audit_evidence row written', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'Key': 'receipts/$testUserId/2026/11/$expectedSha256.webp'}),
            200,
            headers: {
              'etag': '"$expectedSha256"',
              'content-type': 'application/json',
            },
          );
        }
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {
              'etag': '"$expectedSha256"',
              'x-sha256': expectedSha256,
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final storageService = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
        httpClient: mockClient,
      );

      final uploadResult = await storageService.uploadWithIntegrityVerification(
        bytes: sampleBytes,
        userId: testUserId,
        date: fixedDate,
      );

      expect(uploadResult.matchesClientHash, isTrue);
      expect(uploadResult.confirmedSha256, equals(expectedSha256));
      expect(uploadResult.storagePath, equals('receipts/$testUserId/2026/11/$expectedSha256.webp'));

      // Test writing audit_evidence row with matching hash
      final vaultService = EvidenceVaultService(storageService: storageService);
      final (evidence, error) = await vaultService.registerVerifiedAuditEvidence(
        bytes: sampleBytes,
        evidenceType: EvidenceType.expenseReceipt,
        userId: testUserId,
        vehicleId: 'veh_hilux_01',
        entityId: 'exp_bunnings_123',
        uploadResult: uploadResult,
      );

      expect(error, isNull);
      expect(evidence, isNotNull);
      expect(evidence!.imageSha256, equals(expectedSha256));
      expect(evidence.storagePath, equals('receipts/$testUserId/2026/11/$expectedSha256.webp'));
      expect(evidence.evidenceType, equals(EvidenceType.expenseReceipt));
    });

    test('INV-A01: Throws HashMismatchException when throwOnMismatch is requested', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'Key': 'corrupted'}),
          200,
          headers: {'etag': '"tampered_sha256_value"'},
        );
      });

      final storageService = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
        httpClient: mockClient,
      );

      expect(
        () => storageService.uploadWithIntegrityVerification(
          bytes: sampleBytes,
          userId: testUserId,
          date: fixedDate,
          throwOnMismatch: true,
        ),
        throwsA(isA<HashMismatchException>()),
      );
    });

    test('EvidenceVaultService rejects creating AuditEvidence when uploadResult failed integrity check', () async {
      final failedResult = UploadResult(
        storagePath: null,
        confirmedSha256: 'corrupted',
        matchesClientHash: false,
        errorMessage: 'Hash mismatch detected',
      );

      final vaultService = EvidenceVaultService();
      final (evidence, error) = await vaultService.registerVerifiedAuditEvidence(
        bytes: sampleBytes,
        evidenceType: EvidenceType.expenseReceipt,
        userId: testUserId,
        vehicleId: 'veh_hilux_01',
        entityId: 'exp_bunnings_123',
        uploadResult: failedResult,
      );

      expect(evidence, isNull);
      expect(error, contains('integrity verification failed'));
    });
  });
}
