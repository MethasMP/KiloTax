import 'package:kiloclaim/services/storage/local_storage_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/sync/sync_engine_service.dart';
import 'package:kiloclaim/state/app_state.dart';
import 'package:kiloclaim/services/auth/supabase_auth_service.dart';

class ReceiptRestoreAuth extends SupabaseAuthService {
  @override
  AuthUser? getCurrentUser() => const AuthUser(
      id: 'owner', email: '', provider: 'test', accessToken: 'token');
  @override
  String? get currentAccessToken => 'token';
  @override
  get onAuthStateChange => null;
  @override
  void prewarmConnection() {}
}

class DelayedRestoreEngine extends SyncEngineService {
  final firstStarted = Completer<void>();
  final secondStarted = Completer<void>();
  final response = Completer<CloudRestoreResult>();
  int calls = 0;
  @override
  Future<CloudRestoreResult> restoreFromCloud(
      {String? vehicleId,
      String? userToken,
      String? userId,
      bool requireAuth = false,
      Directory? localCacheDir}) {
    calls++;
    if (calls == 1) firstStarted.complete();
    if (calls == 2) secondStarted.complete();
    return response.future;
  }
}

void main() {
  for (final dispose in [true, false]) {
    test(
        'late cloud restore is ignored after ${dispose ? 'dispose' : 'sign out'}',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final engine = DelayedRestoreEngine();
      final state = AppState(
          storageService: storage,
          authService: ReceiptRestoreAuth(),
          syncEngine: engine);
      await state.init();
      await engine.firstStarted.future;
      final restoring = state.restoreFromCloud();
      await engine.secondStarted.future;
      if (dispose) {
        state.dispose();
      } else {
        await state.signOut();
      }
      engine.response.complete(CloudRestoreResult(success: true, vehicles: [
        Vehicle(
            id: 'late-car',
            make: 'Toyota',
            model: 'Hilux',
            regoPlate: 'LATE',
            initialOdometer: 0)
      ], trips: [], expenses: []));
      final result = await restoring;
      expect(result.success, isFalse);
      expect(state.vehicles, isEmpty);
      expect(storage.loadVehicles(), isEmpty);
      if (!dispose) state.dispose();
    });
  }

  test('job sync failure keeps the overall sync in error for retry', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    await storage.saveVehicles([
      Vehicle(
          id: 'v-job-sync',
          make: 'Toyota',
          model: 'Hilux',
          regoPlate: 'SYNC',
          initialOdometer: 0,
          isPrimary: true)
    ]);
    await storage.saveJobSites([
      JobSite(
          id: 'job-sync',
          name: 'Renovation',
          clientName: 'Smith',
          latitude: 0,
          longitude: 0,
          trackingEnabled: false)
    ]);
    final client = MockClient((r) async =>
        http.Response('[]', r.url.path.endsWith('/job_sites') ? 503 : 201));
    final state = AppState(
        storageService: storage,
        authService: ReceiptRestoreAuth(),
        syncEngine: SyncEngineService(httpClient: client));
    await state.init();
    await state.restoreFromCloud();
    final result = await state.triggerSyncToCloud();
    expect(result.success, isFalse);
    expect(state.syncStatus, SyncStatus.error);
    expect(state.jobSites, hasLength(1));
    state.dispose();
    client.close();
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'multi-page sync preserves observation hashes and verifies downloaded pages',
      () async {
    final dir = await Directory.systemTemp.createTemp('page-sync-');
    addTearDown(() => dir.delete(recursive: true));
    final pages = [
      await File('${dir.path}/a').writeAsBytes([1, 2, 3]),
      await File('${dir.path}/b').writeAsBytes([4, 5, 6])
    ];
    Map<String, dynamic>? payload;
    final binaries = <String, List<int>>{};
    var corrupt = false;
    final client = MockClient((request) async {
      if (request.url.path.contains('/storage/v1/object/')) {
        final key = request.url.path.split('/receipts/').last;
        if (request.method == 'POST') {
          binaries[key] = request.bodyBytes;
          return http.Response('{}', 200);
        }
        return http.Response.bytes(corrupt ? [9] : binaries[key]!, 200);
      }
      if (request.url.path.endsWith('/expenses')) {
        if (request.method == 'POST') {
          payload = Map<String, dynamic>.from(jsonDecode(request.body)[0]);
          return http.Response('[]', 201);
        }
        return http.Response(jsonEncode([payload]), 200);
      }
      return http.Response('[]', 200);
    });
    addTearDown(client.close);
    final service = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'key',
        httpClient: client);
    final expense = VehicleExpense(
        id: 'doc',
        vehicleId: 'car',
        amount: 11,
        currency: 'NZD',
        supplierAbn: '123',
        invoiceNumber: 'I-1',
        category: ExpenseCategory.fuel,
        date: DateTime(2026),
        receiptPath: pages.first.path,
        receiptAudit: ReceiptAuditTrail(
            capturedAt: DateTime(2026),
            reviewStatus: ReceiptReviewStatus.confirmed,
            extractionImageSha256: 'original-observation',
            currentFields: {
              'pagePaths': pages.map((f) => f.path).toList(),
              'pageHashes': ['original-first', 'original-second']
            }));
    final result = await service.syncToCloud(
        vehicle: Vehicle(
            id: 'car',
            make: 'A',
            model: 'B',
            regoPlate: 'C',
            initialOdometer: 0),
        trips: [],
        expenses: [expense],
        userId: 'owner');
    expect(result.success, isTrue);
    expect(payload!['currency'], 'NZD');
    expect(payload!['supplier_abn'], '123');
    expect(payload!['invoice_number'], 'I-1');
    final fields = payload!['receipt_audit']['currentFields'];
    expect(fields['pagePaths'],
        ['owner/doc-page-1.webp', 'owner/doc-page-2.webp']);
    expect(fields['pageHashes'], ['original-first', 'original-second']);
    expect(payload!['receipt_audit']['extractionImageSha256'],
        'original-observation');
    final cache = await Directory('${dir.path}/cache').create();
    final restored =
        await service.restoreFromCloud(userId: 'owner', localCacheDir: cache);
    expect(restored.success, isTrue);
    expect(restored.expenses.single.currency, 'NZD');
    final localPages = restored
        .expenses.single.receiptAudit!.currentFields['pagePaths'] as List;
    expect(await File(localPages[0]).readAsBytes(), [1, 2, 3]);
    expect(await File(localPages[1]).readAsBytes(), [4, 5, 6]);
    corrupt = true;
    final otherCache = await Directory('${dir.path}/corrupt').create();
    final rejected = await service.restoreFromCloud(
        userId: 'owner', localCacheDir: otherCache);
    expect(rejected.success, isFalse);
    expect(rejected.expenses.single.receiptAudit!.currentFields['pagePaths'],
        fields['pagePaths']);
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test('HTTP expense rejection is a failed sync with acknowledged counts',
      () async {
    final service = SyncEngineService(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/expenses')) {
        return http.Response('{"code":"PGRST204"}', 400);
      }
      return http.Response('[]', 201);
    }));
    final result = await service.syncToCloud(
        vehicle: Vehicle(
            id: 'car',
            make: 'Toyota',
            model: 'Corolla',
            regoPlate: 'ABC',
            initialOdometer: 0),
        trips: [],
        expenses: [
          VehicleExpense(
              id: 'receipt',
              vehicleId: 'car',
              amount: 10,
              category: ExpenseCategory.fuel,
              date: DateTime(2026))
        ]);
    expect(result.success, isFalse);
    expect(result.syncedExpenses, 0);
    expect(result.errorMessage, contains('expenses'));
  });

  test(
      'mixed receipt cloud round trip preserves local IDs links and review facts',
      () async {
    final stored = <String, List<dynamic>>{};
    final service = SyncEngineService(httpClient: MockClient((request) async {
      final name = request.url.pathSegments.last;
      if (request.method == 'POST') {
        stored[name] = jsonDecode(request.body) as List<dynamic>;
        return http.Response(request.body, 201);
      }
      return http.Response(jsonEncode(stored[name] ?? []), 200);
    }));
    final receipt = VehicleExpense(
        id: 'receipt_local',
        vehicleId: 'vehicle_local',
        linkedTripId: 'trip_local',
        date: DateTime(2026, 11, 10),
        amount: 110,
        supplier: 'Service station',
        category: ExpenseCategory.fuel,
        allocations: const [
          ReceiptAllocation(
              description: 'Fuel',
              amount: 100,
              purpose: AllocationPurpose.work),
          ReceiptAllocation(
              description: 'Groceries',
              amount: 10,
              purpose: AllocationPurpose.private)
        ],
        receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.manualReview,
            capturedAt: DateTime(2026)));
    final car = Vehicle(
        id: 'vehicle_local',
        make: 'Toyota',
        model: 'Corolla',
        regoPlate: 'TEST',
        initialOdometer: 100);
    final trip = Trip(
        id: 'trip_local',
        vehicleId: car.id,
        date: DateTime(2026),
        distanceKm: 5,
        purpose: 'Delivery');
    final first = await service.syncToCloud(
        vehicle: car, trips: [trip], expenses: [receipt], userId: 'tenant');
    expect(first.success, isTrue);
    final firstId = stored['expenses']!.single['id'];
    expect(firstId, matches(RegExp(r'^[a-f0-9-]{36}$')));
    await service.syncToCloud(
        vehicle: car,
        trips: [trip],
        expenses: [receipt.copyWith(notes: 'changed')],
        userId: 'tenant');
    expect(stored['expenses']!.single['id'], firstId);
    expect(
        SyncEngineService.generateExpenseDedupKey(
            receipt.copyWith(id: 'another')),
        isNot(SyncEngineService.generateExpenseDedupKey(receipt)));
    final restored = await service.restoreFromCloud(userId: 'tenant');
    expect(restored.success, isTrue);
    expect(restored.vehicles.single.id, car.id);
    expect(restored.trips.single.id, trip.id);
    expect(restored.trips.single.vehicleId, car.id);
    expect(restored.expenses.single.linkedTripId, trip.id);
    expect(restored.expenses.single.supplier, 'Service station');
    expect(restored.expenses.single.allocations.length, 2);
    expect(restored.expenses.single.allocatedWorkAmount, 100);
    expect(restored.expenses.single.receiptAudit?.reviewStatus,
        ReceiptReviewStatus.manualReview);
  });

  test('receipt upload failure cannot report sync success', () async {
    final dir = await Directory.systemTemp.createTemp('failed-upload-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/receipt.jpg').writeAsBytes([1, 2, 3]);
    final service = SyncEngineService(
        httpClient: MockClient((request) async =>
            request.url.path.contains('/storage/')
                ? http.Response('failed', 500)
                : http.Response('[]', 201)));
    final result = await service.syncToCloud(
        vehicle: Vehicle(
            id: 'car',
            make: 'Toyota',
            model: 'Corolla',
            regoPlate: 'TEST',
            initialOdometer: 0),
        trips: [],
        expenses: [
          VehicleExpense(
              id: 'receipt',
              vehicleId: 'car',
              date: DateTime(2026),
              amount: 10,
              category: ExpenseCategory.fuel,
              receiptPath: file.path)
        ]);
    expect(result.success, isFalse);
    expect(result.syncedExpenses, 0);
  });

  test('profile is ensured without overwriting it before vehicle sync',
      () async {
    final paths = <String>[];
    final service = SyncEngineService(httpClient: MockClient((request) async {
      paths.add(request.url.pathSegments.last);
      if (request.url.path.endsWith('/profiles')) {
        expect(request.headers['Prefer'], contains('ignore-duplicates'));
        expect((jsonDecode(request.body) as List).single['id'], 'owner');
      }
      return http.Response('[]', 201);
    }));
    final result = await service.syncToCloud(
        vehicle: Vehicle(
            id: 'car',
            make: 'Toyota',
            model: 'Corolla',
            regoPlate: 'TEST',
            initialOdometer: 0),
        trips: [],
        expenses: [],
        userId: 'owner');
    expect(result.success, isTrue);
    expect(paths.take(2).toList(), ['profiles', 'vehicles']);
  });

  test(
      'partial cloud restore merges available records and reports incomplete recovery',
      () async {
    final service = SyncEngineService(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
            jsonEncode([
              {
                'id': 'restored-car',
                'make': 'Toyota',
                'model': 'Corolla',
                'rego_plate': 'TEST',
                'initial_odometer': 100
              }
            ]),
            200);
      }
      if (request.url.path.endsWith('/expenses')) {
        return http.Response('failure', 503);
      }
      return http.Response('[]', 200);
    }));
    final state =
        AppState(authService: ReceiptRestoreAuth(), syncEngine: service);
    await state.init();
    final result = await state.restoreFromCloud();
    expect(result.success, isFalse);
    expect(state.vehicles.single.id, 'restored-car');
    expect(state.syncStatus, SyncStatus.error);
    expect(state.syncErrorMessage, isNotEmpty);
    state.dispose();
  });

  group('SyncEngineService Tenant Token & User ID Suite', () {
    late Vehicle testVehicle;
    late List<Trip> testTrips;
    late List<VehicleExpense> testExpenses;

    setUp(() {
      testVehicle = Vehicle(
        id: 'veh-123',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'KILO-01',
        initialOdometer: 50000.0,
      );

      testTrips = [
        Trip(
          id: 'trip-1',
          vehicleId: 'veh-123',
          distanceKm: 25.0,
          date: DateTime(2026, 9, 15, 8, 30),
          purpose: 'Site Inspection',
          classification: TripClassification.business,
        ),
      ];

      testExpenses = [
        VehicleExpense(
          id: 'exp-1',
          vehicleId: 'veh-123',
          amount: 85.50,
          category: ExpenseCategory.fuel,
          date: DateTime(2026, 9, 15, 12, 0),
        ),
      ];
    });

    test(
        'syncToCloud includes userToken in Authorization header and userId in payloads',
        () async {
      String? capturedAuthHeader;
      Map<String, dynamic>? capturedVehiclePayload;
      List<dynamic>? capturedTripPayload;
      List<dynamic>? capturedExpensePayload;

      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];

        if (request.url.path.contains('vehicles')) {
          final list = jsonDecode(request.body) as List<dynamic>;
          capturedVehiclePayload = list.first as Map<String, dynamic>;
          return http.Response(jsonEncode(list), 201);
        } else if (request.url.path.contains('trips')) {
          capturedTripPayload = jsonDecode(request.body) as List<dynamic>;
          return http.Response(jsonEncode(capturedTripPayload), 201);
        } else if (request.url.path.contains('expenses')) {
          capturedExpensePayload = jsonDecode(request.body) as List<dynamic>;
          return http.Response(jsonEncode(capturedExpensePayload), 201);
        }
        return http.Response('{}', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.syncToCloud(
        vehicle: testVehicle,
        trips: testTrips,
        expenses: testExpenses,
        userToken: 'user_jwt_token_xyz',
        userId: 'user-uuid-999',
      );

      expect(result.success, isTrue);
      expect(capturedAuthHeader, equals('Bearer user_jwt_token_xyz'));
      expect(capturedVehiclePayload?['user_id'], equals('user-uuid-999'));
      expect((capturedTripPayload?.first as Map<String, dynamic>)['user_id'],
          equals('user-uuid-999'));
      expect((capturedExpensePayload?.first as Map<String, dynamic>)['user_id'],
          equals('user-uuid-999'));
    });

    test(
        'syncToCloud falls back to anonKey in Authorization header when userToken is omitted',
        () async {
      String? capturedAuthHeader;

      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.syncToCloud(
        vehicle: testVehicle,
        trips: testTrips,
        expenses: testExpenses,
      );

      expect(result.success, isTrue);
      expect(capturedAuthHeader, equals('Bearer test_anon_key'));
    });

    test('restoreFromCloud filters queries by user_id and passes userToken',
        () async {
      final requestedUrls = <String>[];
      final requestedAuthHeaders = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        requestedAuthHeaders.add(request.headers['Authorization'] ?? '');
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.restoreFromCloud(
        userToken: 'jwt_restore_token',
        userId: 'taxpayer-123',
      );

      expect(result.success, isTrue);
      expect(requestedAuthHeaders.every((h) => h == 'Bearer jwt_restore_token'),
          isTrue);
      expect(
          requestedUrls.any((u) =>
              u.contains('vehicles') && u.contains('user_id=eq.taxpayer-123')),
          isTrue);
      expect(
          requestedUrls.any((u) =>
              u.contains('trips') && u.contains('user_id=eq.taxpayer-123')),
          isTrue);
      expect(
          requestedUrls.any((u) =>
              u.contains('expenses') && u.contains('user_id=eq.taxpayer-123')),
          isTrue);
    });

    test(
        'restoreFromCloud tracks unparseable/corrupted records and marks partial failure',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('vehicles')) {
          // One valid, one corrupted vehicle record
          return http.Response(
              jsonEncode([
                {
                  'id': 'v-valid',
                  'make': 'Toyota',
                  'model': 'Corolla',
                  'rego_plate': 'COR-123',
                  'initial_odometer': 1000.0,
                },
                {
                  'id': 'v-corrupt',
                  // Missing required fields / bad types
                  'make': 12345,
                }
              ]),
              200);
        } else if (request.url.path.contains('trips')) {
          // Corrupted trip record
          return http.Response(
              jsonEncode([
                {'corrupted': true}
              ]),
              200);
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.restoreFromCloud(userId: 'test-user');

      expect(result.success, isFalse);
      expect(result.corruptedRecordsCount, equals(2));
      expect(result.vehicles.length, equals(1));
      expect(result.vehicles.first.id, equals('v-valid'));
      expect(
          result.errorMessage,
          contains(
              '2 records or receipt files could not be restored completely.'));
    });

    test(
        'syncToCloud syncs both business and personal trips with privacy masking',
        () async {
      List<dynamic>? capturedTrips;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('trips')) {
          capturedTrips = jsonDecode(request.body) as List<dynamic>;
          return http.Response(jsonEncode(capturedTrips), 201);
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final mixedTrips = [
        Trip(
          id: 'biz-1',
          vehicleId: testVehicle.id,
          distanceKm: 15.0,
          date: DateTime(2026, 9, 10, 8, 0),
          purpose: 'Client Consultation',
          startOdometer: 1000.0,
          endOdometer: 1015.0,
          classification: TripClassification.business,
          originAddress: 'Office Headquarters',
          destinationAddress: 'Client Office',
        ),
        Trip(
          id: 'pers-1',
          vehicleId: testVehicle.id,
          distanceKm: 5.0,
          date: DateTime(2026, 9, 10, 18, 0),
          purpose: 'Grocery run',
          startOdometer: 1015.0,
          endOdometer: 1020.0,
          classification: TripClassification.personal,
          originAddress: 'Home',
          destinationAddress: 'Supermarket',
        ),
      ];

      final result = await syncService.syncToCloud(
        vehicle: testVehicle,
        trips: mixedTrips,
        expenses: [],
        userId: 'user-777',
      );

      expect(result.success, isTrue);
      expect(result.syncedTrips, equals(2));
      expect(result.rejectedOrIgnored, equals(0));
      expect(capturedTrips?.length, equals(2));

      final bizJson =
          capturedTrips!.firstWhere((t) => t['local_id'] == 'biz-1');
      expect(bizJson['classification'], equals('business'));
      expect(bizJson['purpose'], equals('Client Consultation'));
      expect(bizJson['origin_address'], equals('Office Headquarters'));
      expect(bizJson['destination_address'], equals('Client Office'));

      final persJson =
          capturedTrips!.firstWhere((t) => t['local_id'] == 'pers-1');
      expect(persJson['classification'], equals('personal'));
      expect(persJson['purpose'], equals('Personal'));
      expect(persJson['origin_address'], equals('Personal Location'));
      expect(persJson['destination_address'], equals('Personal Destination'));
      expect(persJson['start_odometer'], equals(1015.0));
      expect(persJson['end_odometer'], equals(1020.0));
    });

    test(
        'syncToCloud uploads local receipt image and updates receipt_storage_path to cloud path',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('receipt_test_');
      final sampleReceipt = File('${tempDir.path}/local_receipt.webp')
        ..writeAsBytesSync(utf8.encode('FAKE_IMAGE_BYTES'));

      final expenseWithReceipt = VehicleExpense(
        id: 'exp-receipt-1',
        vehicleId: testVehicle.id,
        amount: 45.0,
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 9, 11),
        receiptPath: sampleReceipt.path,
      );

      final uploadedPaths = <String>[];
      List<dynamic>? capturedExpenses;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/storage/v1/object/receipts/')) {
          uploadedPaths.add(request.url.path);
          return http.Response(jsonEncode({'Key': request.url.path}), 200);
        } else if (request.url.path.contains('expenses')) {
          capturedExpenses = jsonDecode(request.body) as List<dynamic>;
          return http.Response(jsonEncode(capturedExpenses), 201);
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.syncToCloud(
        vehicle: testVehicle,
        trips: [],
        expenses: [expenseWithReceipt],
        userId: 'user-abc',
      );

      expect(result.success, isTrue);
      expect(uploadedPaths.length, equals(1));
      expect(uploadedPaths.first,
          contains('receipts/user-abc/exp-receipt-1.webp'));

      expect(capturedExpenses?.length, equals(1));
      final expPayload = capturedExpenses!.first as Map<String, dynamic>;
      expect(expPayload['receipt_storage_path'],
          equals('user-abc/exp-receipt-1.webp'));

      tempDir.deleteSync(recursive: true);
    });

    test(
        'restoreFromCloud downloads remote receipt and caches to local directory',
        () async {
      final tempCacheDir =
          Directory.systemTemp.createTempSync('cache_restore_');
      final fakeBytes = utf8.encode('SAMPLE_RESTORED_BINARY_DATA');

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('expenses')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'exp-cloud-99',
                'vehicle_id': 'veh-123',
                'amount': 99.0,
                'category': 'fuel',
                'date': '2026-09-12T10:00:00.000',
                'receipt_storage_path': 'user-xyz/exp-cloud-99.webp',
              }
            ]),
            200,
          );
        } else if (request.url.path.contains('/storage/v1/object/')) {
          return http.Response.bytes(fakeBytes, 200);
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.restoreFromCloud(
        userId: 'user-xyz',
        localCacheDir: tempCacheDir,
      );

      expect(result.success, isTrue);
      expect(result.expenses.length, equals(1));
      final restoredExp = result.expenses.first;
      expect(restoredExp.receiptPath,
          equals('${tempCacheDir.path}/exp-cloud-99.webp'));

      final cachedFile = File(restoredExp.receiptPath!);
      expect(cachedFile.existsSync(), isTrue);
      expect(cachedFile.readAsBytesSync(), equals(fakeBytes));

      tempCacheDir.deleteSync(recursive: true);
    });

    test(
        'syncJobSitesToCloud serializes job sites with userToken and conforms to job_sites table',
        () async {
      String? capturedAuthHeader;
      List<dynamic>? capturedPayload;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('job_sites')) {
          capturedAuthHeader = request.headers['Authorization'];
          capturedPayload = jsonDecode(request.body) as List<dynamic>;
          return http.Response(jsonEncode(capturedPayload), 201);
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final testJobSites = [
        JobSite(
          id: 'poi-sydney-01',
          name: 'Sydney Opera House Restoration',
          clientName: 'NSW Public Works',
          projectCode: 'NSW-PW-2026',
          address: 'Bennelong Point, Sydney NSW 2000',
          latitude: -33.8568,
          longitude: 151.2153,
          radiusMeters: 200.0,
          isActive: true,
        ),
      ];

      final result = await syncService.syncJobSitesToCloud(
        jobSites: testJobSites,
        userToken: 'user_jwt_token_jobsite',
        userId: 'user-tradie-101',
      );

      expect(result.success, isTrue);
      expect(capturedAuthHeader, equals('Bearer user_jwt_token_jobsite'));
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!.length, equals(1));

      final item = capturedPayload!.first as Map<String, dynamic>;
      expect(
          item['id'],
          equals(
              SyncEngineService.cloudId('poi-sydney-01', 'user-tradie-101')));
      expect(item['local_id'], equals('poi-sydney-01'));
      expect(item['user_id'], equals('user-tradie-101'));
      expect(item['name'], equals('Sydney Opera House Restoration'));
      expect(item['client_name'], equals('NSW Public Works'));
      expect(item['project_code'], equals('NSW-PW-2026'));
      expect(item['address'], equals('Bennelong Point, Sydney NSW 2000'));
      expect(item['latitude'], equals(-33.8568));
      expect(item['longitude'], equals(151.2153));
      expect(item['radius_meters'], equals(200.0));
      expect(item['is_active'], isTrue);
    });

    test('restoreFromCloud parses and restores job sites', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('job_sites')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'poi-restored-01',
                'user_id': 'user-101',
                'name': 'Barangaroo Site A',
                'client_name': 'Lendlease',
                'project_code': 'LL-BAR-01',
                'address': 'Barangaroo Ave, Sydney',
                'latitude': -33.8640,
                'longitude': 151.2010,
                'radius_meters': 150.0,
                'is_active': true,
                'created_at': '2026-10-01T08:00:00.000',
                'updated_at': '2026-10-01T08:00:00.000',
              }
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final syncService = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test_anon_key',
        httpClient: mockClient,
      );

      final result = await syncService.restoreFromCloud(
        userId: 'user-101',
      );

      expect(result.success, isTrue);
      expect(result.jobSites.length, equals(1));
      expect(result.jobSites.first.id, equals('poi-restored-01'));
      expect(result.jobSites.first.name, equals('Barangaroo Site A'));
      expect(result.jobSites.first.radiusMeters, equals(150.0));
    });

    test(
        'AppState cascade unlinks expenses on deleteTrip and cleans linkedExpenseIds on deleteExpense',
        () {
      final appState = AppState();

      final trip1 = Trip(
        id: 'trip-cascade-01',
        vehicleId: 'veh-123',
        distanceKm: 30.0,
        date: DateTime(2026, 11, 8, 8, 0),
        purpose: 'Morning Site Visit',
        classification: TripClassification.business,
      );

      final trip2 = Trip(
        id: 'trip-cascade-02',
        vehicleId: 'veh-123',
        distanceKm: 15.0,
        date: DateTime(2026, 11, 8, 14, 0),
        purpose: 'Afternoon Supplier Run',
        classification: TripClassification.business,
      );

      final expense1 = VehicleExpense(
        id: 'exp-cascade-01',
        vehicleId: 'veh-123',
        amount: 55.0,
        category: ExpenseCategory.fuel,
        date: DateTime(2026, 11, 8, 8, 30),
        linkedTripId: 'trip-cascade-01',
      );

      final expense2 = VehicleExpense(
        id: 'exp-cascade-02',
        vehicleId: 'veh-123',
        amount: 120.0,
        category: ExpenseCategory.toolsMaterials,
        date: DateTime(2026, 11, 8, 14, 30),
        linkedTripId: 'trip-cascade-02',
      );

      appState.recordTrip(trip1);
      appState.recordTrip(trip2);
      appState.recordExpense(expense1);
      appState.recordExpense(expense2);

      // Verify initial bidirectional linkages
      expect(
          appState.expenses
              .firstWhere((e) => e.id == 'exp-cascade-01')
              .linkedTripId,
          equals('trip-cascade-01'));
      expect(
          appState.trips
              .firstWhere((t) => t.id == 'trip-cascade-01')
              .linkedExpenseIds,
          contains('exp-cascade-01'));

      expect(
          appState.expenses
              .firstWhere((e) => e.id == 'exp-cascade-02')
              .linkedTripId,
          equals('trip-cascade-02'));
      expect(
          appState.trips
              .firstWhere((t) => t.id == 'trip-cascade-02')
              .linkedExpenseIds,
          contains('exp-cascade-02'));

      // 1. Delete trip1 -> Expense1 must have linkedTripId cleared to null
      appState.deleteTrip('trip-cascade-01');
      expect(appState.trips.any((t) => t.id == 'trip-cascade-01'), isFalse);
      final unlinkedExp =
          appState.expenses.firstWhere((e) => e.id == 'exp-cascade-01');
      expect(unlinkedExp.linkedTripId, isNull);

      // Ensure unaffected trip and expense remain intact
      expect(
          appState.trips
              .firstWhere((t) => t.id == 'trip-cascade-02')
              .linkedExpenseIds,
          contains('exp-cascade-02'));
      expect(
          appState.expenses
              .firstWhere((e) => e.id == 'exp-cascade-02')
              .linkedTripId,
          equals('trip-cascade-02'));

      // 2. Delete expense2 -> Trip2 must have 'exp-cascade-02' removed from linkedExpenseIds
      appState.deleteExpense('exp-cascade-02');
      expect(appState.expenses.any((e) => e.id == 'exp-cascade-02'), isFalse);
      final updatedTrip2 =
          appState.trips.firstWhere((t) => t.id == 'trip-cascade-02');
      expect(updatedTrip2.linkedExpenseIds, isNot(contains('exp-cascade-02')));
    });
  });
}
