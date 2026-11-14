import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehicle_expense.dart';
import 'receipt_database.dart';
export 'receipt_database.dart';

const _receiptNotSet = Object();

enum ReceiptDraftState { queued, failed, needsReview, ready, recorded }

class ReceiptDraft {
  final VehicleExpense expense;
  final bool processed;
  final List<String> issues;
  final String documentId;
  final int revision;
  final ReceiptDraftState state;
  final DateTime? purchaseDate;
  final DateTime? capturedAt;
  final String? sourcePath;
  final String? normalizedPath;
  final List<String> pagePaths;
  final String? groupId;
  final String? error;
  final List<Map<String, dynamic>> groupedDocuments;
  final bool extractionReviewed;
  final bool duplicateReviewed;
  final bool groupingReviewed;
  ReceiptDraft(this.expense,
      {this.processed = false,
      this.issues = const [],
      String? documentId,
      this.revision = 0,
      ReceiptDraftState? state,
      this.purchaseDate,
      this.capturedAt,
      this.sourcePath,
      this.normalizedPath,
      List<String>? pagePaths,
      this.groupId,
      this.error,
      this.groupedDocuments = const [],
      this.extractionReviewed = false,
      this.duplicateReviewed = false,
      this.groupingReviewed = false})
      : pagePaths = pagePaths ??
            (expense.receiptPath == null ? const [] : [expense.receiptPath!]),
        documentId = documentId ?? expense.id,
        state = state ??
            (processed
                ? ReceiptDraftState.needsReview
                : ReceiptDraftState.queued);
  ReceiptDraft copyWith(
          {VehicleExpense? expense,
          bool? processed,
          List<String>? issues,
          int? revision,
          ReceiptDraftState? state,
          Object? purchaseDate = _receiptNotSet,
          String? groupId,
          List<String>? pagePaths,
          String? error,
          bool? extractionReviewed,
          bool? duplicateReviewed,
          bool? groupingReviewed}) =>
      ReceiptDraft(expense ?? this.expense,
          processed: processed ?? this.processed,
          issues: issues ?? this.issues,
          documentId: documentId,
          revision: revision ?? this.revision,
          state: state ?? this.state,
          purchaseDate: identical(purchaseDate, _receiptNotSet)
              ? this.purchaseDate
              : purchaseDate as DateTime?,
          capturedAt: capturedAt,
          sourcePath: sourcePath,
          normalizedPath: normalizedPath,
          pagePaths: pagePaths ?? this.pagePaths,
          groupId: groupId ?? this.groupId,
          error: error,
          groupedDocuments: groupedDocuments,
          extractionReviewed: extractionReviewed ?? this.extractionReviewed,
          duplicateReviewed: duplicateReviewed ?? this.duplicateReviewed,
          groupingReviewed: groupingReviewed ?? this.groupingReviewed);
  Map<String, dynamic> toJson() => {
        'expense': expense.toJson(),
        'processed': processed,
        'issues': issues,
        'documentId': documentId,
        'revision': revision,
        'state': state.name,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'capturedAt': capturedAt?.toIso8601String(),
        'sourcePath': sourcePath,
        'normalizedPath': normalizedPath,
        'pagePaths': pagePaths,
        'groupId': groupId,
        'groupedDocuments': groupedDocuments,
        'extractionReviewed': extractionReviewed,
        'duplicateReviewed': duplicateReviewed,
        'groupingReviewed': groupingReviewed,
        'error': error
      };
  factory ReceiptDraft.fromJson(Map<String, dynamic> j) => ReceiptDraft(
      VehicleExpense.fromJson(Map<String, dynamic>.from(j['expense'] as Map)),
      processed: j['processed'] == true,
      issues: List<String>.from(j['issues'] as List? ?? []),
      documentId: j['documentId'] as String?,
      revision: j['revision'] as int? ?? 0,
      state: ReceiptDraftState.values.firstWhere((s) => s.name == j['state'],
          orElse: () => j['processed'] == true
              ? ReceiptDraftState.needsReview
              : ReceiptDraftState.queued),
      purchaseDate: DateTime.tryParse(j['purchaseDate'] as String? ?? ''),
      capturedAt: DateTime.tryParse(j['capturedAt'] as String? ?? ''),
      sourcePath: j['sourcePath'] as String?,
      normalizedPath: j['normalizedPath'] as String?,
      pagePaths: j['pagePaths'] == null
          ? null
          : List<String>.from(j['pagePaths'] as List),
      groupId: j['groupId'] as String?,
      error: j['error'] as String?,
      groupedDocuments: (j['groupedDocuments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      extractionReviewed: j['extractionReviewed'] == true,
      duplicateReviewed: j['duplicateReviewed'] == true,
      groupingReviewed: j['groupingReviewed'] == true);
}

class ReceiptInboxService {
  final SharedPreferences preferences;
  final String scope;
  final Directory directory;
  final ReceiptDatabase? database;
  List<ReceiptDraft>? _cache;
  ReceiptInboxService(this.preferences, this.scope, this.directory,
      {this.database});
  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static Future<ReceiptInboxService> open(
      String account, String vehicle) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/receipt_inbox/${_hash(account)}');
    await dir.create(recursive: true);
    final service = ReceiptInboxService(
        await SharedPreferences.getInstance(), _hash(account), dir,
        database:
            await ReceiptDatabase.open('${root.path}/receipt_inbox.sqlite'));
    await service.initialize();
    // Inspect every known vehicle key for this account; callers may open each vehicle
    // over time, and all migrated documents share the account inbox.
    await service.migrateLegacy(_hash('$account/$vehicle'));
    return service;
  }

  static Future<ReceiptInboxService> openForVehicles(
      String account, Iterable<String> vehicleIds) async {
    final ids = vehicleIds.toList();
    final store = await open(account, ids.firstOrNull ?? '');
    for (final id in ids.skip(1)) {
      await store.migrateLegacy(_hash('$account/$id'));
    }
    // Legacy payloads contain their vehicle ID even when the vehicle was removed.
    // Match the owner-derived key before importing; never adopt another account's list.
    for (final key in store.preferences.getKeys().where(
        (k) => k.startsWith('receipt_inbox_v1_') && !k.endsWith('_migrated'))) {
      final raw = store.preferences.getString(key);
      if (raw == null) continue;
      try {
        final entries = jsonDecode(raw) as List;
        for (final value in entries) {
          final expense = (value as Map)['expense'] as Map;
          final vehicle = expense['vehicleId'] as String;
          final legacy = _hash('$account/$vehicle');
          if (key == 'receipt_inbox_v1_$legacy') {
            await store.migrateLegacy(legacy);
          }
        }
      } on FormatException {
        /* Known corrupt scopes are surfaced by open/migrate above. */
      } on TypeError {
        /* Other preference formats are not receipt migrations. */
      }
    }
    await store.initialize();
    return store;
  }

  String get key => 'receipt_inbox_v1_$scope';
  File get _journal => File('${directory.path}/drafts_$scope.json');
  Future<void> initialize() async {
    _cache = database == null
        ? load()
        : (await database!.load(scope)).map(ReceiptDraft.fromJson).toList();
  }

  List<ReceiptDraft> _decode(String value) => (jsonDecode(value) as List)
      .map((e) => ReceiptDraft.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  List<ReceiptDraft> load() {
    if (_cache != null) return List.unmodifiable(_cache!);
    if (_journal.existsSync()) return _decode(_journal.readAsStringSync());
    final value = preferences.getString(key);
    return value == null ? [] : _decode(value);
  }

  Future<void> save(List<ReceiptDraft> drafts) async {
    final previous = load();
    final old = {for (final d in previous) d.documentId: d};
    final next = <ReceiptDraft>[];
    for (final d in drafts) {
      final p = old[d.documentId];
      if (p != null && d.revision != p.revision) {
        throw ReceiptRevisionConflict(d.documentId);
      }
      next.add(ReceiptDraft(d.expense,
          processed: d.processed,
          issues: d.issues,
          documentId: d.documentId,
          revision: (p?.revision ?? -1) + 1,
          state: d.state,
          purchaseDate: d.purchaseDate,
          capturedAt: d.capturedAt ?? p?.capturedAt,
          sourcePath: d.sourcePath ?? p?.sourcePath,
          normalizedPath: d.normalizedPath ?? p?.normalizedPath,
          pagePaths: d.pagePaths.isEmpty ? p?.pagePaths ?? [] : d.pagePaths,
          groupId: d.groupId ?? p?.groupId,
          error: d.error,
          groupedDocuments: d.groupedDocuments,
          extractionReviewed: d.extractionReviewed,
          duplicateReviewed: d.duplicateReviewed,
          groupingReviewed: d.groupingReviewed));
    }
    if (database != null) {
      await database!.replace(scope, next.map((d) => d.toJson()).toList(),
          {for (final d in previous) d.documentId: d.revision});
    } else {
      await directory.create(recursive: true);
      final temp = File('${_journal.path}.tmp');
      await temp.writeAsString(jsonEncode(next.map((d) => d.toJson()).toList()),
          flush: true);
      await temp.rename(_journal.path);
      // Keep compatibility preference readers, while the atomic journal is authoritative.
      if (!await preferences.setString(
          key, jsonEncode(next.map((d) => d.toJson()).toList()))) {
        throw StateError('Could not save receipt drafts.');
      }
    }
    _cache = next;
  }

  Future<void> migrateLegacy(String legacyScope) async {
    final legacyKey = 'receipt_inbox_v1_$legacyScope';
    if (preferences.getBool('${legacyKey}_migrated') == true) return;
    final raw = preferences.getString(legacyKey);
    if (raw == null) return;
    final migrated = _decode(raw); // malformed data is surfaced and retained.
    final all = load().toList();
    final ids = all.map((d) => d.documentId).toSet();
    all.addAll(migrated.where((d) => ids.add(d.documentId)));
    await save(all);
    if (!await preferences.setBool('${legacyKey}_migrated', true)) {
      throw StateError('Could not mark receipt migration complete.');
    }
  }

  Future<ReceiptDraft> retain(String path, String vehicleId) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Receipt image is empty.');
    final hash = sha256.convert(bytes).toString();
    for (final d in load()) {
      if (d.expense.sha256Hash == hash) return d;
    }
    await directory.create(recursive: true);
    final ext = path.toLowerCase().endsWith('.png')
        ? '.png'
        : path.toLowerCase().endsWith('.webp')
            ? '.webp'
            : '.jpg';
    final file = File('${directory.path}/$hash$ext');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    final id =
        'receipt_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    return ReceiptDraft(
        VehicleExpense(
            id: id,
            vehicleId: vehicleId,
            amount: 0,
            category: ExpenseCategory.otherBusiness,
            date: DateTime.fromMillisecondsSinceEpoch(0),
            receiptPath: file.path,
            sha256Hash: hash),
        capturedAt: DateTime.now(),
        sourcePath: file.path,
        pagePaths: [file.path]);
  }

  Future<void> retry(String id) async => save(load()
      .map((d) => d.documentId == id
          ? d.copyWith(state: ReceiptDraftState.queued, processed: false)
          : d)
      .toList());
  Future<void> stageCommit(VehicleExpense expense) async {
    if (database == null) throw StateError('Commit intents require SQLite.');
    final draft = load().where((d) => d.expense.id == expense.id).firstOrNull;
    await database!.stage(scope, expense.id, expense.toJson(),
        expectedRevision: draft?.revision);
  }

  Future<List<VehicleExpense>> pendingCommits() async => database == null
      ? []
      : (await database!.pending(scope)).map(VehicleExpense.fromJson).toList();
  Future<void> completeCommit(String expenseId) async {
    await database!.complete(scope, expenseId);
    await initialize();
  }

  List<ReceiptDraft> listAll() => load();
  int get accountCount => load().length;
  List<Map<String, dynamic>> exportAccount() =>
      load().map((d) => d.toJson()).toList();
  Future<void> importAccount(List<Map<String, dynamic>> drafts) async {
    final all = {for (final d in load()) d.documentId: d};
    for (final j in drafts) {
      final extraPaths = <String>{};
      void collect(dynamic value) {
        if (value is String && value.startsWith('/')) extraPaths.add(value);
        if (value is List) {
          for (final child in value) {
            collect(child);
          }
        }
        if (value is Map) {
          for (final child in value.values) {
            collect(child);
          }
        }
      }

      collect(j);
      final d = ReceiptDraft.fromJson(j);
      if (!all.containsKey(d.documentId)) all[d.documentId] = d;
    }
    await save(all.values.toList());
  }

  Future<ReceiptDraft> groupDocuments(List<String> ids) async {
    final all = load();
    final selected =
        ids.map((id) => all.firstWhere((d) => d.documentId == id)).toList();
    if (selected.length < 2 ||
        selected.any((d) => d.state == ReceiptDraftState.recorded)) {
      throw StateError('Choose at least two unrecorded documents.');
    }
    final id =
        'receipt_group_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final first = selected.first;
    final grouped = ReceiptDraft(first.expense.copyWith(id: id, amount: 0),
        documentId: id,
        groupId: id,
        state: ReceiptDraftState.queued,
        capturedAt: DateTime.now(),
        sourcePath: first.sourcePath,
        pagePaths: selected.expand((d) => d.pagePaths).toList(),
        groupedDocuments: selected.map((d) => d.toJson()).toList(),
        issues: ['Review combined receipt pages and total']);
    await save([...all.where((d) => !ids.contains(d.documentId)), grouped]);
    return load().firstWhere((d) => d.documentId == id);
  }

  Future<void> splitDocument(String id) async {
    final all = load();
    final group = all.firstWhere((d) => d.documentId == id);
    if (group.groupedDocuments.isEmpty) {
      throw StateError('This document has no original page documents.');
    }
    final restored = group.groupedDocuments.map((j) => ReceiptDraft.fromJson({
          ...j,
          'revision': 0,
          'processed': false,
          'state': 'queued',
          'extractionReviewed': false,
          'duplicateReviewed': false,
          'groupingReviewed': false
        }));
    await save([...all.where((d) => d.documentId != id), ...restored]);
  }

  Future<void> migrateGuestTo(String account) async {
    final destination = await open(account, '');
    final copied = <Map<String, dynamic>>[];
    for (final draft in load()) {
      final j = draft.toJson();
      final paths = <String>{
        ...draft.pagePaths,
        if (draft.sourcePath != null) draft.sourcePath!,
        if (draft.normalizedPath != null) draft.normalizedPath!,
        if (draft.expense.receiptPath != null) draft.expense.receiptPath!
      };
      void collect(Map<String, dynamic> doc) {
        final d = ReceiptDraft.fromJson(doc);
        paths.addAll(d.pagePaths);
        for (final p in [
          d.sourcePath,
          d.normalizedPath,
          d.expense.receiptPath
        ]) {
          if (p != null) paths.add(p);
        }
        for (final child in d.groupedDocuments) {
          collect(child);
        }
      }

      collect(j);
      final remap = <String, String>{};
      for (final path in paths) {
        final source = File(path);
        if (!await source.exists()) {
          throw StateError('Receipt image missing during guest migration.');
        }
        final target =
            '${destination.directory.path}/${_hash(path)}_${path.split('/').last}';
        await source.copy(target);
        remap[path] = target;
      }
      j['pagePaths'] = draft.pagePaths.map((p) => remap[p]!).toList();
      j['sourcePath'] = remap[draft.sourcePath];
      j['normalizedPath'] = remap[draft.normalizedPath];
      (j['expense'] as Map)['receiptPath'] = remap[draft.expense.receiptPath];
      dynamic rewrite(dynamic value) {
        if (value is String) return remap[value] ?? value;
        if (value is List) return value.map(rewrite).toList();
        if (value is Map) return value.map((k, v) => MapEntry(k, rewrite(v)));
        return value;
      }

      copied.add(Map<String, dynamic>.from(rewrite(j) as Map));
    }
    // Destination is durable first. A crash before clearing is safe to retry by ID.
    await destination.importAccount(copied);
    await save([]);
  }

  static Future<void> deleteAccount(String account,
      {Directory? rootDirectory,
      ReceiptDatabase? database,
      Iterable<String> knownVehicleIds = const []}) async {
    final root = rootDirectory ?? await getApplicationDocumentsDirectory();
    final scope = _hash(account);
    final db = database ??
        await ReceiptDatabase.open('${root.path}/receipt_inbox.sqlite');
    final drafts = await db.load(scope);
    final recorded = await db.database
        .query('recorded_documents', where: 'account = ?', whereArgs: [scope]);
    drafts.addAll(recorded.map((r) =>
        Map<String, dynamic>.from(jsonDecode(r['payload'] as String) as Map)));
    final prefs = await SharedPreferences.getInstance();
    final vehicleIds = {
      ...knownVehicleIds,
      ...drafts.map((j) => ReceiptDraft.fromJson(j).expense.vehicleId)
    };
    for (final key in prefs.getKeys().where(
        (k) => k.startsWith('receipt_inbox_v1_') && !k.endsWith('_migrated'))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        for (final value in jsonDecode(raw) as List) {
          final expense = (value as Map)['expense'] as Map;
          final vehicle = expense['vehicleId'] as String;
          if (key == 'receipt_inbox_v1_${_hash('$account/$vehicle')}') {
            vehicleIds.add(vehicle);
          }
        }
      } on FormatException {
        /* Preserve undecodable data for explicit recovery. */
      } on TypeError {/* Ignore non-receipt preference formats. */}
    }
    for (final vehicle in vehicleIds.toList()) {
      final raw =
          prefs.getString('receipt_inbox_v1_${_hash('$account/$vehicle')}');
      if (raw != null) {
        try {
          drafts.addAll((jsonDecode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e as Map)));
        } on FormatException {
          /* Owner-derived directory can still be purged. */
        } on TypeError {/* Malformed owned indexes must not block erasure. */}
      }
    }
    for (final vehicle in vehicleIds) {
      final oldKey = 'receipt_inbox_v1_${_hash('$account/$vehicle')}';
      await prefs.remove(oldKey);
      await prefs.remove('${oldKey}_migrated');
    }
    await prefs.remove('receipt_inbox_v1_$scope');
    final inboxRoot = Directory('${root.path}/receipt_inbox').absolute.path;
    for (final j in drafts) {
      final extraPaths = <String>{};
      void collect(dynamic value) {
        if (value is String && value.startsWith('/')) extraPaths.add(value);
        if (value is List) {
          for (final child in value) {
            collect(child);
          }
        }
        if (value is Map) {
          for (final child in value.values) {
            collect(child);
          }
        }
      }

      collect(j);
      final d = ReceiptDraft.fromJson(j);
      for (final p in {
        ...extraPaths,
        ...d.pagePaths,
        if (d.sourcePath != null) d.sourcePath!,
        if (d.normalizedPath != null) d.normalizedPath!,
        if (d.expense.receiptPath != null) d.expense.receiptPath!
      }) {
        if (File(p).absolute.path.startsWith('$inboxRoot/')) {
          final f = File(p);
          if (await f.exists()) await f.delete();
        }
      }
    }
    await db.deleteAccount(scope);
    for (final vehicle in vehicleIds) {
      final legacyDir =
          Directory('${root.path}/receipt_inbox/${_hash('$account/$vehicle')}');
      if (await legacyDir.exists()) await legacyDir.delete(recursive: true);
    }
    final dir = Directory('${root.path}/receipt_inbox/$scope');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
