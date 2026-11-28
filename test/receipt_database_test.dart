import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/receipts/receipt_inbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late ReceiptDatabase db;
  late ReceiptInboxService store;
  ReceiptDraft draft(String id, String vehicle) => ReceiptDraft(VehicleExpense(
      id: id,
      vehicleId: vehicle,
      amount: 10,
      category: ExpenseCategory.fuel,
      date: DateTime(2026)));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('receipt_db');
    db = await ReceiptDatabase.open('${dir.path}/inbox.db',
        factory: databaseFactoryFfi);
    store = ReceiptInboxService(
        await SharedPreferences.getInstance(), 'account', dir,
        database: db);
    await store.initialize();
  });
  tearDown(() async {
    await db.database.close();
    await dir.delete(recursive: true);
  });
  test(
      'account inbox discovers both vehicles after reopen and isolates accounts',
      () async {
    await store.save([draft('a', 'car'), draft('b', 'truck')]);
    final second =
        ReceiptInboxService(store.preferences, 'account', dir, database: db);
    await second.initialize();
    expect(second.load().map((d) => d.expense.vehicleId), ['car', 'truck']);
    final other =
        ReceiptInboxService(store.preferences, 'other', dir, database: db);
    await other.initialize();
    expect(other.load(), isEmpty);
  });
  test('stale replacement transaction rolls back all rows', () async {
    await store.save([draft('a', 'car')]);
    final stale =
        ReceiptInboxService(store.preferences, 'account', dir, database: db);
    await stale.initialize();
    await store.save([
      store.load().single.copyWith(issues: ['changed'])
    ]);
    await expectLater(stale.save([]), throwsA(isA<ReceiptRevisionConflict>()));
    await stale.initialize();
    expect(stale.load().single.issues, ['changed']);
  });
  test('pending ledger intent survives reopen and completes atomically',
      () async {
    await store.save([draft('a', 'car')]);
    await store.stageCommit(store.load().single.expense);
    final second =
        ReceiptInboxService(store.preferences, 'account', dir, database: db);
    await second.initialize();
    expect((await second.pendingCommits()).single.id, 'a');
    await second.completeCommit('a');
    expect(await second.pendingCommits(), isEmpty);
    expect(second.load(), isEmpty);
    expect((await db.database.query('recorded_documents')).length, 1);
  });
  test('editing a document invalidates a staged approval', () async {
    await store.save([draft('a', 'car')]);
    await store.stageCommit(store.load().single.expense);
    await store.save([
      store
          .load()
          .single
          .copyWith(expense: store.load().single.expense.copyWith(amount: 99))
    ]);
    expect(await store.pendingCommits(), isEmpty);
    expect(store.load().single.expense.amount, 99);
  });
  test('explicitly unknown date clears a previous extraction', () async {
    final known =
        draft('a', 'car').copyWith(purchaseDate: DateTime(2026, 11, 1));
    await store.save([known]);
    await store.save([store.load().single.copyWith(purchaseDate: null)]);
    expect(store.load().single.purchaseDate, isNull);
  });
  test('group and split preserve ordered sources and reset approval', () async {
    await store.save([
      draft('a', 'car')
          .copyWith(pagePaths: ['page1'], extractionReviewed: true),
      draft('b', 'car').copyWith(pagePaths: ['page2'])
    ]);
    final group = await store.groupDocuments(['b', 'a']);
    expect(group.pagePaths, ['page2', 'page1']);
    expect(group.expense.amount, 0);
    expect(group.extractionReviewed, isFalse);
    await store.splitDocument(group.documentId);
    expect(store.load().map((d) => d.documentId), ['b', 'a']);
    expect(
        store.load().every((d) =>
            !d.extractionReviewed && d.state == ReceiptDraftState.queued),
        isTrue);
  });
  test('stale document cannot stage a ledger intent', () async {
    await store.save([draft('a', 'car')]);
    final stale =
        ReceiptInboxService(store.preferences, 'account', dir, database: db);
    await stale.initialize();
    await store.save([
      store.load().single.copyWith(issues: ['new'])
    ]);
    await expectLater(stale.stageCommit(stale.load().single.expense),
        throwsA(isA<ReceiptRevisionConflict>()));
    expect(await store.pendingCommits(), isEmpty);
  });
  test('account cleanup removes legacy images for a recorded document',
      () async {
    final root = Directory('${dir.path}/root');
    await root.create();
    const account = 'owner';
    final scope = sha256.convert(utf8.encode(account)).toString();
    final oldDir = Directory('${root.path}/receipt_inbox/legacy_vehicle_hash');
    await oldDir.create(recursive: true);
    final image =
        await File('${oldDir.path}/receipt.png').writeAsBytes([1, 2, 3]);
    final service = ReceiptInboxService(store.preferences, scope,
        Directory('${root.path}/receipt_inbox/$scope'),
        database: db);
    await service.initialize();
    await service.save([
      ReceiptDraft(
          draft('recorded', 'car').expense.copyWith(receiptPath: image.path))
    ]);
    await service.stageCommit(service.load().single.expense);
    await service.completeCommit('recorded');
    expect(service.load(), isEmpty);
    await ReceiptInboxService.deleteAccount(account,
        rootDirectory: root, database: db);
    expect(await image.exists(), isFalse);
    expect(
        await db.database.query('recorded_documents',
            where: 'account = ?', whereArgs: [scope]),
        isEmpty);
  });
  test('known corrupt legacy index cannot prevent erasure of owned bytes',
      () async {
    const account = 'owner';
    final legacy = sha256.convert(utf8.encode('$account/car')).toString();
    final legacyDir = Directory('${dir.path}/receipt_inbox/$legacy');
    await legacyDir.create(recursive: true);
    await File('${legacyDir.path}/source.jpg').writeAsBytes([1, 2, 3]);
    await store.preferences
        .setString('receipt_inbox_v1_$legacy', 'corrupt json');
    await ReceiptInboxService.deleteAccount(account,
        rootDirectory: dir, database: db, knownVehicleIds: ['car']);
    expect(await legacyDir.exists(), isFalse);
    expect(store.preferences.getString('receipt_inbox_v1_$legacy'), isNull);
  });
  test('migration preserves malformed source and is repeatable', () async {
    await store.preferences.setString('receipt_inbox_v1_old', 'broken');
    await expectLater(store.migrateLegacy('old'), throwsFormatException);
    expect(store.preferences.getString('receipt_inbox_v1_old'), 'broken');
    await store.preferences.setString('receipt_inbox_v1_old',
        '[{"expense":{"id":"old","vehicleId":"car","amount":12,"category":"fuel","date":"2026-01-01"}}]');
    await store.migrateLegacy('old');
    await store.migrateLegacy('old');
    expect(store.load().single.documentId, 'old');
    expect(store.preferences.getString('receipt_inbox_v1_old'), isNotNull);
  });
}
