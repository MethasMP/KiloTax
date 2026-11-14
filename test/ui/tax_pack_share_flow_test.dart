import 'dart:io';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:kilotax/services/receipts/receipt_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/engine/tax_pack_share_helper.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit();
  sqlite.databaseFactory = ffi.databaseFactoryFfiNoIsolate;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const mailChannel = MethodChannel('flutter_email_sender');
  late Directory temp;
  late Directory documents;
  final sentNames = <String>[];
  final sentBodies = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('handoff-share-');
    documents = await Directory.systemTemp.createTemp('handoff-documents-');
    sentNames.clear();
    sentBodies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathChannel,
            (call) async => call.method == 'getTemporaryDirectory'
                ? temp.path
                : documents.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mailChannel, (call) async {
      final arguments = call.arguments as Map;
      final paths = (arguments['attachment_paths'] as List).cast<String>();
      expect(paths.length, 1);
      final bytes = await File(paths.single).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('summary.pdf'), isNotNull);
      expect(archive.findFile('review-issues.csv'), isNotNull);
      sentNames.addAll(paths);
      sentBodies.add(arguments['body'] as String);
      return null;
    });
  });

  tearDown(() async {
    final db =
        await ReceiptDatabase.open('${documents.path}/receipt_inbox.sqlite');
    await db.database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mailChannel, null);
    await temp.delete(recursive: true);
    await documents.delete(recursive: true);
  });

  Future<AppState> fixture({bool gap = false}) async {
    final state = AppState();
    await state.addVehicle(Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'HiLux',
      regoPlate: 'TEST',
      initialOdometer: 100,
      taxMethod: gap ? TaxMethod.logbook : TaxMethod.centsPerKm,
    ));
    state.recordTrip(Trip(
      id: 't1',
      vehicleId: 'v1',
      date: DateTime.now(),
      distanceKm: 10,
      purpose: '',
      startOdometer: gap ? 120 : 100,
      endOdometer: gap ? 130 : 110,
      taxMethod: gap ? TaxMethod.logbook : TaxMethod.centsPerKm,
    ));
    return state;
  }

  Future<void> finish(WidgetTester tester, Future<void> operation) async {
    var done = false;
    operation.whenComplete(() => done = true);
    for (var i = 0; i < 100 && !done; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue, reason: 'The actual share operation must finish');
    await operation;
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finder, findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .join(' | '));
  }

  testWidgets(
      'real helper shares one inspected ZIP only after review and cleans up',
      (tester) async {
    final state = await fixture();
    addTearDown(state.dispose);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => FilledButton(
        onPressed: () {
          operation = TaxPackShareHelper.shareTaxPack(context, state);
        },
        child: const Text('Prepare'),
      ),
    ))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Draft tax pack ready'));
    expect(sentNames, isEmpty);
    await tester.tap(find.text('Share draft ZIP'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    await tester.pumpAndSettle();
    expect(sentNames.length, 1);
    expect(sentBodies.single, contains('1 review items'));
    expect(sentBodies.single, isNot(contains('Audit-Proof')));
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
    expect(find.textContaining('Delivery is not confirmed.'), findsOneWidget);
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Product feedback'), findsOneWidget);
  });

  testWidgets('canceling the pack review sends nothing and removes the ZIP',
      (tester) async {
    final state = await fixture();
    addTearDown(state.dispose);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => FilledButton(
        onPressed: () {
          operation = TaxPackShareHelper.shareTaxPack(context, state);
        },
        child: const Text('Prepare'),
      ),
    ))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Draft tax pack ready'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    expect(sentNames, isEmpty);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });

  testWidgets('existing odometer-gap safeguard prevents package dispatch',
      (tester) async {
    final state = await fixture(gap: true);
    addTearDown(state.dispose);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => FilledButton(
        onPressed: () {
          operation = TaxPackShareHelper.shareTaxPack(context, state);
        },
        child: const Text('Prepare'),
      ),
    ))));
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();
    await operation;
    expect(find.textContaining('Review the unrecorded odometer travel'),
        findsOneWidget);
    expect(sentNames, isEmpty);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });
}
