import '../../services/tax/ato_tax_period_engine.dart';

class Formatters {
  static const AtoTaxPeriodEngine _taxPeriodEngine = AtoTaxPeriodEngine();

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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String dateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · $hour:$minute $ampm';
  }

  /// Calculates ATO Financial Year string (e.g. '2026–27') delegating cleanly to [AtoTaxPeriodEngine]
  static String financialYear(DateTime date) {
    return _taxPeriodEngine.forDate(date).shortLabel;
  }

  /// Current ATO Financial Year based on system clock
  static String currentFinancialYear() {
    return financialYear(DateTime.now());
  }
}
