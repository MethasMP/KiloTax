import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/engine/tax_rule_service.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Simulate Future Year: Cloud returns FY 2027-28 with 95c without touching Dart code',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);

    // Mock response from Cloud (Supabase) when ATO announces new FY 2027-28 rate (e.g. 95c)
    final mockSupabaseData = [
      {
        'financial_year': '2027-28',
        'start_year': 2027,
        'cents_per_km_rate': 0.95,
        'cents_per_km_max_km': 5000.0,
        'car_depreciation_limit': 71000.0,
        'is_active': true,
      },
      {
        'financial_year': '2026-27',
        'start_year': 2026,
        'cents_per_km_rate': 0.91,
        'cents_per_km_max_km': 5000.0,
        'car_depreciation_limit': 69674.0,
        'is_active': false,
      }
    ];

    final client = MockClient((request) async {
      if (request.url.toString().contains('ato_tax_rules')) {
        return http.Response(jsonEncode(mockSupabaseData), 200);
      }
      return http.Response('Not Found', 404);
    });

    final service = TaxRuleService(
      storageService: storage,
      httpClient: client,
    );
    await service.init();

    // 1. Before sync, rate is initial active rule
    expect(service.currentRule.centsPerKmRate, equals(0.91));

    // 2. Perform background sync from Cloud
    final updated = await service.syncLatestOfficialRates();
    expect(updated, isTrue);

    // 3. Rate automatically transitions to new FY 2027-28 rate (95c) and $4,750 max claim
    expect(service.currentRule.financialYear, equals('2027-28'));
    expect(service.currentRule.centsPerKmRate, equals(0.95));
    expect(service.currentRule.maxCentsPerKmClaim, equals(4750.0)); // 5000 * 0.95

    // 4. Querying a trip date in FY 2027-28 returns 95c
    final tripIn2027 = DateTime(2027, 8, 15);
    expect(service.getRateCentsForDate(tripIn2027), equals(95));
  });
}
