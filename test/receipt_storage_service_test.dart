import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/storage/receipt_storage_service.dart';

void main() {
  group('ReceiptStorageService Direct Unit Tests', () {
    test('uploadBinary performs POST to Supabase Storage endpoint with upsert header', () async {
      String? capturedUrl;
      String? capturedApiKey;
      String? capturedAuth;
      String? capturedContentType;
      String? capturedUpsert;
      List<int>? capturedBytes;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        capturedApiKey = request.headers['apikey'];
        capturedAuth = request.headers['Authorization'];
        capturedContentType = request.headers['Content-Type'];
        capturedUpsert = request.headers['x-upsert'];
        capturedBytes = request.bodyBytes;
        return http.Response('{"Key":"receipts/user-1/sample.webp"}', 200);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        bucket: 'receipts',
        httpClient: mockClient,
      );

      final result = await service.uploadBinary(
        bytes: utf8.encode('TEST_WEBP_BYTES'),
        remotePath: 'user-1/sample.webp',
        userToken: 'user_jwt_token',
      );

      expect(result, equals('user-1/sample.webp'));
      expect(capturedUrl, equals('https://test.supabase.co/storage/v1/object/receipts/user-1/sample.webp'));
      expect(capturedApiKey, equals('test_anon'));
      expect(capturedAuth, equals('Bearer user_jwt_token'));
      expect(capturedContentType, equals('image/webp'));
      expect(capturedUpsert, equals('true'));
      expect(capturedBytes, equals(utf8.encode('TEST_WEBP_BYTES')));
    });

    test('uploadExpenseReceipt reads file and uploads to {userId}/{expenseId}.webp', () async {
      final tempDir = Directory.systemTemp.createTempSync('exp_test_');
      final tempFile = File('${tempDir.path}/test_exp.webp')
        ..writeAsBytesSync(utf8.encode('IMAGE_DATA'));

      String? uploadedUrl;

      final mockClient = MockClient((request) async {
        uploadedUrl = request.url.toString();
        return http.Response('{"Key":"receipts/taxpayer-99/exp-101.webp"}', 200);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final path = await service.uploadExpenseReceipt(
        file: tempFile,
        userId: 'taxpayer-99',
        expenseId: 'exp-101',
      );

      expect(path, equals('taxpayer-99/exp-101.webp'));
      expect(uploadedUrl, contains('taxpayer-99/exp-101.webp'));

      tempDir.deleteSync(recursive: true);
    });

    test('uploadOdometerPhoto handles Day 1 start and Day 84 finish naming conventions', () async {
      final tempDir = Directory.systemTemp.createTempSync('odo_test_');
      final startFile = File('${tempDir.path}/start.webp')..writeAsBytesSync([1, 2, 3]);
      final finishFile = File('${tempDir.path}/finish.webp')..writeAsBytesSync([4, 5, 6]);

      final uploadedPaths = <String>[];

      final mockClient = MockClient((request) async {
        uploadedPaths.add(request.url.path);
        return http.Response('{"Key":"ok"}', 200);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final startRemote = await service.uploadOdometerPhoto(
        file: startFile,
        userId: 'u1',
        vehicleId: 'v1',
        isStart: true,
      );
      final finishRemote = await service.uploadOdometerPhoto(
        file: finishFile,
        userId: 'u1',
        vehicleId: 'v1',
        isStart: false,
      );

      expect(startRemote, equals('u1/odometer_v1_start.webp'));
      expect(finishRemote, equals('u1/odometer_v1_finish.webp'));
      expect(uploadedPaths.any((p) => p.contains('odometer_v1_start.webp')), isTrue);
      expect(uploadedPaths.any((p) => p.contains('odometer_v1_finish.webp')), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('downloadBinary falls back to public endpoint if authenticated endpoint fails', () async {
      int authCalls = 0;
      int publicCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/authenticated/')) {
          authCalls++;
          return http.Response('Not Found', 404);
        } else if (request.url.path.contains('/public/')) {
          publicCalls++;
          return http.Response.bytes(utf8.encode('PUBLIC_IMAGE_DATA'), 200);
        }
        return http.Response('Error', 500);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final bytes = await service.downloadBinary(remotePath: 'u1/test.webp');
      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), equals('PUBLIC_IMAGE_DATA'));
      expect(authCalls, equals(1));
      expect(publicCalls, equals(1));
    });

    test('downloadAndCacheReceipt writes downloaded bytes to target local file', () async {
      final tempDir = Directory.systemTemp.createTempSync('cache_test_');
      final targetFile = '${tempDir.path}/cached_receipt.webp';

      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode('CACHED_BYTES_123'), 200);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final cached = await service.downloadAndCacheReceipt(
        remotePath: 'u1/exp1.webp',
        targetLocalPath: targetFile,
      );

      expect(cached, isNotNull);
      expect(cached!.existsSync(), isTrue);
      expect(cached.readAsStringSync(), equals('CACHED_BYTES_123'));

      tempDir.deleteSync(recursive: true);
    });

    test('uploadExpenseReceiptWithHash computes SHA-256 and uploads receipt', () async {
      final tempDir = Directory.systemTemp.createTempSync('receipt_hash_upload_');
      final localFile = File('${tempDir.path}/test_upload.webp');
      const content = 'IMMUTABLE_RECEIPT_BYTES_FOR_ATO_TR9711';
      localFile.writeAsStringSync(content);
      final expectedSha = ReceiptStorageService.computeSha256(utf8.encode(content));

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/object/receipts/user-123/exp-999.webp')) {
          return http.Response('', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final result = await service.uploadExpenseReceiptWithHash(
        file: localFile,
        userId: 'user-123',
        expenseId: 'exp-999',
      );

      expect(result.remotePath, equals('user-123/exp-999.webp'));
      expect(result.sha256Hash, equals(expectedSha));

      tempDir.deleteSync(recursive: true);
    });

    test('downloadAndCacheReceipt with expectedSha256 validates hash and rejects corrupted payload', () async {
      final tempDir = Directory.systemTemp.createTempSync('tamper_test_');
      final targetFile = '${tempDir.path}/valid.webp';
      const validContent = 'LEGIT_RECEIPT_BINARY_DATA';
      final validHash = ReceiptStorageService.computeSha256(utf8.encode(validContent));

      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode('TAMPERED_OR_CORRUPTED_BYTES'), 200);
      });

      final service = ReceiptStorageService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon',
        httpClient: mockClient,
      );

      final cached = await service.downloadAndCacheReceipt(
        remotePath: 'u1/exp_tampered.webp',
        targetLocalPath: targetFile,
        expectedSha256: validHash,
      );

      expect(cached, isNull, reason: 'Corrupted payload must be rejected when SHA-256 does not match');
      expect(File(targetFile).existsSync(), isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('getCachedReceiptFile uses SHA-256 filename for offline resilience', () {
      final cacheDir = Directory('/dummy/cache');
      final hashFile = ReceiptStorageService.getCachedReceiptFile(
        cacheDirectory: cacheDir,
        sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        fallbackId: 'exp-123',
      );
      expect(hashFile.path, equals('/dummy/cache/e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.webp'));

      final fallbackFile = ReceiptStorageService.getCachedReceiptFile(
        cacheDirectory: cacheDir,
        sha256Hash: null,
        fallbackId: 'exp-123',
      );
      expect(fallbackFile.path, equals('/dummy/cache/exp-123.webp'));
    });

    test('getPublicReceiptUrl returns compliant Supabase public URL', () {
      final service = ReceiptStorageService(
        supabaseUrl: 'https://abc.supabase.co',
        bucket: 'receipts',
      );
      final url = service.getPublicReceiptUrl(
        vehicleId: 'veh_hilux_01',
        expenseId: 'exp_fuel_99',
      );
      expect(url, equals('https://abc.supabase.co/storage/v1/object/public/receipts/veh_hilux_01/exp_fuel_99.webp'));
    });
  });
}
