import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/engine/tax_rule_service.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaxRuleService - Dynamic Statutory Rate Lookup by Financial Year', () {
    late TaxRuleService service;

    setUp(() {
      service = TaxRuleService();
    });

    test('Returns 85c for FY 2023-24 dates (1 Jul 2023 - 30 Jun 2024)', () {
      final date1 = DateTime(2023, 7, 1);
      final date2 = DateTime(2023, 11, 15);
      final date3 = DateTime(2024, 6, 30);

      expect(service.getRateForDate(date1), equals(0.85));
      expect(service.getRateForDate(date2), equals(0.85));
      expect(service.getRateForDate(date3), equals(0.85));

      expect(service.getRateCentsForDate(date1), equals(85));
      expect(service.getRateCentsForDate(date2), equals(85));
    });

    test('Returns 88c for FY 2024-25 dates (1 Jul 2024 - 30 Jun 2025)', () {
      final date1 = DateTime(2024, 7, 1);
      final date2 = DateTime(2024, 9, 14);
      final date3 = DateTime(2025, 6, 30);

      expect(service.getRateForDate(date1), equals(0.88));
      expect(service.getRateForDate(date2), equals(0.88));
      expect(service.getRateForDate(date3), equals(0.88));

      expect(service.getRateCentsForDate(date1), equals(88));
      expect(service.getRateCentsForDate(date2), equals(88));
    });

    test('Returns 78c for FY 2022-23 dates (1 Jul 2022 - 30 Jun 2023)', () {
      final date = DateTime(2022, 10, 10);
      expect(service.getRateForDate(date), equals(0.78));
      expect(service.getRateCentsForDate(date), equals(78));
    });
  });

  group('TaxRuleService - Cloud-First Multi-Tier Resilient Silent Sync', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Tier 1: Successfully syncs canonical rules from Global Supabase REST API', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final mockSupabaseData = [
        {
          'financial_year': '2026-27',
          'start_year': 2026,
          'cents_per_km_rate': 0.91,
          'cents_per_km_max_km': 5000.0,
          'car_depreciation_limit': 69674.0,
          'legislative_ref': 'ITAA 1997 s.28-25 / TD 2026/X',
          'is_active': true,
        },
        {
          'financial_year': '2025-26',
          'start_year': 2025,
          'cents_per_km_rate': 0.88,
          'cents_per_km_max_km': 5000.0,
          'car_depreciation_limit': 69674.0,
          'legislative_ref': 'ITAA 1997 s.28-25 / TD 2024/6',
          'is_active': false,
        }
      ];

      final client = MockClient((request) async {
        if (request.url.path.contains('ato_tax_rules')) {
          return http.Response(jsonEncode(mockSupabaseData), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = TaxRuleService(
        storageService: storage,
        httpClient: client,
      );

      final success = await service.syncLatestOfficialRates();
      expect(success, isTrue);

      // Active rule should now be 2026-27 with 91c
      expect(service.currentRule.financialYear, equals('2026-27'));
      expect(service.currentRule.centsPerKmRate, equals(0.91));

      // Querying date in FY 2026-27 should return 91c
      final date2026 = DateTime(2026, 8, 1);
      expect(service.getRateCentsForDate(date2026), equals(91));

      // Should be saved into local storage cache
      final cachedJson = storage.loadRawString('kilotax_cached_tax_rule_v1');
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('2026-27'));
    });

    test('Tier 2: Falls back to secondary CDN when Supabase is down or fails', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final mockCdnData = {
        'financialYear': '2026-27',
        'centsPerKmRate': 0.91,
        'centsPerKmMaxKm': 5000.0,
        'carDepreciationLimit': 69674.0,
      };

      final client = MockClient((request) async {
        if (request.url.host.contains('supabase.co')) {
          // Supabase throws error
          return http.Response('Internal Server Error', 500);
        }
        if (request.url.host.contains('githubusercontent.com')) {
          // Secondary CDN succeeds
          return http.Response(jsonEncode(mockCdnData), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = TaxRuleService(
        storageService: storage,
        httpClient: client,
      );

      final success = await service.syncLatestOfficialRates();
      expect(success, isTrue);
      expect(service.currentRule.centsPerKmRate, equals(0.91));
    });

    test('Tier 3 & 4: 100% Silent Offline Operation - Never crashes or throws exceptions', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      // Client throws network connection errors (simulating zero outback reception)
      final client = MockClient((request) async {
        throw http.ClientException('Network unreachable (no cellular data)');
      });

      final service = TaxRuleService(
        storageService: storage,
        httpClient: client,
      );

      // Must complete safely without throwing any uncaught exception
      final success = await service.syncLatestOfficialRates();
      expect(success, isFalse);

      // Historical calculation still works 100% using immutable binary map
      final tripDate2024 = DateTime(2024, 10, 15);
      expect(service.getRateCentsForDate(tripDate2024), equals(88));

      final tripDate2023 = DateTime(2023, 9, 1);
      expect(service.getRateCentsForDate(tripDate2023), equals(85));
    });
  });
}
