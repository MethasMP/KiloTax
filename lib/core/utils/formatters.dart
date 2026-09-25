class Formatters {
  static String currency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  static String distance(double km) {
    return '${km.toStringAsFixed(1)} km';
  }

  static String odometer(double reading) {
    return reading.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  static String percentage(double percent) {
    return '${percent.toStringAsFixed(1)}%';
  }

  static String date(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String dateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $hour:$minute $ampm';
  }

  /// Calculates ATO Financial Year string (e.g. '2026–27') based on Australian Tax Cycle (1 July – 30 June)
  static String financialYear(DateTime date) {
    // If month is July (7) or later, FY is currentYear to nextYear (e.g., Jul 2026 -> 2026–27)
    // If month is before July (1-6), FY is prevYear to currentYear (e.g., Jun 2027 -> 2026–27)
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    final endYearShort = (startYear + 1).toString().substring(2);
    return '$startYear–$endYearShort';
  }

  /// Current ATO Financial Year based on system clock
  static String currentFinancialYear() {
    return financialYear(DateTime.now());
  }
}
