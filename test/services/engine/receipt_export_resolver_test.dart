import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/evidence_review_service.dart';
import 'package:kilotax/services/engine/receipt_export_resolver.dart';
import 'package:kilotax/services/engine/tax_pack_builder.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = '11111111-1111-4111-a111-111111111111';
  const firstPath = '$owner/receipt-page-1.webp';
  const secondPath = '$owner/receipt-page-2.webp';
  final firstBytes = utf8.encode('%PDF-1.4 first original');
  final secondBytes = utf8.encode('%PDF-1.4 second original');
  String hash(List<int> bytes) => sha256.convert(bytes).toString();
  late Directory temp;
  late List<http.Request> requests;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('receipt-export-');
    requests = [];
  });
  tearDown(() async => temp.delete(recursive: true));

  VehicleExpense expense(
          {String? path, List<String>? paths, bool audit = true}) =>
      VehicleExpense(
          id: 'expense-1',
          vehicleId: 'vehicle-1',
          amount: 100,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 8, 1),
          receiptPath: path,
          receiptAudit: audit
              ? ReceiptAuditTrail(
                  reviewStatus: ReceiptReviewStatus.confirmed,
                  capturedAt: DateTime(2026, 8, 1),
                  imageSha256: hash(firstBytes),
                  revision: 1,
                  currentFields: {
                      if (paths != null) 'pagePaths': paths,
                      'pageHashes': [hash(firstBytes), hash(secondBytes)]
                    })
              : null);
  Map<String, dynamic> cloud(VehicleExpense record,
          {List<String> paths = const [firstPath, secondPath],
          int revision = 1,
          String user = owner}) =>
      {
        'id': SyncEngineService.cloudId(record.id, owner),
        'local_id': record.id,
        'user_id': user,
        'vehicle_id': SyncEngineService.cloudId(record.vehicleId, owner),
        'date': record.date.toIso8601String(),
        'deleted_at': null,
        'receipt_storage_path': firstPath,
        'sha256_hash': hash(firstBytes),
        'receipt_audit': {
          'revision': revision,
          'imageSha256': hash(firstBytes),
          'extractionImageSha256': hash(firstBytes),
          'currentFields': {
            'pagePaths': paths,
            'pageHashes': [hash(firstBytes), hash(secondBytes)],
            'transportPageHashes': [hash(firstBytes), hash(secondBytes)]
          }
        },
      };
  ReceiptExportResolver resolver(
      Future<http.Response> Function(http.Request) handler,
      {String? user = owner,
      String? token = 'private-token',
      bool Function()? current,
      Duration timeout = const Duration(seconds: 1),
      Duration budget = const Duration(seconds: 30),
      int maxBytes = 10 * 1024 * 1024}) {
    final value = ReceiptExportResolver(
        ownerId: user,
        accessToken: token,
        supabaseUrl: 'https://storage.example',
        anonKey: 'public-test-key',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.url.host, 'storage.example');
          expect(request.url.path, isNot(contains('/public/')));
          expect(request.headers['Authorization'], 'Bearer private-token');
          return handler(request);
        }),
        isCurrent: current,
        requestTimeout: timeout,
        recoveryBudget: budget,
        maxPageBytes: maxBytes);
    addTearDown(value.close);
    return value;
  }

  Future<http.Response> reply(
      http.Request request, Map<String, dynamic> row) async {
    if (request.url.path.endsWith('/expenses')) {
      return http.Response(jsonEncode([row]), 200);
    }
    return http.Response.bytes(
        request.url.path.endsWith('page-2.webp') ? secondBytes : firstBytes,
        200);
  }

  test(
      'available local bytes win and changed local bytes are never replaced by a cloud copy',
      () async {
    final file =
        await File('${temp.path}/receipt').writeAsString('changed local bytes');
    final source =
        resolver((_) async => throw StateError('Network must not be used'));
    final result = await source.resolve(expense(path: file.path));
    expect(result.pages.single.bytes, utf8.encode('changed local bytes'));
    expect(result.pages.single.savedSha256, hash(firstBytes));
    expect(result.pages.single.source, 'local');
    expect(requests, isEmpty);
  });

  test(
      'private recovery queries exact account, vehicle, year and expense then retrieves all pages',
      () async {
    final record = expense(
        path: '${temp.path}/missing',
        paths: ['${temp.path}/missing', '${temp.path}/missing2']);
    final source = resolver((request) => reply(request, cloud(record)));
    final result = await source.resolve(record);
    expect(result.pages.map((page) => page.bytes), [firstBytes, secondBytes]);
    expect(result.pages.every((page) => page.source == 'cloud'), isTrue);
    final query = requests.first.url.queryParameters;
    expect(query['id'], 'eq.${SyncEngineService.cloudId(record.id, owner)}');
    expect(query['user_id'], 'eq.$owner');
    expect(query['vehicle_id'],
        'eq.${SyncEngineService.cloudId(record.vehicleId, owner)}');
    expect(query['and'], '(date.gte.2026-07-01,date.lt.2027-07-01)');
    expect(query['deleted_at'], 'is.null');
    expect(requests, hasLength(3));
  });

  test(
      'partial local evidence keeps its page order and only downloads the missing page',
      () async {
    final file = await File('${temp.path}/first').writeAsBytes(firstBytes);
    final record =
        expense(path: file.path, paths: [file.path, '${temp.path}/missing']);
    final result = await resolver((request) => reply(request, cloud(record)))
        .resolve(record);
    expect(result.pages.map((page) => page.source), ['local', 'cloud']);
    expect(result.pages.map((page) => page.bytes), [firstBytes, secondBytes]);
    expect(requests, hasLength(2));
    expect(requests.last.url.path, endsWith('page-2.webp'));
  });

  test(
      'a known restored private object can be read without querying record metadata',
      () async {
    final record = expense(path: firstPath, paths: [firstPath]);
    final result =
        await resolver((_) async => http.Response.bytes(firstBytes, 200))
            .resolve(record);
    expect(result.pages.single.bytes, firstBytes);
    expect(requests, hasLength(1));
    expect(
        requests.single.url.path, contains('/object/authenticated/receipts/'));
  });

  test('guest and exhausted recovery budget never make network requests',
      () async {
    for (final source in [
      resolver((_) async => throw StateError('network'),
          user: null, token: null),
      resolver((_) async => throw StateError('network'), budget: Duration.zero)
    ]) {
      final result =
          await source.resolve(expense(path: '${temp.path}/missing'));
      expect(result.pages.single.bytes, isNull);
    }
    expect(requests, isEmpty);
  });

  test(
      'wrong-account metadata, wrong vehicle, wrong year and deleted records cannot hydrate evidence',
      () async {
    final record = expense(path: '${temp.path}/missing');
    for (final change in [
      {'user_id': 'other-owner'},
      {'vehicle_id': 'other-vehicle'},
      {'date': '2025-08-01'},
      {'deleted_at': '2026-08-02'}
    ]) {
      requests.clear();
      final row = {
        ...cloud(record, paths: [firstPath]),
        ...change
      };
      final result =
          await resolver((request) => reply(request, row)).resolve(record);
      expect(result.pages.single.bytes, isNull);
      expect(requests, hasLength(1));
    }
  });

  test(
      'cross-account and path traversal objects from metadata are never downloaded',
      () async {
    final record = expense(path: '${temp.path}/missing');
    for (final path in [
      'other-owner/page.webp',
      '$owner/../page.webp',
      '$owner/%2e%2e/page.webp',
      'https://outside.example/file'
    ]) {
      requests.clear();
      final result = await resolver(
              (request) => reply(request, cloud(record, paths: [path])))
          .resolve(record);
      expect(result.pages.single.bytes, isNull);
      expect(requests, hasLength(1));
    }
  });

  test(
      'a stale cloud revision or different page set cannot substitute evidence',
      () async {
    final record = expense(path: '${temp.path}/missing');
    for (final row in [
      cloud(record, paths: [firstPath], revision: 2),
      cloud(record)
    ]) {
      requests.clear();
      final result =
          await resolver((request) => reply(request, row)).resolve(record);
      expect(result.pages.single.bytes, isNull);
      expect(result.issue, contains('different'));
      expect(requests, hasLength(1));
    }
  });

  test(
      'transport hash mismatch and oversized or empty downloads stay unavailable',
      () async {
    final record = expense(path: firstPath, paths: [firstPath]);
    for (final bytes in [utf8.encode('wrong bytes'), <int>[]]) {
      final result =
          await resolver((_) async => http.Response.bytes(bytes, 200))
              .resolve(record);
      expect(result.pages.single.bytes, isNull);
    }
    final tooLarge = await resolver(
            (_) async => http.Response.bytes(firstBytes, 200),
            maxBytes: 3)
        .resolve(record);
    expect(tooLarge.pages.single.bytes, isNull);
  });

  test(
      'offline and timeout preserve local pages without failing the whole document',
      () async {
    final file = await File('${temp.path}/first').writeAsBytes(firstBytes);
    final record =
        expense(path: file.path, paths: [file.path, '${temp.path}/missing']);
    final offline =
        await resolver((_) async => throw const SocketException('offline'))
            .resolve(record);
    expect(offline.pages.first.bytes, firstBytes);
    expect(offline.pages.last.bytes, isNull);
    final gate = Completer<http.Response>();
    final timeout = await resolver((_) => gate.future,
            timeout: const Duration(milliseconds: 10))
        .resolve(record);
    gate.complete(http.Response('[]', 200));
    expect(timeout.pages.first.bytes, firstBytes);
    expect(timeout.pages.last.bytes, isNull);
  });

  test(
      'account change during recovery discards the response before any file can be shared',
      () async {
    var current = true;
    final record = expense(path: '${temp.path}/missing');
    final source = resolver((request) async {
      current = false;
      return reply(request, cloud(record, paths: [firstPath]));
    }, current: () => current);
    await expectLater(
        source.resolve(record), throwsA(isA<AccountantExportCancelled>()));
    expect(requests, hasLength(1));
  });

  test('file URI reads locally without needing a cloud account', () async {
    final file = await File('${temp.path}/receipt').writeAsBytes(firstBytes);
    final source = resolver((_) async => throw StateError('network'),
        user: null, token: null);
    final result = await source.resolve(expense(path: file.uri.toString()));
    expect(result.pages.single.bytes, firstBytes);
    expect(requests, isEmpty);
  });

  test(
      'real pack embeds recovered originals without rewriting expense data or flagging an absent primary pointer',
      () async {
    final record = expense();
    final source = resolver((request) => reply(request, cloud(record)));
    final pack = await const TaxPackBuilder().build(
        vehicle: Vehicle(
            id: 'vehicle-1',
            make: 'Toyota',
            model: 'Corolla',
            regoPlate: 'TEST'),
        taxRule: AppConstants.activeTaxRule,
        trips: [],
        expenses: [record],
        outputDirectory: temp,
        receiptResolver: source);
    final archive = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    expect(archive.findFile('Receipts/R000001_p01.pdf')!.content, firstBytes);
    expect(archive.findFile('Receipts/R000001_p02.pdf')!.content, secondBytes);
    final metadata = jsonDecode(utf8.decode(archive
        .findFile('Supporting/record-history.json')!
        .content as List<int>));
    expect(metadata['receiptDocuments']['expense-1'][0]['source'], 'cloud');
    expect(pack.receiptCount, 2);
    expect(
        pack.report.items.whereType<ExpenseReviewItem>().any(
            (item) => item.reasons.contains(ExpenseReviewReason.missingPhoto)),
        isFalse);
    expect(record.receiptPath, isNull);
    expect(
        record.receiptAudit!.currentFields.containsKey('pagePaths'), isFalse);
  });
}
