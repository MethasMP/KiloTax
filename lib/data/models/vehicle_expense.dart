const Object _expenseUnset = Object();

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

enum ReceiptReviewStatus { verified, needsReview, manualReview, confirmed }

class ReceiptFieldCorrection {
  final String field;
  final Object? oldValue;
  final Object? newValue;
  final String source;
  final DateTime timestamp;
  final int revision;
  const ReceiptFieldCorrection(
      {required this.field,
      this.oldValue,
      this.newValue,
      this.source = 'user',
      required this.timestamp,
      required this.revision});
  Map<String, dynamic> toJson() => {
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
        'revision': revision
      };
  factory ReceiptFieldCorrection.fromJson(Map<String, dynamic> j) =>
      ReceiptFieldCorrection(
          field: j['field'] as String,
          oldValue: j['oldValue'],
          newValue: j['newValue'],
          source: j['source'] as String? ?? 'user',
          timestamp: DateTime.parse(j['timestamp'] as String),
          revision: j['revision'] as int? ?? 1);
}

/// Immutable evidence captured at the time a receipt is committed. This keeps
/// the OCR proposal separate from the values ultimately approved by a person.
class ReceiptAuditTrail {
  final DateTime? extractedAt;
  final DateTime? ocrDate;
  final String? ocrCurrency;
  final String? ocrInvoiceNumber;
  final String? extractionImageSha256;
  final String? engineId;
  final String? engineVersion;
  final String? parserVersion;
  final List<Map<String, dynamic>> blocks;
  final List<ReceiptFieldCorrection> corrections;
  final int revision;
  final int? reviewedRevision;
  final String? reviewedBy;
  final String? batchId;
  final Map<String, dynamic> currentFields;
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
  final DateTime? reviewedAt;

  const ReceiptAuditTrail({
    this.extractedAt,
    this.ocrDate,
    this.ocrCurrency,
    this.ocrInvoiceNumber,
    this.extractionImageSha256,
    this.engineId,
    this.engineVersion,
    this.parserVersion,
    this.blocks = const [],
    this.corrections = const [],
    this.revision = 1,
    this.reviewedRevision,
    this.reviewedBy,
    this.batchId,
    this.currentFields = const {},
    required this.reviewStatus,
    required this.capturedAt,
    this.reviewedAt,
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

  /// Compatibility getter for substantiation standard (ATO TR 97/11)
  String? get sha256Hash => imageSha256;

  bool get needsReview =>
      reviewStatus != ReceiptReviewStatus.verified &&
      reviewStatus != ReceiptReviewStatus.confirmed;

  Map<String, dynamic> toJson() => {
        'extractedAt': extractedAt?.toIso8601String(),
        'ocrDate': ocrDate?.toIso8601String(),
        'ocrCurrency': ocrCurrency,
        'ocrInvoiceNumber': ocrInvoiceNumber,
        'extractionImageSha256': extractionImageSha256,
        'engineId': engineId,
        'engineVersion': engineVersion,
        'parserVersion': parserVersion,
        'blocks': blocks,
        'corrections': corrections.map((e) => e.toJson()).toList(),
        'revision': revision,
        'reviewedRevision': reviewedRevision,
        'reviewedBy': reviewedBy,
        'batchId': batchId,
        'currentFields': currentFields,
        'imageSha256': imageSha256,
        'sha256Hash': imageSha256,
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
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory ReceiptAuditTrail.fromJson(Map<String, dynamic> json) {
    return ReceiptAuditTrail(
      extractedAt: DateTime.tryParse(json['extractedAt'] as String? ?? ''),
      ocrDate: DateTime.tryParse(json['ocrDate'] as String? ?? ''),
      ocrCurrency: json['ocrCurrency'] as String?,
      ocrInvoiceNumber: json['ocrInvoiceNumber'] as String?,
      extractionImageSha256: json['extractionImageSha256'] as String?,
      engineId: json['engineId'] as String?,
      engineVersion: json['engineVersion'] as String?,
      parserVersion: json['parserVersion'] as String?,
      blocks: (json['blocks'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      corrections: (json['corrections'] as List? ?? [])
          .map((e) => ReceiptFieldCorrection.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      revision: json['revision'] as int? ?? 1,
      reviewedRevision: json['reviewedRevision'] as int?,
      reviewedBy: json['reviewedBy'] as String?,
      batchId: json['batchId'] as String?,
      currentFields:
          Map<String, dynamic>.from(json['currentFields'] as Map? ?? {}),
      imageSha256: (json['imageSha256'] ??
          json['image_sha256'] ??
          json['sha256Hash'] ??
          json['sha256_hash']) as String?,
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
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
    );
  }
}

enum AllocationPurpose { work, private, unresolved }

/// A receipt line is an allocation of its original gross total, not a tax ruling.
class ReceiptAllocation {
  final String description;
  final double amount;
  final double? gstAmount;
  final ExpenseCategory? category;
  final AllocationPurpose purpose;

  const ReceiptAllocation(
      {required this.description,
      required this.amount,
      required this.purpose,
      this.gstAmount,
      this.category});

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'gst_amount': gstAmount,
        'category': category?.name,
        'purpose': purpose.name
      };

  factory ReceiptAllocation.fromJson(Map<String, dynamic> json) =>
      ReceiptAllocation(
          description: json['description'] as String? ?? '',
          amount: (json['amount'] as num).toDouble(),
          gstAmount: (json['gst_amount'] as num?)?.toDouble(),
          category: json['category'] == null
              ? null
              : ExpenseCategory.values
                  .firstWhere((c) => c.name == json['category']),
          purpose: AllocationPurpose.values.firstWhere(
              (p) => p.name == json['purpose'],
              orElse: () => AllocationPurpose.unresolved));
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
  final String? supplier;
  final String? currency;
  final String? supplierAbn;
  final String? invoiceNumber;
  final List<ReceiptAllocation> allocations;
  final double? gstAmount; // Statutory GST component (capped at ATO 1/11th)
  final ExpenseCategory category;
  final DateTime date;
  final double businessPercentage; // 100.0 for direct, or custom/logbook scaled
  final String? notes;
  final String? jobId;
  final String? linkedTripId; // Link to Trip in Evidence Graph
  final String?
      clientDedupId; // Idempotency Key (Prevents duplicate expense syncs)
  final DateTime? deletedAt; // Soft Delete support
  final ReceiptAuditTrail? receiptAudit;
  final bool
      isVaultOnly; // When true: stored in Evidence Vault but excluded from active FY claim
  final String?
      vaultReason; // e.g. 'prior_tax_year', 'cents_per_km_running_cost'
  final String?
      sha256Hash; // Cryptographic SHA-256 hash of receipt image bytes (ATO TR 97/11)

  VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.amount,
    required this.category,
    required this.date,
    this.gstAmount,
    this.supplier,
    this.currency = 'AUD',
    this.supplierAbn,
    this.invoiceNumber,
    List<ReceiptAllocation> allocations = const [],
    this.receiptPath,
    double? businessPercentage,
    this.notes,
    this.linkedTripId,
    this.jobId,
    this.clientDedupId,
    this.deletedAt,
    this.receiptAudit,
    this.isVaultOnly = false,
    this.vaultReason,
    String? sha256Hash,
  })  : allocations = List.unmodifiable(allocations),
        sha256Hash = sha256Hash ?? receiptAudit?.imageSha256,
        businessPercentage = (businessPercentage ??
                (category.isDirectlyDeductibleByDefault ? 100.0 : 100.0))
            .clamp(0.0, 100.0);

  bool get isDeleted => deletedAt != null;

  /// Null means each amount is valid and all lines reconcile to the receipt total.
  String? get allocationError {
    final gst = gstAmount;
    if (gst != null &&
        (!gst.isFinite ||
            gst < 0 ||
            !amount.isFinite ||
            gst > amount / 11 + 0.01 ||
            (gst * 100 - (gst * 100).round()).abs() > 0.00001)) {
      return 'Check the GST on the receipt, or leave it blank if unknown.';
    }
    if (allocations.isEmpty) return null;
    if (!amount.isFinite || amount <= 0) return 'Enter a valid receipt total.';
    if (allocations.length > 200) return 'Use at most 200 items per receipt.';
    var cents = 0;
    var knownGstCents = 0;
    for (final line in allocations) {
      if (line.description.trim().isEmpty ||
          !line.amount.isFinite ||
          line.amount <= 0 ||
          (line.amount * 100 - (line.amount * 100).round()).abs() > 0.00001) {
        return 'Each item needs a description and a positive amount in cents.';
      }
      final gst = line.gstAmount;
      if (gst != null &&
          (!gst.isFinite ||
              gst < 0 ||
              (gst * 100 - (gst * 100).round()).abs() > 0.00001 ||
              gst > line.amount / 11 + 0.01)) {
        return 'Check the GST recorded for each item.';
      }
      cents += (line.amount * 100).round();
      knownGstCents += ((gst ?? 0) * 100).round();
    }
    if (cents != (amount * 100).round()) {
      return 'Item amounts must match the receipt total.';
    }
    if (gstAmount != null && knownGstCents > (gstAmount! * 100).round() + 1) {
      return 'Item GST exceeds the GST on the receipt.';
    }
    return null;
  }

  double get allocatedWorkAmount => allocations.isEmpty
      ? amount
      : allocationError != null
          ? 0
          : allocations
              .where((l) => l.purpose == AllocationPurpose.work)
              .fold(0.0, (sum, l) => sum + l.amount);

  /// Calculation-only projection. The stored parent retains its original total/image.
  Iterable<VehicleExpense> get claimComponents sync* {
    if (isDeleted || isVaultOnly) return;
    if (allocations.isEmpty) {
      yield this;
      return;
    }
    if (allocationError != null) return;
    for (final line in allocations) {
      if (line.purpose != AllocationPurpose.work) continue;
      yield VehicleExpense(
          id: id,
          vehicleId: vehicleId,
          amount: line.amount,
          gstAmount: line.gstAmount ?? 0,
          category: line.category ?? category,
          date: date,
          supplier: supplier,
          currency: currency,
          supplierAbn: supplierAbn,
          invoiceNumber: invoiceNumber,
          receiptPath: receiptPath,
          businessPercentage: 100,
          notes: line.description,
          receiptAudit: receiptAudit,
          linkedTripId: linkedTripId,
          sha256Hash: sha256Hash);
    }
  }

  /// Computes deductible amount based on statutory logbook % for general running costs,
  /// or 100% direct claim for work tolls & parking.
  double calculateClaimWithLogbookRate(double statutoryLogbookPercentage) {
    if (allocations.isNotEmpty) {
      return claimComponents.fold(
          0.0,
          (sum, line) =>
              sum +
              line.calculateClaimWithLogbookRate(statutoryLogbookPercentage));
    }
    if (category.isDirectlyDeductibleByDefault) {
      return amount * (businessPercentage / 100.0);
    }
    return amount * (statutoryLogbookPercentage / 100.0);
  }

  /// Default deductible amount using on-record business percentage
  double get deductibleAmount => allocations.isEmpty
      ? amount * (businessPercentage / 100.0)
      : allocatedWorkAmount;

  /// Recorded GST only. Unknown tax is not inferred from category or gross total.
  double get effectiveGst {
    if (allocations.isNotEmpty) {
      return claimComponents.fold(0.0, (sum, line) => sum + line.effectiveGst);
    }
    if (gstAmount != null) return gstAmount!;
    return 0.0;
  }

  VehicleExpense copyWith({
    String? id,
    String? vehicleId,
    String? receiptPath,
    double? amount,
    String? supplier,
    Object? currency = _expenseUnset,
    Object? supplierAbn = _expenseUnset,
    Object? invoiceNumber = _expenseUnset,
    List<ReceiptAllocation>? allocations,
    Object? gstAmount = _expenseUnset,
    ExpenseCategory? category,
    DateTime? date,
    double? businessPercentage,
    String? notes,
    String? linkedTripId,
    String? jobId,
    bool clearJob = false,
    bool clearLinkedTripId = false,
    String? clientDedupId,
    DateTime? deletedAt,
    ReceiptAuditTrail? receiptAudit,
    bool? isVaultOnly,
    String? vaultReason,
    bool clearVaultReason = false,
    String? sha256Hash,
  }) {
    return VehicleExpense(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      receiptPath: receiptPath ?? this.receiptPath,
      amount: amount ?? this.amount,
      supplier: supplier ?? this.supplier,
      currency: identical(currency, _expenseUnset)
          ? this.currency
          : currency as String?,
      supplierAbn: identical(supplierAbn, _expenseUnset)
          ? this.supplierAbn
          : supplierAbn as String?,
      invoiceNumber: identical(invoiceNumber, _expenseUnset)
          ? this.invoiceNumber
          : invoiceNumber as String?,
      allocations: allocations ?? this.allocations,
      gstAmount: identical(gstAmount, _expenseUnset)
          ? this.gstAmount
          : (gstAmount as num?)?.toDouble(),
      category: category ?? this.category,
      date: date ?? this.date,
      businessPercentage: businessPercentage ?? this.businessPercentage,
      notes: notes ?? this.notes,
      jobId: clearJob ? null : (jobId ?? this.jobId),
      linkedTripId:
          clearLinkedTripId ? null : (linkedTripId ?? this.linkedTripId),
      clientDedupId: clientDedupId ?? this.clientDedupId,
      deletedAt: deletedAt ?? this.deletedAt,
      receiptAudit: receiptAudit ?? this.receiptAudit,
      isVaultOnly: isVaultOnly ?? this.isVaultOnly,
      vaultReason: clearVaultReason ? null : (vaultReason ?? this.vaultReason),
      sha256Hash: sha256Hash ?? this.sha256Hash,
    );
  }

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'receiptPath': receiptPath,
      'amount': amount,
      'supplier': supplier,
      'currency': currency,
      'supplierAbn': supplierAbn,
      'invoiceNumber': invoiceNumber,
      'allocations': allocations.map((line) => line.toJson()).toList(),
      'gstAmount': gstAmount,
      'category': category.name,
      'date': date.toIso8601String(),
      'businessPercentage': businessPercentage,
      'notes': notes,
      'linkedTripId': linkedTripId,
      'jobId': jobId,
      'clientDedupId': clientDedupId,
      'deletedAt': deletedAt?.toIso8601String(),
      'receiptAudit': receiptAudit?.toJson(),
      'isVaultOnly': isVaultOnly,
      'vaultReason': vaultReason,
      'sha256Hash': sha256Hash ?? receiptAudit?.imageSha256,
    };
  }

  factory VehicleExpense.fromJson(Map<String, dynamic> json) {
    final auditJson = json['receiptAudit'] ?? json['receipt_audit'];
    final audit = auditJson is Map<String, dynamic>
        ? ReceiptAuditTrail.fromJson(auditJson)
        : null;
    final extractedSha256 = (json['sha256Hash'] ??
        json['sha256_hash'] ??
        audit?.imageSha256) as String?;

    return VehicleExpense(
      id: json['id'] as String,
      vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
      amount: ((json['amount']) as num).toDouble(),
      supplier: json['supplier'] as String?,
      currency:
          json.containsKey('currency') ? json['currency'] as String? : 'AUD',
      supplierAbn: (json['supplierAbn'] ?? json['supplier_abn']) as String?,
      invoiceNumber:
          (json['invoiceNumber'] ?? json['invoice_number']) as String?,
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((line) => ReceiptAllocation.fromJson(
              Map<String, dynamic>.from(line as Map)))
          .toList(),
      gstAmount: (json['gstAmount'] ?? json['gst_amount']) != null
          ? ((json['gstAmount'] ?? json['gst_amount']) as num).toDouble()
          : null,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ExpenseCategory.fuel,
      ),
      date: DateTime.parse(json['date'] as String),
      receiptPath: (json['receiptPath'] ??
          json['receipt_path'] ??
          json['receipt_storage_path']) as String?,
      businessPercentage: json['businessPercentage'] != null
          ? ((json['businessPercentage']) as num).toDouble()
          : (json['business_percentage'] != null
              ? ((json['business_percentage']) as num).toDouble()
              : null),
      notes: json['notes'] as String?,
      linkedTripId: (json['linkedTripId'] ?? json['linked_trip_id']) as String?,
      jobId: (json['jobId'] ?? json['job_id']) as String?,
      clientDedupId:
          (json['clientDedupId'] ?? json['client_dedup_id']) as String?,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null
              ? DateTime.tryParse(json['deleted_at'] as String)
              : null),
      receiptAudit: audit,
      isVaultOnly: json['isVaultOnly'] == true || json['is_vault_only'] == true,
      vaultReason:
          json['vaultReason'] as String? ?? json['vault_reason'] as String?,
      sha256Hash: extractedSha256,
    );
  }
}
