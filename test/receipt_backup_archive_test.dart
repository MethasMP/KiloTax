import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kilotax/services/receipts/receipt_inbox_service.dart';
import 'package:kilotax/services/storage/receipt_backup_archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late ReceiptInboxService inbox;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('receipt_backup_test');
    inbox = ReceiptInboxService(await SharedPreferences.getInstance(), 'source',
        Directory('${root.path}/source'));
    await inbox.initialize();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Map<String, dynamic> payload() =>
      {'vehicles': [], 'trips': [], 'expenses': [], 'evidence': []};
  test(
      'roundtrip retains original bytes and pending drafts in private destination',
      () async {
    final image = File('${root.path}/original.jpg');
    final bytes = [255, 216, 11, 22, 33, 255, 217];
    await image.writeAsBytes(bytes);
    final draft = await inbox.retain(image.path, 'vehicle');
    await inbox.save([draft]);
    final archive = await ReceiptBackupArchive.createArchive(
        payload: payload(),
        inbox: inbox,
        output: File('${root.path}/backup.zip'));
    final backup = await ReceiptBackupArchive.readArchive(archive);
    expect(backup.drafts.length, 1);
    final db = await ReceiptDatabase.open('${root.path}/destination.sqlite',
        factory: databaseFactoryFfi);
    addTearDown(() => db.database.close());
    final destination = ReceiptInboxService(
        await SharedPreferences.getInstance(),
        'target',
        Directory('${root.path}/target'),
        database: db);
    await destination.initialize();
    var restored = false;
    await ReceiptBackupArchive.restore(
        backup: backup,
        inbox: destination,
        restoreLedger: (_) async {
          restored = true;
        });
    expect(restored, isTrue);
    final result = destination.load().single;
    expect(result.processed, isFalse);
    expect(result.sourcePath, startsWith(destination.directory.path));
    expect(await File(result.sourcePath!).readAsBytes(), bytes);
    await ReceiptBackupArchive.restore(
        backup: backup, inbox: destination, restoreLedger: (_) async {});
    expect(destination.load(), hasLength(1));
  });
  test('tamper and traversal rejected before restore', () async {
    final file = await ReceiptBackupArchive.createArchive(
        payload: payload(),
        inbox: inbox,
        output: File('${root.path}/backup.zip'));
    final decoded = ZipDecoder().decodeBytes(await file.readAsBytes());
    final changed = Archive();
    for (final entry in decoded) {
      final bytes =
          entry.name == 'metadata.json' ? utf8.encode('{}') : entry.content;
      changed.addFile(ArchiveFile(entry.name, bytes.length, bytes));
    }
    await file.writeAsBytes(ZipEncoder().encode(changed));
    await expectLater(
        ReceiptBackupArchive.readArchive(file), throwsFormatException);
    changed.addFile(ArchiveFile('../outside', 1, [1]));
    await file.writeAsBytes(ZipEncoder().encode(changed));
    await expectLater(
        ReceiptBackupArchive.readArchive(file), throwsFormatException);
  });
  test('failed ledger commit keeps recovery journal and retry completes',
      () async {
    final archive = await ReceiptBackupArchive.createArchive(
        payload: payload(),
        inbox: inbox,
        output: File('${root.path}/backup.zip'));
    final backup = await ReceiptBackupArchive.readArchive(archive);
    await expectLater(
        ReceiptBackupArchive.restore(
            backup: backup,
            inbox: inbox,
            restoreLedger: (_) async {
              throw StateError('disk unavailable');
            }),
        throwsStateError);
    final journals = await inbox.directory
        .list(recursive: true)
        .where((e) => e.path.endsWith('restore_pending.json'))
        .toList();
    expect(journals, hasLength(1));
    final journal =
        jsonDecode(await File(journals.single.path).readAsString()) as Map;
    expect(journal['payload'], payload());
    await ReceiptBackupArchive.restore(
        backup: backup, inbox: inbox, restoreLedger: (_) async {});
    expect(await File(journals.single.path).exists(), isFalse);
  });
  test('expanded ZIP budget is checked before inflation', () async {
    final file = await ReceiptBackupArchive.createArchive(
        payload: payload(),
        inbox: inbox,
        output: File('${root.path}/large.zip'));
    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 28; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(
            i + 24, ReceiptBackupArchive.maxBytes + 1, Endian.little);
        break;
      }
    }
    await file.writeAsBytes(bytes);
    await expectLater(
        ReceiptBackupArchive.readArchive(file), throwsFormatException);
  });
  test('unsupported format rejected', () async {
    final a = Archive();
    final bytes =
        utf8.encode(jsonEncode({'format': 'future-version', 'files': {}}));
    a.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
    final file = await File('${root.path}/future.zip')
        .writeAsBytes(ZipEncoder().encode(a));
    await expectLater(
        ReceiptBackupArchive.readArchive(file), throwsFormatException);
  });
  test('missing required image aborts backup', () async {
    final data = payload();
    data['expenses'] = [
      {'receiptPath': '${root.path}/missing.jpg'}
    ];
    await expectLater(
        ReceiptBackupArchive.createArchive(
            payload: data,
            inbox: inbox,
            output: File('${root.path}/backup.zip')),
        throwsFormatException);
  });
}
