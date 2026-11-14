import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

/// Supabase Storage Service for Receipt & Odometer Photo Binaries
///
/// Responsibilities:
/// 1. Uploads compressed WebP receipt images to bucket 'receipts' under '{userId}/{expenseId}.webp'
/// 2. Uploads start/end odometer inspection photos under '{userId}/odometer_{vehicleId}_{marker}.webp'
/// 3. Computes SHA-256 hash for cryptographic audit immutability (ATO TR 97/11)
/// 4. Downloads remote receipt binaries for cloud restore & local cache hydration
/// 5. Validates cryptographic integrity against expected SHA-256 hashes
/// 6. Generates high-resolution cloud receipt public URLs for external audit handoffs
/// 7. Provides deterministic testing capability via injected http.Client
class ReceiptStorageService {
  final String supabaseUrl;
  final String anonKey;
  final String bucket;
  final http.Client _httpClient;

  ReceiptStorageService({
    String? supabaseUrl,
    String? anonKey,
    String? bucket,
    http.Client? httpClient,
  })  : supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        bucket = bucket ?? AppConstants.receiptStorageBucket,
        _httpClient = httpClient ?? http.Client();

  Map<String, String> _buildHeaders(String? userToken, {String contentType = 'image/webp'}) => {
        'apikey': anonKey,
        'Authorization': 'Bearer ${userToken ?? anonKey}',
        'Content-Type': contentType,
        'x-upsert': 'true',
      };

  /// Constructs the direct, secure public Supabase Storage URL for an expense receipt:
  /// `${supabaseUrl}/storage/v1/object/public/${bucket}/${vehicleId}/${expenseId}.webp`
  String getPublicReceiptUrl({
    required String vehicleId,
    required String expenseId,
  }) {
    return '$supabaseUrl/storage/v1/object/public/$bucket/$vehicleId/$expenseId.webp';
  }

  /// Derives local cache file path based on receipt SHA-256 hash or expense ID:
  /// `${cacheDirectory.path}/${hashOrId}.webp`
  static File getCachedReceiptFile({
    required Directory cacheDirectory,
    String? sha256Hash,
    required String fallbackId,
  }) {
    final fileName = (sha256Hash != null && sha256Hash.trim().isNotEmpty)
        ? '$sha256Hash.webp'
        : '$fallbackId.webp';
    return File('${cacheDirectory.path}/$fileName');
  }

  /// Computes SHA-256 hash hex string of byte list
  static String computeSha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Verifies byte integrity against expected SHA-256 hash
  static bool verifyIntegrity(List<int> bytes, String expectedSha256) {
    if (bytes.isEmpty || expectedSha256.trim().isEmpty) return false;
    final actualHash = computeSha256(bytes);
    return actualHash.toLowerCase() == expectedSha256.trim().toLowerCase();
  }

  /// Uploads raw binary bytes to the Supabase Storage bucket.
  /// Returns the relative cloud storage path upon success, or null on failure.
  Future<String?> uploadBinary({
    required List<int> bytes,
    required String remotePath,
    String? userToken,
    String contentType = 'image/webp',
  }) async {
    try {
      final cleanPath = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
      final uri = Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$cleanPath');
      final headers = _buildHeaders(userToken, contentType: contentType);

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: bytes,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return cleanPath;
      } else {
        debugPrint(
            '[ReceiptStorageService] Binary upload failed (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('[ReceiptStorageService] Error uploading binary to storage: $e\n$stack');
      return null;
    }
  }

  /// Uploads a local receipt file to Supabase Storage: '{userId}/{expenseId}.webp'
  /// Returns a record with remote storage path and verified SHA-256 hash.
  Future<({String? remotePath, String? sha256Hash})> uploadExpenseReceiptWithHash({
    required File file,
    required String userId,
    required String expenseId,
    String? userToken,
  }) async {
    if (!await file.exists()) {
      debugPrint('[ReceiptStorageService] Local file does not exist: ${file.path}');
      return (remotePath: null, sha256Hash: null);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      debugPrint('[ReceiptStorageService] Local receipt file is empty: ${file.path}');
      return (remotePath: null, sha256Hash: null);
    }
    final hash = computeSha256(bytes);
    final remotePath = '$userId/$expenseId.webp';
    final uploadedPath = await uploadBinary(
      bytes: bytes,
      remotePath: remotePath,
      userToken: userToken,
      contentType: 'image/webp',
    );
    return (remotePath: uploadedPath, sha256Hash: uploadedPath != null ? hash : null);
  }

  /// Uploads a local receipt file to Supabase Storage: '{userId}/{expenseId}.webp'
  Future<String?> uploadExpenseReceipt({
    required File file,
    required String userId,
    required String expenseId,
    String? userToken,
  }) async {
    final result = await uploadExpenseReceiptWithHash(
      file: file,
      userId: userId,
      expenseId: expenseId,
      userToken: userToken,
    );
    return result.remotePath;
  }

  /// Uploads a statutory odometer photo: '{userId}/odometer_{vehicleId}_{marker}.webp'
  Future<String?> uploadOdometerPhoto({
    required File file,
    required String userId,
    required String vehicleId,
    required bool isStart,
    String? userToken,
  }) async {
    if (!await file.exists()) {
      debugPrint('[ReceiptStorageService] Local file does not exist: ${file.path}');
      return null;
    }
    final bytes = await file.readAsBytes();
    final marker = isStart ? 'start' : 'finish';
    final remotePath = '$userId/odometer_${vehicleId}_$marker.webp';
    return uploadBinary(
      bytes: bytes,
      remotePath: remotePath,
      userToken: userToken,
      contentType: 'image/webp',
    );
  }

  /// Downloads binary bytes of a stored object from Supabase Storage
  Future<Uint8List?> downloadBinary({
    required String remotePath,
    String? userToken,
  }) async {
    try {
      final cleanPath = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
      // Try authenticated endpoint first
      final authUri = Uri.parse('$supabaseUrl/storage/v1/object/authenticated/$bucket/$cleanPath');
      final headers = {
        'apikey': anonKey,
        'Authorization': 'Bearer ${userToken ?? anonKey}',
      };

      var response = await _httpClient.get(authUri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Fallback to public endpoint
        final publicUri = Uri.parse('$supabaseUrl/storage/v1/object/public/$bucket/$cleanPath');
        response = await _httpClient.get(publicUri, headers: headers);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      } else {
        debugPrint(
            '[ReceiptStorageService] Binary download failed (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('[ReceiptStorageService] Error downloading binary from storage: $e\n$stack');
      return null;
    }
  }

  /// Downloads remote receipt and writes it directly to target local cache file.
  /// If [expectedSha256] is provided, validates cryptographic immutability and throws or rejects
  /// if corrupted or tampered (ATO TR 97/11).
  Future<File?> downloadAndCacheReceipt({
    required String remotePath,
    required String targetLocalPath,
    String? userToken,
    String? expectedSha256,
  }) async {
    final bytes = await downloadBinary(remotePath: remotePath, userToken: userToken);
    if (bytes == null || bytes.isEmpty) return null;

    if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
      final isValid = verifyIntegrity(bytes, expectedSha256);
      if (!isValid) {
        debugPrint(
            '[ReceiptStorageService] Cryptographic integrity verification FAILED for $remotePath (expected $expectedSha256)');
        return null;
      }
    }

    final targetFile = File(targetLocalPath);
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(bytes);
    return targetFile;
  }
}
