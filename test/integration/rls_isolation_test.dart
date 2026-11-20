import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Squad Delta - Task D1: Supabase RLS Cross-User Isolation Test', () {
    const supabaseUrl = 'http://127.0.0.1:54321';
    const restEndpoint = '$supabaseUrl/rest/v1';
    const authAdminEndpoint = '$supabaseUrl/auth/v1/admin/users';
    const jwtSecret = 'super-secret-jwt-token-with-at-least-32-characters-long';
    const serviceRoleKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
    const anonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

    const userAId = '11111111-1111-1111-1111-111111111111';
    const userBId = '22222222-2222-2222-2222-222222222222';
    const vehicleAId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const tripAId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    const evidenceLinkId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

    String base64UrlNoPadding(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    String createJwt({
      required String userId,
      required String secret,
      String role = 'authenticated',
    }) {
      final header = base64UrlNoPadding(
        utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})),
      );
      final payload = base64UrlNoPadding(
        utf8.encode(json.encode({
          'sub': userId,
          'role': role,
          'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
          'iss': 'supabase-demo',
        })),
      );
      final hmac = Hmac(sha256, utf8.encode(secret));
      final digest = hmac.convert(utf8.encode('$header.$payload'));
      final signature = base64UrlNoPadding(digest.bytes);
      return '$header.$payload.$signature';
    }

    final tokenA = createJwt(userId: userAId, secret: jwtSecret);
    final tokenB = createJwt(userId: userBId, secret: jwtSecret);

    setUpAll(() async {
      // 1. Ensure test users exist in Supabase Auth via GoTrue Admin API
      for (final user in [
        {'id': userAId, 'email': 'user_a_rls@example.com'},
        {'id': userBId, 'email': 'user_b_rls@example.com'},
      ]) {
        await http.post(
          Uri.parse(authAdminEndpoint),
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': 'Bearer $serviceRoleKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'id': user['id'],
            'email': user['email'],
            'password': 'Password123!',
            'email_confirm': true,
          }),
        );
      }

      // 2. Clean up any existing link from previous runs
      await http.delete(
        Uri.parse('$restEndpoint/trip_evidence_links?id=eq.$evidenceLinkId'),
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
        },
      );

      // 3. Upsert Vehicle for User A
      await http.post(
        Uri.parse('$restEndpoint/vehicles'),
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: json.encode({
          'id': vehicleAId,
          'user_id': userAId,
          'make': 'Toyota',
          'model': 'Hilux',
          'rego_plate': 'TRADIE1',
          'initial_odometer': 10000,
          'tax_method': 'logbook',
        }),
      );

      // 4. Upsert Trip for User A
      await http.post(
        Uri.parse('$restEndpoint/trips'),
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: json.encode({
          'id': tripAId,
          'user_id': userAId,
          'vehicle_id': vehicleAId,
          'date': '2026-11-20T08:00:00Z',
          'distance_km': 45.2,
          'purpose': 'Subcontractor site inspection',
          'classification': 'business',
          'tax_method': 'logbook',
          'evidence_source': 'auto_telemetry',
        }),
      );

      // 5. Seed Trip Evidence Link for User A
      final linkRes = await http.post(
        Uri.parse('$restEndpoint/trip_evidence_links'),
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': 'Bearer $serviceRoleKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: json.encode({
          'id': evidenceLinkId,
          'user_id': userAId,
          'trip_id': tripAId,
          'confidence_score': 0.98,
          'association_method': 'manual_user',
        }),
      );
      expect(linkRes.statusCode, anyOf([200, 201]));
    });

    test('User A can query and view their own trip_evidence_link', () async {
      final response = await http.get(
        Uri.parse('$restEndpoint/trip_evidence_links?id=eq.$evidenceLinkId'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $tokenA',
        },
      );

      expect(response.statusCode, equals(200));
      final rows = json.decode(response.body) as List<dynamic>;
      expect(rows.length, equals(1));
      expect(rows.first['id'], equals(evidenceLinkId));
      expect(rows.first['user_id'], equals(userAId));
    });

    test('RLS ISOLATION: User B token queries same table; assert 0 rows returned (no cross-user leak)', () async {
      final response = await http.get(
        Uri.parse('$restEndpoint/trip_evidence_links'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $tokenB',
        },
      );

      expect(response.statusCode, equals(200));
      final rows = json.decode(response.body) as List<dynamic>;
      expect(rows, isEmpty, reason: 'RLS must not leak User A trip_evidence_links to User B');
    });

    test('RLS ISOLATION: User B querying specifically for User A link ID returns 0 rows', () async {
      final response = await http.get(
        Uri.parse('$restEndpoint/trip_evidence_links?id=eq.$evidenceLinkId'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $tokenB',
        },
      );

      expect(response.statusCode, equals(200));
      final rows = json.decode(response.body) as List<dynamic>;
      expect(rows, isEmpty, reason: 'Targeted ID probe by User B must yield 0 rows');
    });

    test('RLS ISOLATION: User B attempting DELETE on User A link has no effect', () async {
      final deleteResponse = await http.delete(
        Uri.parse('$restEndpoint/trip_evidence_links?id=eq.$evidenceLinkId'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $tokenB',
          'Prefer': 'return=representation',
        },
      );

      expect(deleteResponse.statusCode, anyOf([200, 204]));
      if (deleteResponse.body.isNotEmpty) {
        final deletedRows = json.decode(deleteResponse.body) as List<dynamic>;
        expect(deletedRows, isEmpty, reason: 'User B must not be able to delete User A link');
      }

      // Verify User A link is still intact
      final verifyResponse = await http.get(
        Uri.parse('$restEndpoint/trip_evidence_links?id=eq.$evidenceLinkId'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $tokenA',
        },
      );
      final rows = json.decode(verifyResponse.body) as List<dynamic>;
      expect(rows.length, equals(1), reason: 'Link must remain intact after unauthorized delete attempt');
    });

    test('Anonymous unauthenticated request returns 0 rows', () async {
      final response = await http.get(
        Uri.parse('$restEndpoint/trip_evidence_links'),
        headers: {
          'apikey': anonKey,
        },
      );

      expect(response.statusCode, equals(200));
      final rows = json.decode(response.body) as List<dynamic>;
      expect(rows, isEmpty, reason: 'Unauthenticated requests must see 0 rows');
    });
  });
}
