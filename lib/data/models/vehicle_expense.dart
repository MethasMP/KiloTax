enum ExpenseCategory {
  fuel,
  rego,
  insurance,
  maintenanceTyres,
  interest,
  tollsParking;

  String get displayName {
    switch (this) {
      case ExpenseCategory.fuel:
        return 'Fuel & Oil';
      case ExpenseCategory.rego:
        return 'Registration (Rego)';
      case ExpenseCategory.insurance:
        return 'Vehicle Insurance';
      case ExpenseCategory.maintenanceTyres:
        return 'Servicing, Repairs & Tyres';
      case ExpenseCategory.interest:
        return 'Car Loan Interest / Lease';
      case ExpenseCategory.tollsParking:
        return 'Work Tolls & Parking';
    }
  }

  /// ATO Rule: Work-related tolls & parking are 100% directly deductible,
  /// whereas general running costs are scaled by the logbook business percentage.
  bool get isDirectlyDeductibleByDefault => this == ExpenseCategory.tollsParking;
}

/// Core Expense Entity conforming to Layer 2 (EXPENSES):
/// - Receipt
/// - Amount
/// - Category
/// - Date
/// - Business %
class VehicleExpense {
  final String id;
  final String vehicleId;
  final String? receiptPath;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final double businessPercentage; // 100.0 for direct, or custom/logbook scaled
  final String? notes;

  VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.amount,
    required this.category,
    required this.date,
    this.receiptPath,
    double? businessPercentage,
    this.notes,
  }) : businessPercentage = businessPercentage ?? (category.isDirectlyDeductibleByDefault ? 100.0 : 100.0);

  /// Computes deductible amount based on statutory logbook % for general running costs,
  /// or 100% direct claim for work tolls & parking.
  double calculateClaimWithLogbookRate(double statutoryLogbookPercentage) {
    if (category.isDirectlyDeductibleByDefault) {
      return amount * (businessPercentage / 100.0);
    }
    return amount * (statutoryLogbookPercentage / 100.0);
  }

  /// Default deductible amount using on-record business percentage
  double get deductibleAmount => (amount * (businessPercentage / 100.0));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'receipt_path': receiptPath,
      'amount': amount,
      'category': category.name,
      'date': date.toIso8601String(),
      'business_percentage': businessPercentage,
      'notes': notes,
    };
  }
}
