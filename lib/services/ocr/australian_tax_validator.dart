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
