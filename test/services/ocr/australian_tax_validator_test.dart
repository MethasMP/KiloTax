import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/ocr/australian_tax_validator.dart';

void main() {
  group('AustralianTaxValidator - ABN Modulus-89 Validation', () {
    test('validates known real Australian business ABNs with various formats', () {
      // Bunnings Group Limited: 26 008 672 179
      expect(AustralianTaxValidator.isValidAbn('26 008 672 179'), isTrue);
      expect(AustralianTaxValidator.isValidAbn('26008672179'), isTrue);
      expect(AustralianTaxValidator.isValidAbn('26-008-672-179'), isTrue);

      // Australian Taxation Office: 51 824 753 556
      expect(AustralianTaxValidator.isValidAbn('51 824 753 556'), isTrue);
      expect(AustralianTaxValidator.isValidAbn('51824753556'), isTrue);

      // Woolworths Group Limited: 88 000 014 675
      expect(AustralianTaxValidator.isValidAbn('88 000 014 675'), isTrue);

      // Telstra Corporation Limited: 33 051 775 556
      expect(AustralianTaxValidator.isValidAbn('33 051 775 556'), isTrue);

      // Commonwealth Bank of Australia: 48 123 123 124
      expect(AustralianTaxValidator.isValidAbn('48 123 123 124'), isTrue);
    });

    test('rejects invalid ABNs failing Mod-89 check', () {
      // 1 off checksum from Bunnings
      expect(AustralianTaxValidator.isValidAbn('26 008 672 178'), isFalse);
      expect(AustralianTaxValidator.isValidAbn('26 008 672 170'), isFalse);

      // Arbitrary 11-digit numbers (like phone numbers with country code or invoice numbers)
      expect(AustralianTaxValidator.isValidAbn('61412345678'), isFalse);
      expect(AustralianTaxValidator.isValidAbn('12345678901'), isFalse);
      expect(AustralianTaxValidator.isValidAbn('11111111111'), isFalse);
      expect(AustralianTaxValidator.isValidAbn('00000000000'), isFalse);
    });

    test('rejects strings with incorrect length or non-numeric characters', () {
      expect(AustralianTaxValidator.isValidAbn(''), isFalse);
      expect(AustralianTaxValidator.isValidAbn('1234567890'), isFalse); // 10 digits
      expect(AustralianTaxValidator.isValidAbn('123456789012'), isFalse); // 12 digits
      expect(AustralianTaxValidator.isValidAbn('26 008 672 17A'), isFalse);
      expect(AustralianTaxValidator.isValidAbn('ABN 26 008 672 179'), isTrue); // handles prefix if stripped or cleaned
    });
  });

  group('AustralianTaxValidator - GST Cross-Validation', () {
    test('confirms GST is consistent when Total is approx 11 * GST', () {
      // 10% GST on $100 ex-tax = $10 GST, $110 Total
      expect(AustralianTaxValidator.isGstConsistent(110.0, 10.0), isTrue);

      // Real receipt values: $55.00 total -> $5.00 GST
      expect(AustralianTaxValidator.isGstConsistent(55.00, 5.00), isTrue);

      // $14.30 total -> $1.30 GST
      expect(AustralianTaxValidator.isGstConsistent(14.30, 1.30), isTrue);

      // Rounding tolerance edge cases (e.g. $10.00 total -> $0.91 GST: 0.91 * 11 = 10.01)
      expect(AustralianTaxValidator.isGstConsistent(10.00, 0.91), isTrue);

      // $99.95 total -> $9.09 GST: 9.09 * 11 = 99.99 (diff 0.04 <= 0.05 tolerance)
      expect(AustralianTaxValidator.isGstConsistent(99.95, 9.09), isTrue);
    });

    test('rejects inconsistent GST and Total values', () {
      // Obvious mismatch
      expect(AustralianTaxValidator.isGstConsistent(100.0, 50.0), isFalse);
      expect(AustralianTaxValidator.isGstConsistent(100.0, 0.0), isFalse);
      expect(AustralianTaxValidator.isGstConsistent(0.0, 10.0), isFalse);

      // Negative values
      expect(AustralianTaxValidator.isGstConsistent(-110.0, -10.0), isFalse);
      expect(AustralianTaxValidator.isGstConsistent(110.0, -10.0), isFalse);

      // Total smaller than GST
      expect(AustralianTaxValidator.isGstConsistent(10.0, 15.0), isFalse);

      // Beyond tolerance
      expect(AustralianTaxValidator.isGstConsistent(110.0, 9.80, tolerance: 0.05), isFalse);
    });

    test('supports custom tolerance parameter', () {
      expect(AustralianTaxValidator.isGstConsistent(100.0, 9.0, tolerance: 1.5), isTrue);
      expect(AustralianTaxValidator.isGstConsistent(100.0, 9.0, tolerance: 0.01), isFalse);
    });
  });

  group('AustralianTaxValidator - Mathematical Deductions', () {
    test('deduceTotalFromGst calculates expected total from GST', () {
      expect(AustralianTaxValidator.deduceTotalFromGst(10.0), closeTo(110.0, 0.001));
      expect(AustralianTaxValidator.deduceTotalFromGst(5.0), closeTo(55.0, 0.001));
      expect(AustralianTaxValidator.deduceTotalFromGst(1.30), closeTo(14.30, 0.001));
      expect(AustralianTaxValidator.deduceTotalFromGst(0.91), closeTo(10.01, 0.001));
    });

    test('deduceTotalFromGst returns null for non-positive values', () {
      expect(AustralianTaxValidator.deduceTotalFromGst(0.0), isNull);
      expect(AustralianTaxValidator.deduceTotalFromGst(-10.0), isNull);
    });

    test('deduceGstFromTotal calculates expected GST from gross Total (Total / 11)', () {
      expect(AustralianTaxValidator.deduceGstFromTotal(110.0), closeTo(10.0, 0.001));
      expect(AustralianTaxValidator.deduceGstFromTotal(55.0), closeTo(5.0, 0.001));
      expect(AustralianTaxValidator.deduceGstFromTotal(14.30), closeTo(1.30, 0.001));
      expect(AustralianTaxValidator.deduceGstFromTotal(10.00), closeTo(0.909, 0.01));
    });

    test('deduceGstFromTotal returns null for non-positive values', () {
      expect(AustralianTaxValidator.deduceGstFromTotal(0.0), isNull);
      expect(AustralianTaxValidator.deduceGstFromTotal(-110.0), isNull);
    });
  });
}
