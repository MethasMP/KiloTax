import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import '../receipts/receipt_inbox_service.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/audit_evidence.dart';
import '../../data/models/job_site.dart';
import '../../data/models/annual_odometer.dart';
import '../../data/models/user_profile.dart';

/// Archives are decoded in memory with strict budgets; archive paths are never
/// used as filesystem destinations. Hashes detect corruption, not authorship.
class ReceiptBackupArchive {
  static const format = 'KiloClaim_Backup_v2';
  static const maxBytes = 256 * 1024 * 1024;
  static const maxEntries = 5000;

  static bool _local(String value) =>
      value.startsWith('/') || value.startsWith('file:');
  static Set<String> _paths(dynamic value, [String key = '']) {
    final result = <String>{};
    if (value is Map) {
      value.forEach((k, v) => result.addAll(_paths(v, k.toString())));
    } else if (value is List) {
      for (final v in value) {
        result.addAll(_paths(v, key));
      }
    } else if (value is String &&
        value.isNotEmpty &&
        (key.toLowerCase().contains('path') || key == 'localUri') &&
        _local(value)) {
      result.add(value);
    }
    return result;
  }

  static dynamic _rewrite(dynamic value, Map<String, String> paths) {
    if (value is String) return paths[value] ?? value;
    if (value is List) return value.map((v) => _rewrite(v, paths)).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _rewrite(v, paths)));
    }
    return value;
  }

  static Future<File> createArchive(
      {required Map<String, dynamic> payload,
      required ReceiptInboxService inbox,
      required File output}) async {
    final data = {
      'format': format,
      'payload': payload,
      'drafts': inbox.exportAccount()
    };
    final archive = Archive();
    final manifest = <String, dynamic>{};
    void add(String name, List<int> bytes) {
      manifest[name] = {
        'size': bytes.length,
        'sha256': sha256.convert(bytes).toString()
      };
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final remap = <String, String>{};
    var total = 0;
    for (final path in _paths(data)) {
      final file =
          path.startsWith('file:') ? File.fromUri(Uri.parse(path)) : File(path);
      if (!await file.exists()) {
        throw FormatException('Required receipt image is missing: $path');
      }
      final size = await file.length();
      total += size;
      if (size == 0 || total > maxBytes) {
        throw const FormatException('Invalid or oversized backup images.');
      }
      final bytes = await file.readAsBytes();
      final name = 'images/${sha256.convert(bytes)}';
      if (!manifest.containsKey(name)) add(name, bytes);
      remap[path] = name;
    }
    final metadata = utf8.encode(jsonEncode(_rewrite(data, remap)));
    add('metadata.json', metadata);
    final m = utf8.encode(jsonEncode({'format': format, 'files': manifest}));
    archive.addFile(ArchiveFile('manifest.json', m.length, m));
    if (archive.length > maxEntries ||
        archive.fold<int>(0, (sum, entry) => sum + entry.size) > maxBytes) {
      throw const FormatException('Backup exceeds the supported size.');
    }
    await output.parent.create(recursive: true);
    await output.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    return output;
  }

  static Future<ValidatedReceiptBackup> readArchive(File file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Backup is too large.');
    }
    final input = await file.readAsBytes();
    final directory = ZipDirectory();
    final names = <String>{};
    var expanded = 0;
    var count = 0;
    for (final header in directory.headers(InputMemoryStream(input),
        files: false, verify: true)) {
      expanded += header.uncompressedSize;
      count++;
      if (count > maxEntries ||
          expanded > maxBytes ||
          !names.add(header.filename) ||
          (header.externalFileAttributes >> 16) & 0xf000 == 0xa000) {
        throw const FormatException('Unsafe or oversized backup.');
      }
    }
    final archive = ZipDecoder().decodeBytes(input, verify: true);
    if (archive.length > maxEntries) {
      throw const FormatException('Too many backup entries.');
    }
    final entries = <String, ArchiveFile>{};
    var total = 0;
    for (final entry in archive) {
      final name = entry.name;
      if (!entry.isFile ||
          name.startsWith('/') ||
          name.contains('\\') ||
          name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
          entries.containsKey(name) ||
          entry.isSymbolicLink) {
        throw const FormatException('Unsafe backup entry.');
      }
      total += entry.size;
      if (entry.size < 0 || total > maxBytes) {
        throw const FormatException('Expanded backup is too large.');
      }
      entries[name] = entry;
    }
    Map<String, dynamic> decode(String name) {
      final e = entries[name];
      if (e == null) throw FormatException('Missing $name');
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(e.content)) as Map);
    }

    final manifest = decode('manifest.json');
    if (manifest['format'] != format) {
      throw const FormatException('Unsupported backup format.');
    }
    final hashes = Map<String, dynamic>.from(manifest['files'] as Map);
    if (hashes.length != entries.length - 1) {
      throw const FormatException('Unexpected archive files.');
    }
    final images = <String, List<int>>{};
    for (final item in hashes.entries) {
      final entry = entries[item.key];
      if (entry == null ||
          (item.key != 'metadata.json' &&
              !RegExp(r'^images/[a-f0-9]{64}$').hasMatch(item.key))) {
        throw const FormatException('Missing or unsupported backup file.');
      }
      final bytes = entry.content;
      final expected = item.value as Map;
      if (bytes.length != expected['size'] ||
          sha256.convert(bytes).toString() != expected['sha256']) {
        throw const FormatException('Backup integrity check failed.');
      }
      if (item.key.startsWith('images/')) images[item.key] = bytes;
    }
    final data = decode('metadata.json');
    if (data['format'] != format) {
      throw const FormatException('Unsupported metadata.');
    }
    final payload = Map<String, dynamic>.from(data['payload'] as Map);
    for (final key in ['vehicles', 'trips', 'expenses', 'evidence']) {
      if (payload[key] is! List) throw FormatException('Invalid $key records.');
    }
    final parsers = <String, dynamic Function(Map<String, dynamic>)>{
      'vehicles': Vehicle.fromJson,
      'trips': Trip.fromJson,
      'expenses': VehicleExpense.fromJson,
      'evidence': AuditEvidence.fromJson,
      'jobSites': JobSite.fromJson,
      'annualOdometers': AnnualVehicleOdometer.fromJson,
    };
    for (final item in parsers.entries) {
      for (final record in payload[item.key] as List? ?? []) {
        item.value(Map<String, dynamic>.from(record as Map));
      }
    }
    if (payload['userProfile'] != null) {
      UserProfile.fromJson(
          Map<String, dynamic>.from(payload['userProfile'] as Map));
    }
    final drafts = (data['drafts'] as List)
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    for (final draft in drafts) {
      ReceiptDraft.fromJson(draft);
    }
    void check(dynamic v, [String key = '']) {
      if (v is Map) {
        v.forEach((k, x) => check(x, k.toString()));
      } else if (v is List) {
        for (final x in v) {
          check(x, key);
        }
      } else if (v is String &&
          v.isNotEmpty &&
          (key.toLowerCase().contains('path') || key == 'localUri')) {
        if (_local(v) || (v.startsWith('images/') && !images.containsKey(v))) {
          throw const FormatException('Unbundled receipt image.');
        }
      }
    }

    check(data);
    return ValidatedReceiptBackup(payload, drafts, images);
  }

  /// A durable journal retains the remapped payload and drafts on partial failure.
  /// Retry the same archive: both merges preserve existing IDs. Files remain until
  /// both stores commit; no existing ledger/draft is rolled back or overwritten.
  static Future<void> restore(
      {required ValidatedReceiptBackup backup,
      required ReceiptInboxService inbox,
      required Future<void> Function(Map<String, dynamic>) restoreLedger,
      void Function()? checkOwner}) async {
    checkOwner?.call();
    final fingerprint =
        sha256.convert(utf8.encode(jsonEncode(backup.payload))).toString();
    final dir = Directory('${inbox.directory.path}/restored/$fingerprint');
    await dir.create(recursive: true);
    checkOwner?.call();
    final paths = <String, String>{};
    for (final entry in backup.images.entries) {
      final file = File('${dir.path}/${entry.key.split('/').last}');
      checkOwner?.call();
      await file.writeAsBytes(entry.value, flush: true);
      checkOwner?.call();
      paths[entry.key] = file.path;
    }
    final payload =
        Map<String, dynamic>.from(_rewrite(backup.payload, paths) as Map);
    final drafts = backup.drafts
        .map((d) => Map<String, dynamic>.from(_rewrite(d, paths) as Map))
        .toList();
    final journal = File('${dir.path}/restore_pending.json');
    await journal.writeAsString(
        jsonEncode({'payload': payload, 'drafts': drafts}),
        flush: true);
    checkOwner?.call();
    await restoreLedger(payload);
    checkOwner?.call();
    await inbox.importAccount(drafts);
    checkOwner?.call();
    await journal.delete();
  }
}

class ValidatedReceiptBackup {
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> drafts;
  final Map<String, List<int>> images;
  ValidatedReceiptBackup(this.payload, this.drafts, this.images);
  String get summary =>
      '${(payload['vehicles'] as List).length} vehicles, ${(payload['trips'] as List).length} trips, ${(payload['expenses'] as List).length} expenses, ${(payload['evidence'] as List).length} evidence records and ${drafts.length} pending receipts';
}
