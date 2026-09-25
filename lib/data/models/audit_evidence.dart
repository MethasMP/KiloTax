enum EvidenceType {
  odometerStart,
  odometerEnd,
  heavyToolsSetup,
  expenseReceipt;

  String get dbValue {
    switch (this) {
      case EvidenceType.odometerStart:
        return 'odometer_start';
      case EvidenceType.odometerEnd:
        return 'odometer_end';
      case EvidenceType.heavyToolsSetup:
        return 'heavy_tools_setup';
      case EvidenceType.expenseReceipt:
        return 'expense_receipt';
    }
  }

  static EvidenceType fromDbValue(String value) {
    switch (value) {
      case 'odometer_start':
        return EvidenceType.odometerStart;
      case 'odometer_end':
        return EvidenceType.odometerEnd;
      case 'heavy_tools_setup':
        return EvidenceType.heavyToolsSetup;
      case 'expense_receipt':
      default:
        return EvidenceType.expenseReceipt;
    }
  }

  String get displayName {
    switch (this) {
      case EvidenceType.odometerStart:
        return 'Day 1 Starting Odometer';
      case EvidenceType.odometerEnd:
        return 'Day 84 Final Odometer';
      case EvidenceType.heavyToolsSetup:
        return 'Trade Equipment Setup';
      case EvidenceType.expenseReceipt:
        return 'Expense Receipt';
    }
  }
}

/// Unified Audit Evidence Entity
/// Represents an immutable, cryptographically verified piece of tax evidence.
class AuditEvidence {
  final String id;
  final String? vehicleId;
  final EvidenceType evidenceType;
  final String? entityId;
  final String storagePath;
  final String imageSha256;
  final int? fileSizeBytes;
  final String mimeType;
  final DateTime capturedAt;
  final String captureSource;
  final Map<String, dynamic> watermarkMetadata;
  final DateTime createdAt;

  AuditEvidence({
    required this.id,
    this.vehicleId,
    required this.evidenceType,
    this.entityId,
    required this.storagePath,
    required this.imageSha256,
    this.fileSizeBytes,
    this.mimeType = 'image/webp',
    required this.capturedAt,
    this.captureSource = 'camera_live',
    Map<String, dynamic>? watermarkMetadata,
    DateTime? createdAt,
  })  : watermarkMetadata = watermarkMetadata ?? {},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'evidenceType': evidenceType.dbValue,
      'entityId': entityId,
      'storagePath': storagePath,
      'imageSha256': imageSha256,
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
      'capturedAt': capturedAt.toIso8601String(),
      'captureSource': captureSource,
      'watermarkMetadata': watermarkMetadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AuditEvidence.fromJson(Map<String, dynamic> json) {
    return AuditEvidence(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String?,
      evidenceType: EvidenceType.fromDbValue(
        (json['evidenceType'] ?? json['evidence_type']) as String? ?? 'expense_receipt',
      ),
      entityId: (json['entityId'] ?? json['entity_id']) as String?,
      storagePath: (json['storagePath'] ?? json['storage_path']) as String,
      imageSha256: (json['imageSha256'] ?? json['image_sha256']) as String,
      fileSizeBytes: (json['fileSizeBytes'] ?? json['file_size_bytes']) as int?,
      mimeType: (json['mimeType'] ?? json['mime_type']) as String? ?? 'image/webp',
      capturedAt: DateTime.parse(
        (json['capturedAt'] ?? json['captured_at']) as String,
      ),
      captureSource:
          (json['captureSource'] ?? json['capture_source']) as String? ?? 'camera_live',
      watermarkMetadata:
          Map<String, dynamic>.from(json['watermarkMetadata'] ?? json['watermark_metadata'] ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
