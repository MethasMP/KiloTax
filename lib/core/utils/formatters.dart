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
}
