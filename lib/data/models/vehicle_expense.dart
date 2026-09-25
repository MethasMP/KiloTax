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

  /// 80/20 Ergonomics: The 3 Core Pillars covering 97% of Tradie vehicle costs
  bool get isCoreThreePillar =>
      this == ExpenseCategory.fuel ||
      this == ExpenseCategory.maintenanceTyres ||
      this == ExpenseCategory.rego ||
      this == ExpenseCategory.insurance ||
      this == ExpenseCategory.tollsParking;

  /// High-level 3-Pillar UI Bucket
  String get pillarGroupName {
    switch (this) {
      case ExpenseCategory.fuel:
        return 'Fuel & Oil';
      case ExpenseCategory.maintenanceTyres:
      case ExpenseCategory.rego:
      case ExpenseCategory.insurance:
      case ExpenseCategory.interest:
        return 'Service, Tyres & Fixed Costs';
      case ExpenseCategory.tollsParking:
        return 'Work Tolls & Parking';
      case ExpenseCategory.toolsMaterials:
        return 'Tools & Materials (Bunnings)';
      case ExpenseCategory.otherBusiness:
        return 'Other Business Expense';
    }
  }
}

enum ReceiptReviewStatus { verified, needsReview, manualReview }

/// Immutable evidence captured at the time a receipt is committed. This keeps
/// the OCR proposal separate from the values ultimately approved by a person.
class ReceiptAuditTrail {
  final String? imageSha256;
  final String? rawOcrText;
  final String? ocrMerchant;
  final double? ocrAmount;
  final double? ocrGstAmount;
  final String? ocrAbn;
  final String? ocrCategory;
  final double? ocrConfidence;
  final List<String> ocrEvidence;
  final ReceiptReviewStatus reviewStatus;
  final List<String> correctionReasons;
  final DateTime capturedAt;

  const ReceiptAuditTrail({
    required this.reviewStatus,
    required this.capturedAt,
    this.imageSha256,
    this.rawOcrText,
    this.ocrMerchant,
    this.ocrAmount,
    this.ocrGstAmount,
    this.ocrAbn,
    this.ocrCategory,
    this.ocrConfidence,
    this.ocrEvidence = const [],
    this.correctionReasons = const [],
  });

  bool get needsReview => reviewStatus != ReceiptReviewStatus.verified;

  Map<String, dynamic> toJson() => {
        'imageSha256': imageSha256,
        'rawOcrText': rawOcrText,
        'ocrMerchant': ocrMerchant,
        'ocrAmount': ocrAmount,
        'ocrGstAmount': ocrGstAmount,
        'ocrAbn': ocrAbn,
        'ocrCategory': ocrCategory,
        'ocrConfidence': ocrConfidence,
        'ocrEvidence': ocrEvidence,
        'reviewStatus': reviewStatus.name,
        'correctionReasons': correctionReasons,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory ReceiptAuditTrail.fromJson(Map<String, dynamic> json) {
    return ReceiptAuditTrail(
      imageSha256: json['imageSha256'] as String?,
      rawOcrText: json['rawOcrText'] as String?,
      ocrMerchant: json['ocrMerchant'] as String?,
      ocrAmount: (json['ocrAmount'] as num?)?.toDouble(),
      ocrGstAmount: (json['ocrGstAmount'] as num?)?.toDouble(),
      ocrAbn: json['ocrAbn'] as String?,
      ocrCategory: json['ocrCategory'] as String?,
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
      ocrEvidence: (json['ocrEvidence'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      reviewStatus: ReceiptReviewStatus.values.firstWhere(
        (status) => status.name == json['reviewStatus'],
        orElse: () => ReceiptReviewStatus.needsReview,
      ),
      correctionReasons:
          (json['correctionReasons'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
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
  final double? gstAmount; // Statutory GST component (capped at ATO 1/11th)
  final ExpenseCategory category;
  final DateTime date;
  final double businessPercentage; // 100.0 for direct, or custom/logbook scaled
  final String? notes;
  final String? linkedTripId; // Link to Trip in Evidence Graph
  final String?
      clientDedupId; // Idempotency Key (Prevents duplicate expense syncs)
  final DateTime? deletedAt; // Soft Delete support
  final ReceiptAuditTrail? receiptAudit;
  final bool isVaultOnly; // When true: stored in Evidence Vault but excluded from active FY claim
  final String? vaultReason; // e.g. 'prior_tax_year', 'cents_per_km_running_cost'

  VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.amount,
    required this.category,
    required this.date,
    this.gstAmount,
    this.receiptPath,
    double? businessPercentage,
    this.notes,
    this.linkedTripId,
    this.clientDedupId,
    this.deletedAt,
    this.receiptAudit,
    this.isVaultOnly = false,
    this.vaultReason,
  }) : businessPercentage = businessPercentage ??
            (category.isDirectlyDeductibleByDefault ? 100.0 : 100.0);

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

  /// Effective GST component with ATO 1/11th statutory cap fallback for GST categories
  double get effectiveGst {
    if (gstAmount != null) return gstAmount!;
    if (receiptAudit?.ocrGstAmount != null) return receiptAudit!.ocrGstAmount!;
    if (category == ExpenseCategory.fuel ||
        category == ExpenseCategory.maintenanceTyres ||
        category == ExpenseCategory.toolsMaterials ||
        category == ExpenseCategory.tollsParking) {
      return double.parse((amount / 11.0).toStringAsFixed(2));
    }
    return 0.0;
  }

  VehicleExpense copyWith({
    String? id,
    String? vehicleId,
    String? receiptPath,
    double? amount,
    double? gstAmount,
    ExpenseCategory? category,
    DateTime? date,
    double? businessPercentage,
    String? notes,
    String? linkedTripId,
    String? clientDedupId,
    DateTime? deletedAt,
    ReceiptAuditTrail? receiptAudit,
    bool? isVaultOnly,
    String? vaultReason,
    bool clearVaultReason = false,
  }) {
    return VehicleExpense(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      receiptPath: receiptPath ?? this.receiptPath,
      amount: amount ?? this.amount,
      gstAmount: gstAmount ?? this.gstAmount,
      category: category ?? this.category,
      date: date ?? this.date,
      businessPercentage: businessPercentage ?? this.businessPercentage,
      notes: notes ?? this.notes,
      linkedTripId: linkedTripId ?? this.linkedTripId,
      clientDedupId: clientDedupId ?? this.clientDedupId,
      deletedAt: deletedAt ?? this.deletedAt,
      receiptAudit: receiptAudit ?? this.receiptAudit,
      isVaultOnly: isVaultOnly ?? this.isVaultOnly,
      vaultReason: clearVaultReason ? null : (vaultReason ?? this.vaultReason),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'receiptPath': receiptPath,
      'amount': amount,
      'gstAmount': gstAmount,
      'category': category.name,
      'date': date.toIso8601String(),
      'businessPercentage': businessPercentage,
      'notes': notes,
      'linkedTripId': linkedTripId,
      'clientDedupId': clientDedupId,
      'deletedAt': deletedAt?.toIso8601String(),
      'receiptAudit': receiptAudit?.toJson(),
      'isVaultOnly': isVaultOnly,
      'vaultReason': vaultReason,
    };
  }

  factory VehicleExpense.fromJson(Map<String, dynamic> json) {
    return VehicleExpense(
      id: json['id'] as String,
      vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
      amount: ((json['amount']) as num).toDouble(),
      gstAmount: (json['gstAmount'] ?? json['gst_amount']) != null
          ? ((json['gstAmount'] ?? json['gst_amount']) as num).toDouble()
          : null,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ExpenseCategory.fuel,
      ),
      date: DateTime.parse(json['date'] as String),
      receiptPath: (json['receiptPath'] ?? json['receipt_path']) as String?,
      businessPercentage: json['businessPercentage'] != null
          ? ((json['businessPercentage']) as num).toDouble()
          : (json['business_percentage'] != null
              ? ((json['business_percentage']) as num).toDouble()
              : null),
      notes: json['notes'] as String?,
      linkedTripId: (json['linkedTripId'] ?? json['linked_trip_id']) as String?,
      clientDedupId:
          (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null
              ? DateTime.tryParse(json['deleted_at'] as String)
              : null),
      receiptAudit: json['receiptAudit'] is Map<String, dynamic>
          ? ReceiptAuditTrail.fromJson(
              json['receiptAudit'] as Map<String, dynamic>)
          : null,
      isVaultOnly: json['isVaultOnly'] == true || json['is_vault_only'] == true,
      vaultReason: json['vaultReason'] as String? ?? json['vault_reason'] as String?,
    );
  }
}
