/// Australian Tax & ABN Modulus-89 Algorithmic Engine.
///
/// Implements ATO specifications for:
/// 1. ABN (Australian Business Number) validation using the ATO Modulus-89 algorithm.
/// 2. Mathematical consistency validation between GST and Gross Total (ATO standard 10% GST, Total = 11 * GST).
/// 3. Mathematical deduction of Total from GST and GST from Total.
class AustralianTaxValidator {
  const AustralianTaxValidator._();

  /// The official ATO weighting factors for each of the 11 digits in an ABN.
  static const List<int> _abnWeights = [
    10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19,
  ];

  /// Validates an Australian Business Number (ABN) using the official ATO Modulus-89 algorithm.
  ///
  /// Steps:
  /// 1. Strip non-digit characters.
  /// 2. Check length is exactly 11 digits.
  /// 3. Subtract 1 from the first digit.
  /// 4. Multiply each digit by its corresponding ATO weighting factor.
  /// 5. Sum the products.
  /// 6. Divide the sum by 89. If the remainder is 0, the ABN is valid.
  static bool isValidAbn(String? rawAbn) {
    if (rawAbn == null || rawAbn.trim().isEmpty) {
      return false;
    }

    // Strip any non-digit characters (spaces, hyphens, prefixes like "ABN")
    final digitsOnly = rawAbn.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length != 11) {
      return false;
    }

    final digits = digitsOnly.split('').map(int.parse).toList();

    // Subtract 1 from the first digit
    digits[0] -= 1;

    var sum = 0;
    for (var i = 0; i < 11; i++) {
      sum += digits[i] * _abnWeights[i];
    }

    return sum % 89 == 0;
  }

  /// Attempts to auto-repair common OCR optical misrecognitions in an 11-character string
  /// (such as 'O'/'D' -> '0', 'I'/'l' -> '1', 'B' -> '8', 'S' -> '5', 'Z' -> '2').
  ///
  /// If the repaired digits satisfy the ATO Modulus-89 algorithm, returns the valid 11-digit string.
  /// Otherwise, returns null.
  static String? repairOcrAbn(String? rawAbn) {
    if (rawAbn == null) return null;
    final cleaned = rawAbn
        .replaceAll(RegExp(r'^(?:abn|a\.b\.n|aust\w*\s+bus\w*\s+no\.?)\s*[:#]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s.-]'), '')
        .trim();

    if (cleaned.length != 11) return null;

    // Check if already valid
    if (isValidAbn(cleaned)) return cleaned;

    // Direct character substitution map for high-frequency OCR confusions
    final substitutions = <int, List<String>>{};
    for (var i = 0; i < 11; i++) {
      final ch = cleaned[i].toUpperCase();
      switch (ch) {
        case 'O':
        case 'D':
        case 'Q':
          substitutions[i] = ['0'];
          break;
        case 'I':
        case 'L':
        case '|':
        case '!':
          substitutions[i] = ['1'];
          break;
        case 'Z':
          substitutions[i] = ['2'];
          break;
        case 'E':
          substitutions[i] = ['3'];
          break;
        case 'A':
          substitutions[i] = ['4'];
          break;
        case 'S':
          substitutions[i] = ['5'];
          break;
        case 'G':
        case 'b':
          substitutions[i] = ['6'];
          break;
        case 'T':
          substitutions[i] = ['7'];
          break;
        case 'B':
          substitutions[i] = ['8'];
          break;
        case 'g':
        case 'q':
          substitutions[i] = ['9'];
          break;
      }
    }

    if (substitutions.isEmpty) {
      // If all are digits but mod89 failed, check single-digit error (Hamming distance 1)
      if (RegExp(r'^\d{11}$').hasMatch(cleaned)) {
        return _searchSingleDigitCorrection(cleaned);
      }
      return null;
    }

    // Replace characters with top candidate digits
    final chars = cleaned.toUpperCase().split('');
    for (final entry in substitutions.entries) {
      chars[entry.key] = entry.value.first;
    }
    final candidate = chars.join();
    if (isValidAbn(candidate)) {
      return candidate;
    }

    // If still failing, check single-digit error on candidate
    if (RegExp(r'^\d{11}$').hasMatch(candidate)) {
      return _searchSingleDigitCorrection(candidate);
    }

    return null;
  }

  static String? _searchSingleDigitCorrection(String elevenDigits) {
    // If only 1 digit was corrupted (e.g. 3 vs 8, 5 vs 6, 0 vs 8)
    const confusionPairs = {
      '0': ['8', '6', '9'],
      '1': ['7'],
      '2': ['7'],
      '3': ['8', '5'],
      '4': ['1'],
      '5': ['6', '3'],
      '6': ['8', '5', '0'],
      '7': ['1'],
      '8': ['0', '3', '6', '9'],
      '9': ['8', '0', '7'],
    };

    final chars = elevenDigits.split('');
    for (var i = 0; i < 11; i++) {
      final original = chars[i];
      final alternates = confusionPairs[original] ?? const [];
      for (final alt in alternates) {
        chars[i] = alt;
        final testCandidate = chars.join();
        if (isValidAbn(testCandidate)) {
          return testCandidate;
        }
      }
      chars[i] = original; // revert
    }
    return null;
  }

  /// Checks if the provided [total] and [gst] amounts are mathematically consistent
  /// with standard Australian 10% GST (where Gross Total = 11 * GST).
  ///
  /// Allows an absolute difference within [tolerance] (default 0.05) to accommodate
  /// standard rounding errors on line-item receipts.
  static bool isGstConsistent(
    double total,
    double gst, {
    double tolerance = 0.05,
  }) {
    if (total <= 0 || gst <= 0 || gst >= total) {
      return false;
    }

    final expectedTotal = gst * 11.0;
    return (total - expectedTotal).abs() <= tolerance;
  }

  /// Deduces the expected Gross Total from a known [gst] value.
  /// Returns null if [gst] is non-positive.
  static double? deduceTotalFromGst(double gst) {
    if (gst <= 0) return null;
    return gst * 11.0;
  }

  /// Deduces the expected GST from a known Gross [total] value (Total / 11).
  /// Returns null if [total] is non-positive.
  static double? deduceGstFromTotal(double total) {
    if (total <= 0) return null;
    return total / 11.0;
  }
}
