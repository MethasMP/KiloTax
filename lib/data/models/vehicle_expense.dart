enum ExpenseCategory {
  fuel,
  rego,
  insurance,
  maintenanceTyres,
  interest,
  tollsParking,
  toolsMaterials,
  otherBusiness;

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
      case ExpenseCategory.toolsMaterials:
        return 'Tools & Job Materials (Bunnings)';
      case ExpenseCategory.otherBusiness:
        return 'General Business Cost';
    }
  }

  /// Categorizes whether this is directly tied to the car running cost vs general business
  bool get isCarExpense =>
      this == ExpenseCategory.fuel ||
      this == ExpenseCategory.rego ||
      this == ExpenseCategory.insurance ||
      this == ExpenseCategory.maintenanceTyres ||
      this == ExpenseCategory.interest;

  /// ATO Rule: Work tolls, tools & direct business items are 100% deductible directly,
  /// whereas general car running costs are scaled by logbook business %.
  bool get isDirectlyDeductibleByDefault =>
      this == ExpenseCategory.tollsParking ||
      this == ExpenseCategory.toolsMaterials ||
      this == ExpenseCategory.otherBusiness;
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
  final String? linkedTripId; // Link to Trip in Evidence Graph
  final String? clientDedupId; // Idempotency Key (Prevents duplicate expense syncs)
  final DateTime? deletedAt; // Soft Delete support

  VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.amount,
    required this.category,
    required this.date,
    this.receiptPath,
    double? businessPercentage,
    this.notes,
    this.linkedTripId,
    this.clientDedupId,
    this.deletedAt,
  }) : businessPercentage = businessPercentage ?? (category.isDirectlyDeductibleByDefault ? 100.0 : 100.0);

  bool get isDeleted => deletedAt != null;

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
