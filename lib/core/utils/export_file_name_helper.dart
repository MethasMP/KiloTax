/// Sanitizes taxpayer names and registration plates for safe cross-platform file naming
/// Aligned with KiloTax Compliance Architecture dynamic file naming specification.
class ExportFileNameHelper {
  /// Standard document type slugs
  static const String boxD1LodgementSlip = 'BoxD1_Lodgement_Slip';
  static const String cpkTripLedger = 'Trip_Ledger';
  static const String auditDossier = 'Audit_Dossier';
  static const String continuousOdometerLedger = 'Continuous_Odometer_Ledger';
  static const String manualJournalXero = 'Manual_Journal_Xero';
  static const String generalJournalMyob = 'General_Journal_MYOB';
  static const String multiVehicleBoxD1Schedule = 'MultiVehicle_BoxD1_Schedule';

  /// Sanitizes alphanumeric input, replacing spaces and hyphens with underscores,
  /// stripping special characters, and truncating to [maxLength].
  static String sanitizeAlphaNumeric(String input, {int maxLength = 20}) {
    if (input.trim().isEmpty) return '';
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }

  /// Sanitizes vehicle registration plate: uppercase alphanumeric only.
  static String sanitizeRego(String rego) {
    return rego.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Builds a deterministic, cross-platform file name:
  /// `KiloTax_{Method}_{FY}_{TaxpayerName}_{SanitizedRego}_{DocumentType}.{extension}`
  static String buildFileName({
    required String method, // 'CPK' | 'Logbook' | 'Combined'
    required String fy, // e.g. 'FY2025-26' or 'FY2026-27'
    required String taxpayerName,
    required String rego,
    required String documentType, // e.g. 'BoxD1_Lodgement_Slip'
    required String extension, // 'csv' | 'pdf' | 'txt'
  }) {
    final cleanName = sanitizeAlphaNumeric(taxpayerName).isNotEmpty
        ? sanitizeAlphaNumeric(taxpayerName)
        : 'TradieClient';
    final cleanRego =
        sanitizeRego(rego).isNotEmpty ? sanitizeRego(rego) : 'VEHICLE';
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    final cleanFy = fy.startsWith('FY') ? fy : 'FY$fy';

    return 'KiloTax_${method}_${cleanFy}_${cleanName}_${cleanRego}_$documentType.$cleanExt';
  }
}
