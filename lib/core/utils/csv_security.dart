/// Utility for CSV injection sanitization adhering to CWE-1236.
/// Prevents formula execution (=, +, -, @, \t, \r) in spreadsheet viewers (Excel, Sheets).
class CsvSecurity {
  /// Characters that can trigger formula execution in spreadsheet software.
  /// Adheres to CWE-1236 including extended European separators and pipe executions.
  static const List<String> formulaTriggers = [
    '=',
    '+',
    '-',
    '@',
    '\t',
    '\r',
    '\n',
    '%',
    ';',
    '|',
  ];

  /// Sanitizes a CSV cell:
  /// 1. Trims leading whitespace/control chars before checking formula triggers.
  /// 2. If the trimmed text starts with any formula trigger (=, +, -, @, \t, \r, \n, %, ;, |),
  ///    prepend a single quote (') to force plain-text evaluation.
  /// 3. Escapes any double quotes by doubling them (" -> "").
  /// 4. Returns the sanitized string.
  static String sanitizeCsvCell(String input) {
    if (input.isEmpty) return input;

    // Check raw leading trigger first, or trimmed leading spaces (e.g. " =SUM(A1)")
    String text = input;
    final firstRawChar = text[0];
    if (formulaTriggers.contains(firstRawChar)) {
      text = "'$text";
    } else {
      // Check if leading spaces hide a formula trigger
      int spaceCount = 0;
      while (spaceCount < text.length && text[spaceCount] == ' ') {
        spaceCount++;
      }
      if (spaceCount > 0 && spaceCount < text.length) {
        final charAfterSpace = text[spaceCount];
        if (formulaTriggers.contains(charAfterSpace)) {
          text = "'$text";
        }
      }
    }

    return text.replaceAll('"', '""');
  }

  /// Wraps a value in double quotes after sanitization, or returns empty quotes.
  static String quoteCell(String input) {
    return '"${sanitizeCsvCell(input)}"';
  }
}
