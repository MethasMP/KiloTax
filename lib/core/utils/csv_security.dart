/// Utility for CSV injection sanitization adhering to CWE-1236.
/// Prevents formula execution (=, +, -, @, \t, \r) in spreadsheet viewers (Excel, Sheets).
class CsvSecurity {
  /// Characters that can trigger formula execution in spreadsheet software.
  static const List<String> formulaTriggers = ['=', '+', '-', '@', '\t', '\r'];

  /// Sanitizes a CSV cell:
  /// 1. If text starts with any formula trigger character (=, +, -, @, \t, \r), prepend a single quote (').
  /// 2. Escapes any double quotes by doubling them (" -> "").
  /// 3. Returns the sanitized string.
  static String sanitizeCsvCell(String input) {
    if (input.isEmpty) return input;

    String text = input;
    final firstChar = text[0];
    if (formulaTriggers.contains(firstChar)) {
      text = "'$text";
    }

    return text.replaceAll('"', '""');
  }
}
