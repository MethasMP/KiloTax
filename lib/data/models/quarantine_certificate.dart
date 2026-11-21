import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Statutory Private Use Quarantine & Exclusion Certificate Entity
///
/// Complies with ATO ITAA 1997 Division 28 & TR 2021/1 substantiation rules.
/// Explicitly isolates non-business kilometers and private expenses so tax agents
/// and auditors have proof that private travel is 100% excluded from deductions.
class QuarantineCertificate {
  final String vehicleId;
  final String regoPlate;
  final String financialYear;
  final double totalOdometerKm;
  final double businessKm;
  final double quarantinedPrivateKm;
  final int businessTripsCount;
  final int quarantinedPrivateTripsCount;
  final double totalExpensesAud;
  final double deductibleExpensesAud;
  final double quarantinedPrivateExpensesAud;
  final DateTime generatedAt;
  final String? customAuditHash;

  const QuarantineCertificate({
    required this.vehicleId,
    required this.regoPlate,
    required this.financialYear,
    required this.totalOdometerKm,
    required this.businessKm,
    required this.quarantinedPrivateKm,
    required this.businessTripsCount,
    required this.quarantinedPrivateTripsCount,
    required this.totalExpensesAud,
    required this.deductibleExpensesAud,
    required this.quarantinedPrivateExpensesAud,
    required this.generatedAt,
    this.customAuditHash,
  });

  /// Total trips logged across both business and private categories
  int get totalTripsCount => businessTripsCount + quarantinedPrivateTripsCount;

  /// Business use percentage: (businessKm / totalOdometerKm) * 100
  double get businessPercentage {
    if (totalOdometerKm <= 0 || businessKm <= 0) return 0.0;
    final pct = (businessKm / totalOdometerKm) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  /// Quarantined private percentage: (quarantinedPrivateKm / totalOdometerKm) * 100
  double get quarantinedKmPercentage {
    if (totalOdometerKm <= 0 || quarantinedPrivateKm <= 0) return 0.0;
    final pct = (quarantinedPrivateKm / totalOdometerKm) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  /// Validates that total km matches sum of business and quarantined private km (within 0.1km tolerance)
  bool get isMathematicallySound {
    if (totalOdometerKm < 0 || businessKm < 0 || quarantinedPrivateKm < 0) {
      return false;
    }
    final diff = (totalOdometerKm - (businessKm + quarantinedPrivateKm)).abs();
    return diff <= 0.1;
  }

  /// Cryptographic SHA-256 seal of this quarantine certificate
  String get auditHash {
    final explicit = customAuditHash;
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final payload = [
      vehicleId,
      regoPlate,
      financialYear,
      totalOdometerKm.toStringAsFixed(2),
      businessKm.toStringAsFixed(2),
      quarantinedPrivateKm.toStringAsFixed(2),
      businessTripsCount.toString(),
      quarantinedPrivateTripsCount.toString(),
      totalExpensesAud.toStringAsFixed(2),
      deductibleExpensesAud.toStringAsFixed(2),
      quarantinedPrivateExpensesAud.toStringAsFixed(2),
      generatedAt.toIso8601String(),
    ].join('|');

    return sha256.convert(utf8.encode(payload)).toString();
  }
}
