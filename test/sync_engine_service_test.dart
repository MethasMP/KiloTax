import 'dart:convert';
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

    test('syncToCloud includes userToken in Authorization header and userId in payloads', () async {
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
      expect((capturedTripPayload?.first as Map<String, dynamic>)['user_id'], equals('user-uuid-999'));
      expect((capturedExpensePayload?.first as Map<String, dynamic>)['user_id'], equals('user-uuid-999'));
    });

    test('syncToCloud falls back to anonKey in Authorization header when userToken is omitted', () async {
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

    test('restoreFromCloud filters queries by user_id and passes userToken', () async {
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
      expect(requestedAuthHeaders.every((h) => h == 'Bearer jwt_restore_token'), isTrue);
      expect(requestedUrls.any((u) => u.contains('vehicles') && u.contains('user_id=eq.taxpayer-123')), isTrue);
      expect(requestedUrls.any((u) => u.contains('trips') && u.contains('user_id=eq.taxpayer-123')), isTrue);
      expect(requestedUrls.any((u) => u.contains('expenses') && u.contains('user_id=eq.taxpayer-123')), isTrue);
    });
  });
}
