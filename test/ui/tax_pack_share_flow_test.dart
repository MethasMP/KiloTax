import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../support/tax_pack_reader.dart';
import '../support/pack_save_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/receipts/receipt_inbox_service.dart';
import 'package:kiloclaim/services/engine/tax_pack_share_helper.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/services/auth/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

class AccountantTestAuth extends SupabaseAuthService {
  final events = StreamController<AuthState>.broadcast();
  @override
  AuthUser? getCurrentUser() => const AuthUser(
      id: 'owner-A', email: '', provider: 'test', accessToken: 'test-token');
  @override
  String? get currentAccessToken => 'test-token';
  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit();
  sqlite.databaseFactory = ffi.databaseFactoryFfiNoIsolate;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const mailChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const printingChannel = MethodChannel('net.nfet.printing');
  late Directory temp;
  late Directory documents;
  final sentNames = <String>[];
  final sentBodies = <String>[];
  final sentPendingCounts = <int>[];
  final sentPacks = <TaxPackReader>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('handoff-share-');
    documents = await Directory.systemTemp.createTemp('handoff-documents-');
    sentNames.clear();
    sentBodies.clear();
    sentPendingCounts.clear();
    sentPacks.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printingChannel,
            (_) async => <String, dynamic>{'canRaster': false});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathChannel,
            (call) async => call.method == 'getTemporaryDirectory'
                ? temp.path
                : documents.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mailChannel, (call) async {
      final arguments = call.arguments as Map;
      final paths = (arguments['paths'] as List).cast<String>();
      expect(paths.length, 1);
      final bytes = await File(paths.single).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      sentPacks.add(TaxPackReader(archive));
      expect(archive.findFile('Report.pdf'), isNotNull);
      expect(archive.findFile('Details.xlsx'), isNotNull);
      final metadata = jsonDecode(utf8.decode(archive
          .findFile('Supporting/record-history.json')!
          .content as List<int>));
      sentPendingCounts.add(metadata['pendingDraftCount'] as int);
      sentNames.addAll(paths);
      sentBodies.add(arguments['text'] as String);
      return 'com.test.share.target';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printingChannel, null);
    await temp.delete(recursive: true);
    await documents.delete(recursive: true);
  });

  Future<AppState> fixture({bool gap = false, AccountantTestAuth? auth}) async {
    final state = AppState(authService: auth);
    if (auth != null) await state.init();
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
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
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
    await tester.runAsync(() async {
      final inbox = await ReceiptInboxService.open('guest', 'v1');
      final year = int.parse(state.activeTaxRule.financialYear.substring(0, 4));
      ReceiptDraft draft(String id, DateTime date,
              {String vehicleId = 'v1',
              ReceiptDraftState status = ReceiptDraftState.needsReview}) =>
          ReceiptDraft(
              VehicleExpense(
                  id: id,
                  vehicleId: vehicleId,
                  date: date,
                  amount: 10,
                  category: ExpenseCategory.fuel),
              state: status);
      await inbox.save([
        draft('current', DateTime(year, 8, 1)),
        draft('prior', DateTime(year - 1, 8, 1)),
        draft('other-vehicle', DateTime(year, 8, 1), vehicleId: 'v2'),
        draft('already-recorded', DateTime(year, 8, 1),
            status: ReceiptDraftState.recorded),
      ]);
    });
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => FilledButton(
        onPressed: () {
          operation = Future.wait([
            TaxPackShareHelper.shareTaxPack(context, state),
            TaxPackShareHelper.shareTaxPack(context, state)
          ]).then((_) {});
        },
        child: const Text('Prepare'),
      ),
    ))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Review accountant pack'));
    expect(sentNames, isEmpty);
    expect(find.text('Preview report'), findsOneWidget);
    expect(find.textContaining('Your summary, spreadsheet'), findsOneWidget);
    await tester.tap(find.text('Preview report'));
    await waitFor(tester, find.text('Report preview'));
    await tester.pumpAndSettle();
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(sentNames, isEmpty);
    final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(preview.allowSharing, isFalse);
    expect(preview.allowPrinting, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share pack'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    await tester.pumpAndSettle();
    expect(sentNames.length, 1);
    expect(sentBodies.single, contains('2 review groups'));
    expect(sentPendingCounts.single, 1);
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
    await waitFor(tester, find.text('Review accountant pack'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    expect(sentNames, isEmpty);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });

  testWidgets(
      'odometer gaps use the same accountant handoff and remain visible for review',
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
    await waitFor(tester, find.text('Review accountant pack'));
    expect(find.textContaining('Unexplained odometer distance'), findsWidgets);
    expect(find.text('Share pack'), findsOneWidget);
    expect(sentNames, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });
  testWidgets(
      'session change hides a prepared preview and prevents sharing another account snapshot',
      (tester) async {
    final auth = AccountantTestAuth();
    final state = await fixture(auth: auth);
    addTearDown(state.dispose);
    addTearDown(auth.events.close);
    expect(state.isAccountantExportSessionCurrent('owner-A', 'test-token'),
        isTrue);
    expect(state.isAccountantExportSessionCurrent('other-owner', 'test-token'),
        isFalse);
    expect(state.isAccountantExportSessionCurrent('owner-A', 'other-token'),
        isFalse);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () {
                      operation =
                          TaxPackShareHelper.shareTaxPack(context, state);
                    },
                    child: const Text('Prepare'))))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Review accountant pack'));
    await tester.tap(find.text('Preview report'));
    await waitFor(tester, find.text('Report preview'));
    await tester.pumpAndSettle();
    expect(find.byType(PdfPreview), findsOneWidget);
    auth.events.add(AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(find.byType(PdfPreview), findsNothing);
    expect(
        find.text('Your session changed. Prepare a new pack.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Preparation cancelled'), findsOneWidget);
    expect(find.text('Share pack'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    expect(sentNames, isEmpty);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });

  testWidgets(
      'single default handoff remains usable on a narrow screen at large text scale',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = await fixture(gap: true);
    addTearDown(state.dispose);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () {
                      operation =
                          TaxPackShareHelper.shareTaxPack(context, state);
                    },
                    child: const Text('Prepare'))))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Review accountant pack'));
    await tester.pumpAndSettle();
    expect(find.text('Share pack'), findsOneWidget);
    expect(find.text('Share ZIP'), findsNothing);
    expect(find.text('Share draft ZIP'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    expect(sentNames, isEmpty);
  });
  testWidgets(
      'Selected historical vehicle pack excludes all other scope data without changing primary',
      (tester) async {
    final state = await fixture();
    addTearDown(state.dispose);
    await state.addVehicle(Vehicle(
        id: 'v2',
        make: 'Ford',
        model: 'Ranger',
        regoPlate: 'OTHER',
        isPrimary: false,
        initialOdometer: 100,
        taxMethod: TaxMethod.centsPerKm));
    for (final record in [
      (id: 'chosen-trip', car: 'v2', date: DateTime(2025, 8, 1), km: 20.0),
      (id: 'wrong-year', car: 'v2', date: DateTime(2026, 8, 1), km: 30.0),
      (id: 'wrong-car', car: 'v1', date: DateTime(2025, 8, 1), km: 40.0),
    ]) {
      state.recordTrip(Trip(
          id: record.id,
          vehicleId: record.car,
          date: record.date,
          distanceKm: record.km,
          startOdometer: 100,
          endOdometer: 100 + record.km,
          purpose: record.id,
          classification: TripClassification.business));
    }
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                      onPressed: () => operation =
                          TaxPackShareHelper.shareTaxPack(context, state,
                              vehicleId: 'v2', financialYear: '2025-26'),
                      child: const Text('Prepare'),
                    )))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Review accountant pack'));
    expect(state.primaryVehicle!.id, 'v1');
    await tester.tap(find.text('Share pack'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    final pack = sentPacks.single;
    expect(pack.metadata['vehicleId'], 'v2');
    expect(pack.metadata['financialYear'], '2025-26');
    expect(pack.metadata['tripCount'], 1);
    expect(pack.searchableText, contains('chosen-trip'));
    expect(pack.searchableText, isNot(contains('wrong-year')));
    expect(pack.searchableText, isNot(contains('wrong-car')));
    expect(pack.summaryValue('Rate (AUD per km)'), .88);
    expect(state.primaryVehicle!.id, 'v1');
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });
  testWidgets(
      'Save a copy writes the reviewed ZIP through system picker without sharing',
      (tester) async {
    final original = FilePickerPlatform.instance;
    final picker = PackSavePicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = original);
    final state = await fixture();
    addTearDown(state.dispose);
    Future<void>? operation;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                      onPressed: () => operation =
                          TaxPackShareHelper.shareTaxPack(context, state),
                      child: const Text('Prepare'),
                    )))));
    await tester.tap(find.text('Prepare'));
    await waitFor(tester, find.text('Review accountant pack'));
    expect(picker.savedBytes, isNull);
    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();
    await finish(tester, operation!);
    final archive = ZipDecoder().decodeBytes(picker.savedBytes!);
    expect(archive.findFile('Report.pdf'), isNotNull);
    expect(archive.findFile('Details.xlsx'), isNotNull);
    expect(sentNames, isEmpty);
    expect(find.text('Pack saved to your selected location.'), findsOneWidget);
    expect(await tester.runAsync(() => temp.list().toList()), isEmpty);
  });
}
