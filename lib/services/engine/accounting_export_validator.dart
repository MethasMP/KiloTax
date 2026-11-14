import '../../core/utils/csv_security.dart';

/// Validation result payload for accounting platform journal exports (Xero / MYOB).
class AccountingValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final double netBalance;
  final int transactionCount;

  const AccountingValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.netBalance,
    required this.transactionCount,
  });

  @override
  String toString() {
    return 'AccountingValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length}, netBalance: $netBalance, count: $transactionCount)';
  }
}

/// Boundary validator strictly adhering to Xero and MYOB import specifications.
/// Enforces principle-model-the-domain and principle-boundary-discipline.
class AccountingExportValidator {
  // Xero Australian specification: DD/MM/YYYY
  static final RegExp _xeroAuDateRegex =
      RegExp(r'^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/\d{4}$');

  // Amount format: optional negative sign followed by digits and exactly 2 decimal places
  static final RegExp _amountRegex = RegExp(r'^-?\d+(\.\d{2})$');

  /// Expected Xero Manual Journal header columns
  static const List<String> expectedXeroHeaders = [
    '*Narration',
    '*Date',
    '*Description',
    '*AccountCode',
    '*TaxType',
    '*Amount',
    'TrackingName1',
    'TrackingOption1',
  ];

  /// Validates a generated Xero Manual Journal CSV string.
  /// Throws [FormatException] if [throwOnError] is true and errors are encountered.
  static AccountingValidationResult validateXeroJournalCsv(
    String csvContent, {
    bool throwOnError = false,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    if (lines.isEmpty) {
      errors.add('CSV content is completely empty.');
      return _buildResult(errors, warnings, 0.0, 0, throwOnError);
    }

    // 1. Validate Header
    final headerLine = lines.first;
    final headers = _parseCsvLine(headerLine);
    if (headers.length < expectedXeroHeaders.length) {
      errors.add(
        'Header mismatch: expected at least ${expectedXeroHeaders.length} columns, found ${headers.length}.',
      );
    } else {
      for (int i = 0; i < expectedXeroHeaders.length; i++) {
        if (headers[i] != expectedXeroHeaders[i]) {
          errors.add(
            'Header column $i mismatch: expected "${expectedXeroHeaders[i]}", got "${headers[i]}".',
          );
        }
      }
    }

    // 2. Validate Data Rows
    double runningNetBalance = 0.0;
    int dataRowCount = 0;

    for (int lineIdx = 1; lineIdx < lines.length; lineIdx++) {
      final row = _parseCsvLine(lines[lineIdx]);
      if (row.isEmpty) continue;
      dataRowCount++;

      if (row.length < expectedXeroHeaders.length) {
        errors.add(
          'Row $lineIdx has insufficient columns: expected ${expectedXeroHeaders.length}, got ${row.length}.',
        );
        continue;
      }

      final narration = row[0];
      final date = row[1];
      final description = row[2];
      final accountCode = row[3];
      final taxType = row[4];
      final amountStr = row[5];

      // Invariant 1: Mandatory fields cannot be empty
      if (narration.trim().isEmpty) {
        errors.add('Row $lineIdx: *Narration cannot be empty.');
      }
      if (description.trim().isEmpty) {
        errors.add('Row $lineIdx: *Description cannot be empty.');
      }
      if (accountCode.trim().isEmpty) {
        errors.add('Row $lineIdx: *AccountCode cannot be empty.');
      }
      if (taxType.trim().isEmpty) {
        errors.add('Row $lineIdx: *TaxType cannot be empty.');
      }

      // Invariant 2: Date format strictly DD/MM/YYYY
      if (!_xeroAuDateRegex.hasMatch(date)) {
        errors.add(
          'Row $lineIdx: Invalid Australian date format "$date". Must be strictly DD/MM/YYYY.',
        );
      }

      // Invariant 3: Amount format strictly 2 decimal places
      // Clean leading apostrophe if added by CSV formula injection protection
      final cleanAmount =
          amountStr.startsWith("'") ? amountStr.substring(1) : amountStr;
      if (!_amountRegex.hasMatch(cleanAmount)) {
        errors.add(
          'Row $lineIdx: Invalid monetary amount format "$amountStr". Must have exactly 2 decimal places.',
        );
      }

      final amount = double.tryParse(cleanAmount);
      if (amount == null) {
        errors.add('Row $lineIdx: Could not parse amount "$amountStr".');
      } else {
        runningNetBalance += amount;
      }

      // Invariant 4: Formula Injection check on text columns
      for (int c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell.isEmpty) continue;
        // In the *Amount column (index 5), a leading minus sign is valid numeric notation if it parses as double
        if (c == 5 && double.tryParse(cleanAmount) != null) {
          continue;
        }
        if (CsvSecurity.formulaTriggers.contains(cell[0])) {
          errors.add(
            'Row $lineIdx: Unsanitized formula character detected in cell: "$cell".',
          );
        }
      }
    }

    // Invariant 5: Debits and Credits must balance to zero (within 0.009 rounding tolerance)
    if (dataRowCount > 0 && runningNetBalance.abs() > 0.009) {
      errors.add(
        'Journal is unbalanced! Total net sum is ${runningNetBalance.toStringAsFixed(2)}. Xero requires net balance of 0.00.',
      );
    }

    return _buildResult(
      errors,
      warnings,
      runningNetBalance,
      dataRowCount,
      throwOnError,
    );
  }

  /// Expected HandiTax / Xero D1 Action Schedule CSV header columns
  static const List<String> expectedHandiTaxHeaders = [
    'Tax_Year',
    'Client_Name',
    'ABN',
    'Vehicle_Rego',
    'Vehicle_Description',
    'Item_Label',
    'Schedule_Code',
    'Schedule_Name',
    'Gross_Amount',
    'Business_Percentage',
    'Allowable_Deduction',
    'ATO_Legislative_Reference',
  ];

  /// Validates a generated HandiTax / Xero Tax Item D1 Schedule CSV string.
  static AccountingValidationResult validateHandiTaxD1ScheduleCsv(
    String csvContent, {
    bool throwOnError = false,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    if (lines.isEmpty) {
      errors.add('HandiTax D1 CSV content is completely empty.');
      return _buildResult(errors, warnings, 0.0, 0, throwOnError);
    }

    // 1. Validate Header
    final headerLine = lines.first;
    final headers = _parseCsvLine(headerLine);
    if (headers.length < expectedHandiTaxHeaders.length) {
      errors.add(
        'Header mismatch: expected at least ${expectedHandiTaxHeaders.length} columns, found ${headers.length}.',
      );
    } else {
      for (int i = 0; i < expectedHandiTaxHeaders.length; i++) {
        if (headers[i] != expectedHandiTaxHeaders[i]) {
          errors.add(
            'Header column $i mismatch: expected "${expectedHandiTaxHeaders[i]}", got "${headers[i]}".',
          );
        }
      }
    }

    bool hasD1A = false;
    final foundSchedules = <String>{};
    double sumScheduleAllowable = 0.0;
    double? totalRowAllowable;
    int rowCount = 0;

    for (int lineIdx = 1; lineIdx < lines.length; lineIdx++) {
      final row = _parseCsvLine(lines[lineIdx]);
      if (row.isEmpty) continue;
      rowCount++;

      if (row.length < expectedHandiTaxHeaders.length) {
        errors.add(
          'Row $lineIdx has insufficient columns: expected ${expectedHandiTaxHeaders.length}, got ${row.length}.',
        );
        continue;
      }

      final itemLabel = row[5];
      final schedCode = row[6];
      final grossStr = row[8];
      final bizPctStr = row[9];
      final allowStr = row[10];

      // Formula injection check
      for (int col = 0; col < row.length; col++) {
        final val = row[col];
        if (val.isNotEmpty && CsvSecurity.formulaTriggers.contains(val[0])) {
          errors.add(
              'Row $lineIdx, column $col: Unsanitized formula character detected.');
        }
      }

      if (itemLabel == 'D1A') {
        hasD1A = true;
      } else if (itemLabel == 'D1B') {
        foundSchedules.add(schedCode);
        final allowVal = double.tryParse(allowStr) ?? 0.0;
        final grossVal = double.tryParse(grossStr) ?? 0.0;
        final bizPct = double.tryParse(bizPctStr) ?? 0.0;

        if (schedCode == 'TOTAL') {
          totalRowAllowable = allowVal;
        } else {
          sumScheduleAllowable += allowVal;
          if (allowVal > grossVal && schedCode != 'METHOD') {
            errors.add(
                'Row $lineIdx (Schedule $schedCode): Allowable deduction ($allowVal) exceeds gross ($grossVal).');
          }
          if (bizPct < 0 || bizPct > 100) {
            errors.add('Row $lineIdx: Invalid business percentage: $bizPct.');
          }
        }
      }
    }

    if (!hasD1A) {
      errors.add('Missing Item D1 Method selection row (D1A).');
    }
    const requiredCodes = ['401', '402', '403', '404', '405', 'TOTAL'];
    for (final code in requiredCodes) {
      if (!foundSchedules.contains(code)) {
        errors.add('Missing required Australian Item D1 schedule: $code.');
      }
    }

    if (totalRowAllowable != null) {
      final diff = (sumScheduleAllowable - totalRowAllowable).abs();
      if (diff > 0.05) {
        errors.add(
          'Total row allowable claim ($totalRowAllowable) does not match sum of schedules ($sumScheduleAllowable).',
        );
      }
    }

    return _buildResult(errors, warnings,
        totalRowAllowable ?? sumScheduleAllowable, rowCount, throwOnError);
  }

  static AccountingValidationResult _buildResult(
    List<String> errors,
    List<String> warnings,
    double netBalance,
    int count,
    bool throwOnError,
  ) {
    final isValid = errors.isEmpty;
    if (!isValid && throwOnError) {
      throw FormatException(
        'Accounting export failed validation:\n${errors.join('\n')}',
      );
    }
    return AccountingValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      netBalance: (netBalance.abs() < 0.0001) ? 0.0 : netBalance,
      transactionCount: count,
    );
  }

  /// Basic RFC-4180 compliant CSV line parser supporting quoted fields with commas.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          sb.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString());
    return result;
  }
}
