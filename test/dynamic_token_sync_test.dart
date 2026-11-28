import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/services/auth/supabase_auth_service.dart';
import 'package:kiloclaim/services/sync/sync_engine_service.dart';

class MockHttpClient extends http.BaseClient {
  String? lastAuthHeader;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastAuthHeader = request.headers['Authorization'];
    return http.StreamedResponse(
      Stream.value('[]'.codeUnits),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('PR-13: Dynamic JWT Access Token Streaming', () {
    test('SyncEngineService dynamically retrieves latest token from tokenProvider', () async {
      String? dynamicToken = 'token_initial_123';
      final mockHttp = MockHttpClient();

      final syncService = SyncEngineService(
        httpClient: mockHttp,
        tokenProvider: () => dynamicToken,
      );

      expect(syncService.currentAccessToken, equals('token_initial_123'));
      expect(syncService.isAuthenticated, isTrue);

      // Mutate token dynamically (as happens after token refresh)
      dynamicToken = 'token_refreshed_456';
      expect(syncService.currentAccessToken, equals('token_refreshed_456'));

      final vehicle = Vehicle(
        id: 'v_sync',
        regoPlate: 'SYNC-01',
        make: 'Ford',
        model: 'Ranger',
        initialOdometer: 50000.0,
      );

      await syncService.syncToCloud(
        vehicle: vehicle,
        trips: [],
        expenses: [],
      );

      expect(mockHttp.lastAuthHeader, equals('Bearer token_refreshed_456'));
    });

    test('SyncEngineService falls back to currentUser accessToken when tokenProvider is null', () {
      final user = AuthUser(
        id: 'u_1',
        email: 'user@example.com',
        provider: 'email',
        accessToken: 'fallback_token_789',
      );

      final syncService = SyncEngineService(currentUser: user);
      expect(syncService.currentAccessToken, equals('fallback_token_789'));
    });
  });
}
