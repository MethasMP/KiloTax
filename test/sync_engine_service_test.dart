import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';

void main() {
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
      expect(result.errorMessage,
          contains('2 remote records were corrupted or unparseable.'));
    });

    test('syncToCloud syncs both business and personal trips with privacy masking', () async {
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

      final bizJson = capturedTrips!.firstWhere((t) => t['id'] == 'biz-1');
      expect(bizJson['classification'], equals('business'));
      expect(bizJson['purpose'], equals('Client Consultation'));
      expect(bizJson['origin_address'], equals('Office Headquarters'));
      expect(bizJson['destination_address'], equals('Client Office'));

      final persJson = capturedTrips!.firstWhere((t) => t['id'] == 'pers-1');
      expect(persJson['classification'], equals('personal'));
      expect(persJson['purpose'], equals('Personal'));
      expect(persJson['origin_address'], equals('Personal Location'));
      expect(persJson['destination_address'], equals('Personal Destination'));
      expect(persJson['start_odometer'], equals(1015.0));
      expect(persJson['end_odometer'], equals(1020.0));
    });

    test('syncToCloud uploads local receipt image and updates receipt_storage_path to cloud path', () async {
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
      expect(uploadedPaths.first, contains('receipts/user-abc/exp-receipt-1.webp'));

      expect(capturedExpenses?.length, equals(1));
      final expPayload = capturedExpenses!.first as Map<String, dynamic>;
      expect(expPayload['receipt_storage_path'], equals('user-abc/exp-receipt-1.webp'));

      tempDir.deleteSync(recursive: true);
    });

    test('restoreFromCloud downloads remote receipt and caches to local directory', () async {
      final tempCacheDir = Directory.systemTemp.createTempSync('cache_restore_');
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
      expect(restoredExp.receiptPath, equals('${tempCacheDir.path}/exp-cloud-99.webp'));

      final cachedFile = File(restoredExp.receiptPath!);
      expect(cachedFile.existsSync(), isTrue);
      expect(cachedFile.readAsBytesSync(), equals(fakeBytes));

      tempCacheDir.deleteSync(recursive: true);
    });
  });
}
