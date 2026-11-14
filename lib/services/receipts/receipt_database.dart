import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class ReceiptRevisionConflict implements Exception {
  final String documentId;
  ReceiptRevisionConflict(this.documentId);
  @override
  String toString() => 'Receipt changed; reload before saving ($documentId).';
}

/// SQLite is the durable boundary for draft revisions and ledger commit intents.
class ReceiptDatabase {
  final Database database;
  ReceiptDatabase(this.database);
  static Future<ReceiptDatabase> open(String path,
      {DatabaseFactory? factory}) async {
    final db = await (factory ?? databaseFactory).openDatabase(path,
        options: OpenDatabaseOptions(
            version: 3,
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 3) {
                await db.execute(
                    'ALTER TABLE commits ADD COLUMN expected_revision INTEGER');
              }
              await db.execute(
                  'CREATE TABLE IF NOT EXISTS recorded_documents (account TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account,id))');
            },
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE drafts (account TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account,id))');
              await db.execute(
                  'CREATE TABLE commits (account TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, expected_revision INTEGER, PRIMARY KEY(account,id))');
              await db.execute(
                  'CREATE TABLE recorded_documents (account TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account,id))');
            }));
    return ReceiptDatabase(db);
  }

  Future<List<Map<String, dynamic>>> load(String account) async =>
      (await database.query('drafts',
              where: 'account = ?', whereArgs: [account], orderBy: 'rowid'))
          .map((r) => Map<String, dynamic>.from(
              jsonDecode(r['payload'] as String) as Map))
          .toList();

  Future<void> replace(String account, List<Map<String, dynamic>> drafts,
      Map<String, int> expected) async {
    await database.transaction((txn) async {
      final rows =
          await txn.query('drafts', where: 'account = ?', whereArgs: [account]);
      final actual = {
        for (final r in rows) r['id'] as String: r['revision'] as int
      };
      for (final id in {...actual.keys, ...expected.keys}) {
        if (actual[id] != expected[id]) throw ReceiptRevisionConflict(id);
      }
      await txn.delete('commits', where: 'account = ?', whereArgs: [account]);
      await txn.delete('drafts', where: 'account = ?', whereArgs: [account]);
      for (final d in drafts) {
        await txn.insert('drafts', {
          'account': account,
          'id': d['documentId'],
          'revision': d['revision'],
          'payload': jsonEncode(d)
        });
      }
    });
  }

  Future<void> stage(String account, String id, Map<String, dynamic> expense,
      {int? expectedRevision}) async {
    await database.transaction((txn) async {
      if (expectedRevision != null) {
        final rows = await txn.query('drafts',
            where: 'account = ? AND id = ?', whereArgs: [account, id]);
        if (rows.isEmpty || rows.single['revision'] != expectedRevision) {
          throw ReceiptRevisionConflict(id);
        }
      }
      await txn.insert(
          'commits',
          {
            'account': account,
            'id': id,
            'payload': jsonEncode(expense),
            'expected_revision': expectedRevision
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> pending(String account) async =>
      database.transaction((txn) async {
        final rows = await txn
            .query('commits', where: 'account = ?', whereArgs: [account]);
        final valid = <Map<String, dynamic>>[];
        for (final row in rows) {
          final drafts = await txn.query('drafts',
              where: 'account = ? AND id = ?', whereArgs: [account, row['id']]);
          if (drafts.isEmpty ||
              row['expected_revision'] == null ||
              drafts.single['revision'] != row['expected_revision']) {
            await txn.delete('commits',
                where: 'account = ? AND id = ?',
                whereArgs: [account, row['id']]);
          } else {
            valid.add(Map<String, dynamic>.from(
                jsonDecode(row['payload'] as String) as Map));
          }
        }
        return valid;
      });
  Future<void> complete(String account, String id) async {
    await database.transaction((txn) async {
      final rows = await txn.query('drafts',
          where: 'account = ? AND id = ?', whereArgs: [account, id]);
      if (rows.isNotEmpty) {
        final d = Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String) as Map);
        d['state'] = 'recorded';
        d['revision'] = (d['revision'] as int) + 1;
        await txn.insert('recorded_documents',
            {'account': account, 'id': id, 'payload': jsonEncode(d)},
            conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete('drafts',
            where: 'account = ? AND id = ?', whereArgs: [account, id]);
      }
      await txn.delete('commits',
          where: 'account = ? AND id = ?', whereArgs: [account, id]);
    });
  }

  Future<void> deleteAccount(String account) async =>
      database.transaction((txn) async {
        await txn.delete('drafts', where: 'account = ?', whereArgs: [account]);
        await txn.delete('commits', where: 'account = ?', whereArgs: [account]);
        await txn.delete('recorded_documents',
            where: 'account = ?', whereArgs: [account]);
      });
}
