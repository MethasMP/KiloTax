import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../services/storage/local_storage_service.dart';

/// Official ATO Tax Legislation & Global Remote Compliance Engine
///
/// Ensures Cents-per-kilometre rates are always legally current without requiring
/// manual developer intervention or mobile app store updates.
///
/// Features:
/// 1. Offline-First: Statutory baseline in app binary ensures 100% operation in outback/zero-reception.
/// 2. Multi-tier Silent Sync:
///    - Tier 1: Canonical Global Supabase REST API (`ato_tax_rules`).
///    - Tier 2: Resilient CDN / GitHub Raw fallback.
///    - Tier 3: Local flash memory cache.
///    - Tier 4: Immutable statutory map compiled into Dart binary.
/// 3. Zero User Friction: Operates 100% silently in the background. Traps all network drops
///    gracefully without popping error dialogs or technical banners.
class TaxRuleService {
  static const String _remoteEndpoint =
      'https://raw.githubusercontent.com/kilotax/compliance-rules/main/ato_tax_rules.json';

  static const String _cacheKey = 'kilotax_cached_tax_rule_v1';
  static const String _cachedRatesKey = 'kilotax_cached_rates_map_v1';

  final LocalStorageService? _storageService;
  final http.Client _httpClient;
  final String _supabaseUrl;
  final String _anonKey;

  AtoTaxRule _currentRule;
  final Map<int, double> _syncedRatesByStartYear = {};

  TaxRuleService({
    LocalStorageService? storageService,
    http.Client? httpClient,
    String? supabaseUrl,
    String? anonKey,
  })  : _storageService = storageService,
        _httpClient = httpClient ?? http.Client(),
        _supabaseUrl = supabaseUrl ?? AppConstants.supabaseUrl,
        _anonKey = anonKey ?? AppConstants.supabaseAnonKey,
        _currentRule = AppConstants.activeTaxRule;

  AtoTaxRule get currentRule => _currentRule;

  /// Returns an unmodifiable map of all verified historical and active rates
  Map<int, double> get allKnownRates =>
      Map.unmodifiable(_syncedRatesByStartYear);

  /// Initialize and load cached tax rules from persistent storage or bundled JSON asset
  Future<void> init() async {
    // 1. Seed baseline rates from bundled JSON asset (No Dart code hardcoding)
    await _loadBaselineFromAsset();

    // 2. Load cached single active rule from flash storage
    final cachedJson = _storageService?.loadRawString(_cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        _currentRule = AtoTaxRule.fromJson(data);
      } catch (e, stack) {
        debugPrint(
            '[TaxRuleService] Warning parsing cached single rule: $e\n$stack');
        _currentRule = AppConstants.activeTaxRule;
      }
    }

    // 3. Load cached synced rate map from flash storage
    final cachedRatesJson = _storageService?.loadRawString(_cachedRatesKey);
    if (cachedRatesJson != null && cachedRatesJson.isNotEmpty) {
      try {
        final ratesMap = jsonDecode(cachedRatesJson) as Map<String, dynamic>;
        for (final entry in ratesMap.entries) {
          final year = int.tryParse(entry.key);
          final rate = (entry.value as num?)?.toDouble();
          if (year != null && rate != null && rate >= 0.50 && rate <= 2.00) {
            _syncedRatesByStartYear[year] = rate;
          }
        }
      } catch (e, stack) {
        debugPrint(
            '[TaxRuleService] Warning parsing cached rate map: $e\n$stack');
      }
    }
  }

  Future<void> _loadBaselineFromAsset() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/ato_rates_baseline.json');
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final startYear = (item['startYear'] as num?)?.toInt();
            final rate = (item['centsPerKmRate'] as num?)?.toDouble();
            if (startYear != null && rate != null) {
              _syncedRatesByStartYear.putIfAbsent(startYear, () => rate);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TaxRuleService] Note: rootBundle baseline bypassed or unavailable in environment: $e');
    }
  }

  /// Silently fetch latest official rates from Global Cloud (Supabase) or Secondary CDN
  /// Never throws, never disrupts UI, and operates 100% in the background.
  Future<bool> syncLatestOfficialRates() async {
    // Tier 1: Query Global Supabase REST API
    try {
      final supabaseUri = Uri.parse(
          '$_supabaseUrl/rest/v1/ato_tax_rules?select=*&order=start_year.desc');
      final response = await _httpClient.get(
        supabaseUri,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
        if (rows.isNotEmpty) {
          bool updatedActiveRule = false;
          for (final item in rows) {
            if (item is Map<String, dynamic>) {
              final rule = AtoTaxRule.fromJson(item);
              final startYear = (item['start_year'] as num?)?.toInt() ??
                  _extractStartYearFromFy(rule.financialYear);

              if (startYear != null &&
                  rule.centsPerKmRate >= 0.50 &&
                  rule.centsPerKmRate <= 2.00) {
                _syncedRatesByStartYear[startYear] = rule.centsPerKmRate;

                // Mark active rule or take newest verified rule
                final isActive = item['is_active'] == true;
                if (isActive || !updatedActiveRule) {
                  _currentRule = rule;
                  updatedActiveRule = true;
                }
              }
            }
          }

          // Persist to local flash storage for instant offline access
          await _storageService?.saveRawString(
              _cacheKey, jsonEncode(_currentRule.toJson()));
          final stringKeyMap =
              _syncedRatesByStartYear.map((k, v) => MapEntry(k.toString(), v));
          await _storageService?.saveRawString(
              _cachedRatesKey, jsonEncode(stringKeyMap));
          return true;
        }
      }
    } catch (e) {
      debugPrint('[TaxRuleService] Silent Supabase sync bypassed: $e');
    }

    // Tier 2: Resilient CDN / GitHub Raw fallback
    try {
      final response = await _httpClient
          .get(Uri.parse(_remoteEndpoint))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final newRule = AtoTaxRule.fromJson(decoded);
          if (newRule.centsPerKmRate >= 0.50 &&
              newRule.centsPerKmRate <= 2.00) {
            _currentRule = newRule;
            final startYear = _extractStartYearFromFy(newRule.financialYear);
            if (startYear != null) {
              _syncedRatesByStartYear[startYear] = newRule.centsPerKmRate;
            }

            await _storageService?.saveRawString(_cacheKey, response.body);
            final stringKeyMap = _syncedRatesByStartYear
                .map((k, v) => MapEntry(k.toString(), v));
            await _storageService?.saveRawString(
                _cachedRatesKey, jsonEncode(stringKeyMap));
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[TaxRuleService] Silent CDN fallback bypassed: $e');
    }

    // Tier 3 & 4: Completely offline - gracefully rely on cached memory and statutory baseline
    return false;
  }

  /// Returns the exact statutory ATO rate for any given expense or trip date.
  /// Dynamically resolves against synced rates, falling back to active rule.
  double getRateForDate(DateTime date) {
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    if (_syncedRatesByStartYear.containsKey(startYear)) {
      return _syncedRatesByStartYear[startYear]!;
    }
    // Fallback to active rule
    return _currentRule.centsPerKmRate;
  }

  /// Returns the integer cents per km (e.g. 85, 88, 91) for clean UI display.
  int getRateCentsForDate(DateTime date) =>
      (getRateForDate(date) * 100).round();

  static int? _extractStartYearFromFy(String fy) {
    final match = RegExp(r'(\d{4})').firstMatch(fy);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
