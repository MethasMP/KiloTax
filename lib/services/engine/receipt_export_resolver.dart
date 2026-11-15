import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../data/models/vehicle_expense.dart';
import '../sync/sync_engine_service.dart';
import '../tax/ato_tax_period_engine.dart';

class AccountantExportCancelled implements Exception {}

class ReceiptExportPage {
  final Uint8List? bytes;
  final String? savedSha256;
  final String source;
  final String? issue;

  const ReceiptExportPage(
      {this.bytes, this.savedSha256, this.source = 'unavailable', this.issue});
}

class ReceiptExportDocument {
  final List<ReceiptExportPage> pages;
  final String? issue;

  const ReceiptExportDocument(this.pages, {this.issue});
}

class ReceiptExportResolver {
  final String? ownerId;
  final String? accessToken;
  final String supabaseUrl;
  final String anonKey;
  final String bucket;
  final bool Function()? isCurrent;
  final Duration requestTimeout;
  final Duration recoveryBudget;
  final int maxPageBytes;
  final Stopwatch _clock = Stopwatch()..start();
  http.Client? _client;

  ReceiptExportResolver(
      {this.ownerId,
      this.accessToken,
      String? supabaseUrl,
      String? anonKey,
      String? bucket,
      http.Client? client,
      this.isCurrent,
      this.requestTimeout = const Duration(seconds: 8),
      this.recoveryBudget = const Duration(seconds: 30),
      this.maxPageBytes = 10 * 1024 * 1024})
      : supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        bucket = bucket ?? AppConstants.receiptStorageBucket,
        _client = client;

  void close() => _client?.close();
  void _checkSession() {
    if (isCurrent?.call() == false) throw AccountantExportCancelled();
  }

  bool get _canRecover =>
      ownerId?.isNotEmpty == true &&
      accessToken?.isNotEmpty == true &&
      _clock.elapsed < recoveryBudget;

  String? _ownedPath(Object? value) {
    if (value is! String || ownerId == null || !value.startsWith('$ownerId/')) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z0-9._/-]+$').hasMatch(value) ||
        value
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    return value;
  }

  static String? _hashAt(Object? hashes, int index, [String? path]) {
    final value = hashes is List && index < hashes.length
        ? hashes[index]
        : hashes is Map
            ? hashes[path]
            : null;
    return value is String ? value : null;
  }

  Future<Uint8List?> _local(String path) async {
    if (!path.startsWith('/') && !path.startsWith('file:')) return null;
    try {
      final file =
          path.startsWith('file:') ? File.fromUri(Uri.parse(path)) : File(path);
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<http.Response?> _get(Uri uri) async {
    _checkSession();
    if (!_canRecover) return null;
    final remaining = recoveryBudget - _clock.elapsed;
    final timeout = remaining < requestTimeout ? remaining : requestTimeout;
    try {
      final response = await (_client ??= http.Client()).get(uri, headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $accessToken',
      }).timeout(timeout);
      _checkSession();
      return response;
    } on AccountantExportCancelled {
      rethrow;
    } catch (_) {
      _checkSession();
      return null;
    }
  }

  Future<Map<String, dynamic>?> _cloudRecord(VehicleExpense expense) async {
    final id = SyncEngineService.cloudId(expense.id, ownerId);
    final vehicle = SyncEngineService.cloudId(expense.vehicleId, ownerId);
    final fy = const AtoTaxPeriodEngine().forDate(expense.date);
    final response = await _get(
        Uri.parse('$supabaseUrl/rest/v1/expenses').replace(queryParameters: {
      'select':
          'id,local_id,user_id,vehicle_id,date,deleted_at,receipt_storage_path,receipt_audit,sha256_hash',
      'id': 'eq.$id',
      'user_id': 'eq.$ownerId',
      'vehicle_id': 'eq.$vehicle',
      'and': '(date.gte.${fy.startYear}-07-01,date.lt.${fy.endYear}-07-01)',
      'deleted_at': 'is.null',
      'limit': '1',
    }));
    if (response == null || response.statusCode != 200) return null;
    try {
      final rows = jsonDecode(response.body);
      if (rows is! List || rows.length != 1 || rows.single is! Map) return null;
      final row = Map<String, dynamic>.from(rows.single as Map);
      final date = DateTime.tryParse(row['date'] as String? ?? '');
      if (row['id'] != id ||
          row['user_id'] != ownerId ||
          row['vehicle_id'] != vehicle ||
          row['deleted_at'] != null ||
          date == null ||
          const AtoTaxPeriodEngine().forDate(date).startYear != fy.startYear ||
          (row['local_id'] != null && row['local_id'] != expense.id)) {
        return null;
      }
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<ReceiptExportPage> _download(
      String path, String? savedHash, String? transportHash) async {
    _checkSession();
    final owned = _ownedPath(path);
    if (owned == null) {
      return ReceiptExportPage(
          savedSha256: savedHash,
          issue: 'Saved receipt is not accessible within this account.');
    }
    final response = await _get(Uri.parse(
        '$supabaseUrl/storage/v1/object/authenticated/$bucket/$owned'));
    if (response == null ||
        response.statusCode != 200 ||
        response.bodyBytes.isEmpty ||
        response.bodyBytes.length > maxPageBytes) {
      return ReceiptExportPage(
          savedSha256: savedHash,
          issue:
              'Saved receipt could not be retrieved. Try again when connected.');
    }
    if (transportHash != null &&
        sha256.convert(response.bodyBytes).toString() != transportHash) {
      return ReceiptExportPage(
          savedSha256: savedHash,
          issue: 'Saved cloud receipt did not match its stored fingerprint.');
    }
    return ReceiptExportPage(
        bytes: response.bodyBytes, savedSha256: savedHash, source: 'cloud');
  }

  Future<ReceiptExportDocument> resolve(VehicleExpense expense) async {
    _checkSession();
    final audit = expense.receiptAudit;
    final fields = audit?.currentFields ?? const <String, dynamic>{};
    final recorded = fields['pagePaths'];
    final paths = recorded is List && recorded.isNotEmpty
        ? recorded.map((value) => value is String ? value : '').toList()
        : [if (expense.receiptPath?.isNotEmpty == true) expense.receiptPath!];
    String? savedHash(int index) =>
        _hashAt(fields['pageHashes'], index,
            index < paths.length ? paths[index] : null) ??
        (index == 0
            ? audit?.extractionImageSha256 ??
                audit?.imageSha256 ??
                expense.sha256Hash
            : null);
    final pages = <ReceiptExportPage>[];
    for (var index = 0; index < paths.length; index++) {
      final bytes = await _local(paths[index]);
      _checkSession();
      pages.add(ReceiptExportPage(
          bytes: bytes,
          savedSha256: savedHash(index),
          source: bytes == null ? 'unavailable' : 'local'));
    }
    if (pages.isNotEmpty && pages.every((page) => page.bytes != null)) {
      return ReceiptExportDocument(pages);
    }
    if (!_canRecover) return ReceiptExportDocument(pages);

    // Explicit restored object references already belong to this record; never guess an object name.
    if (paths.isNotEmpty && paths.every((path) => _ownedPath(path) != null)) {
      for (var index = 0; index < paths.length; index++) {
        pages[index] = await _download(paths[index], savedHash(index),
            _hashAt(fields['transportPageHashes'], index) ?? savedHash(index));
      }
      return ReceiptExportDocument(pages);
    }
    final cloud = await _cloudRecord(expense);
    _checkSession();
    if (cloud == null) {
      return ReceiptExportDocument(pages,
          issue: 'A saved cloud copy could not be retrieved for this receipt.');
    }
    final cloudAudit = cloud['receipt_audit'] is Map
        ? Map<String, dynamic>.from(cloud['receipt_audit'] as Map)
        : null;
    if (audit != null &&
        (cloudAudit == null ||
            cloudAudit['revision'] != audit.revision ||
            (audit.imageSha256 != null &&
                cloudAudit['imageSha256'] != audit.imageSha256))) {
      return ReceiptExportDocument(pages,
          issue:
              'Saved cloud copy is a different receipt version; missing pages remain unavailable.');
    }
    final cloudFields = cloudAudit?['currentFields'] is Map
        ? Map<String, dynamic>.from(cloudAudit!['currentFields'] as Map)
        : const <String, dynamic>{};
    final cloudPaths = cloudFields['pagePaths'];
    final remote = cloudPaths is List && cloudPaths.isNotEmpty
        ? cloudPaths.map((value) => value is String ? value : '').toList()
        : [
            if (cloud['receipt_storage_path'] is String)
              cloud['receipt_storage_path'] as String
          ];
    if (paths.isNotEmpty && remote.length != paths.length) {
      return ReceiptExportDocument(pages,
          issue:
              'Saved cloud receipt has a different page set; missing pages remain unavailable.');
    }
    if (remote.isEmpty) return ReceiptExportDocument(pages);
    final cloudOriginalHash = cloudAudit == null
        ? null
        : cloudAudit['extractionImageSha256'] as String?;
    final cloudSavedHash = cloud['sha256_hash'] as String?;
    if (pages.isEmpty) {
      pages.addAll(List.generate(
          remote.length,
          (index) => ReceiptExportPage(
              savedSha256: _hashAt(
                      cloudFields['pageHashes'], index, remote[index]) ??
                  (index == 0 ? cloudOriginalHash ?? cloudSavedHash : null))));
    }
    for (var index = 0; index < remote.length; index++) {
      if (pages[index].bytes != null) continue;
      pages[index] = await _download(
          remote[index],
          pages[index].savedSha256,
          _hashAt(cloudFields['transportPageHashes'], index) ??
              (index == 0 ? cloudSavedHash : null));
    }
    return ReceiptExportDocument(pages);
  }
}
