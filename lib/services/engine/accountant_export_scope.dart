import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../state/app_state.dart';

/// Exact-year settings for report generation; never substitutes this year's
/// rate for an unavailable historical year or changes the active app scope.
class AccountantExportScope {
  static String normalizeYear(String year) => year.replaceAll('–', '-');

  static Future<Map<String, AtoTaxRule>> loadRules(AppState state) async {
    final rules = <String, AtoTaxRule>{};
    try {
      final rows = jsonDecode(await rootBundle.loadString(
          'assets/data/ato_rates_baseline.json',
          cache: false)) as List;
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        if (row['financialYear'] == null ||
            row['centsPerKmRate'] == null ||
            row['centsPerKmMaxKm'] == null ||
            row['carDepreciationLimit'] == null) {
          continue;
        }
        final rule = AtoTaxRule.fromJson(row);
        rules[normalizeYear(rule.financialYear)] = rule;
      }
    } catch (_) {
      // The active rule remains usable; missing historical rules are explicit.
    }
    final active = state.activeTaxRule;
    rules[normalizeYear(active.financialYear)] = active;
    return rules;
  }
}
