import 'package:flutter/foundation.dart';

import '../../data/models/trip.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';

/// A physical dashboard odometer reading captured from a photo, service invoice,
/// fuel receipt, or manual check.
@immutable
class OdometerAnchor {
  final DateTime date;
  final double physicalOdometerKm;
  final double? gpsCumulativeKm;
  final String source;
  final String? note;

  const OdometerAnchor({
    required this.date,
    required this.physicalOdometerKm,
    this.gpsCumulativeKm,
    required this.source,
    this.note,
  });
}

/// Output of the Dashboard-Odometer Parity Engine (ATO CR 2021/16 para 35).
@immutable
class OdometerCalibrationResult {
  final String vehicleId;
  final double calibrationFactor;
  final double driftPercent;
  final bool requiresRecalibrationAlert;
  final int anchorCount;
  final double totalPhysicalDeltaKm;
  final double totalGpsDeltaKm;
  final String advisoryMessage;

  const OdometerCalibrationResult({
    required this.vehicleId,
    required this.calibrationFactor,
    required this.driftPercent,
    required this.requiresRecalibrationAlert,
    required this.anchorCount,
    required this.totalPhysicalDeltaKm,
    required this.totalGpsDeltaKm,
    required this.advisoryMessage,
  });

  /// Applies the learned calibration multiplier to raw GPS distance while
  /// keeping raw GPS auditable separately.
  double applyToGpsKm(double gpsRawKm) {
    if (!gpsRawKm.isFinite || gpsRawKm < 0) return 0.0;
    return double.parse((gpsRawKm * calibrationFactor).toStringAsFixed(2));
  }
}

/// Estimated Fuel-Litres-to-Km Plausibility Band for pre-lodgement sanity checks.
@immutable
class FuelPlausibilityResult {
  final double totalFuelLitres;
  final double claimedKm;
  final double? estimatedLitresPer100Km;
  final double expectedMinLPer100Km;
  final double expectedMaxLPer100Km;
  final bool isPlausible;
  final bool hasSufficientData;
  final String statusLabel;
  final String advisoryMessage;

  const FuelPlausibilityResult({
    required this.totalFuelLitres,
    required this.claimedKm,
    this.estimatedLitresPer100Km,
    required this.expectedMinLPer100Km,
    required this.expectedMaxLPer100Km,
    required this.isPlausible,
    required this.hasSufficientData,
    required this.statusLabel,
    required this.advisoryMessage,
  });
}

/// Axis B: Dashboard-Odometer Parity Engine
/// - Computes per-vehicle GPS-to-physical-odometer calibration factor
/// - Flags CR 2021/16 para 35 >2% drift alerts for recalibration
/// - Evaluates Fuel-Litres-to-Km plausibility band
class OdometerCalibrationEngine {
  OdometerCalibrationEngine._();

  static const double cr2021DriftThresholdPercent = 2.0;
  static const double minCalibrationFactor = 0.80;
  static const double maxCalibrationFactor = 1.25;

  /// Computes the vehicle's calibration multiplier from physical odometer anchors
  /// vs GPS trip distance between those anchors.
  static OdometerCalibrationResult computeCalibration({
    required Vehicle vehicle,
    required List<OdometerAnchor> anchors,
    required List<Trip> trips,
  }) {
    final validAnchors = anchors
        .where((a) => a.physicalOdometerKm.isFinite && a.physicalOdometerKm > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (validAnchors.length < 2) {
      return OdometerCalibrationResult(
        vehicleId: vehicle.id,
        calibrationFactor: 1.0,
        driftPercent: 0.0,
        requiresRecalibrationAlert: false,
        anchorCount: validAnchors.length,
        totalPhysicalDeltaKm: 0.0,
        totalGpsDeltaKm: 0.0,
        advisoryMessage:
            'Add at least 2 physical odometer anchors (fuel/service) to calibrate GPS against dashboard.',
      );
    }

    final firstAnchor = validAnchors.first;
    final lastAnchor = validAnchors.last;
    final physicalDelta =
        lastAnchor.physicalOdometerKm - firstAnchor.physicalOdometerKm;

    double gpsDelta = 0.0;
    if (firstAnchor.gpsCumulativeKm != null &&
        lastAnchor.gpsCumulativeKm != null &&
        lastAnchor.gpsCumulativeKm! > firstAnchor.gpsCumulativeKm!) {
      gpsDelta = lastAnchor.gpsCumulativeKm! - firstAnchor.gpsCumulativeKm!;
    } else {
      gpsDelta = trips
          .where((t) =>
              t.vehicleId == vehicle.id &&
              !t.isDeleted &&
              !t.date.isBefore(firstAnchor.date) &&
              !t.date.isAfter(lastAnchor.date))
          .fold<double>(0.0, (sum, t) => sum + t.distanceKm);
    }

    if (physicalDelta <= 10.0 || gpsDelta <= 10.0) {
      return OdometerCalibrationResult(
        vehicleId: vehicle.id,
        calibrationFactor: 1.0,
        driftPercent: 0.0,
        requiresRecalibrationAlert: false,
        anchorCount: validAnchors.length,
        totalPhysicalDeltaKm: double.parse(physicalDelta.toStringAsFixed(2)),
        totalGpsDeltaKm: double.parse(gpsDelta.toStringAsFixed(2)),
        advisoryMessage:
            'Need >10 km between odometer anchors to compute a reliable calibration factor.',
      );
    }

    final rawFactor = physicalDelta / gpsDelta;
    final clampedFactor = double.parse(
      rawFactor
          .clamp(minCalibrationFactor, maxCalibrationFactor)
          .toStringAsFixed(4),
    );
    final driftPercent = double.parse(
      (((physicalDelta - gpsDelta).abs() / physicalDelta) * 100.0)
          .toStringAsFixed(2),
    );
    final alert = driftPercent > cr2021DriftThresholdPercent;

    final msg = alert
        ? 'CR 2021/16 Drift Alert: Dashboard vs GPS differs by ${driftPercent.toStringAsFixed(1)}% (>2.0%). '
            'Recommended calibration factor: ${clampedFactor.toStringAsFixed(3)}x.'
        : 'Dashboard & GPS aligned within ${driftPercent.toStringAsFixed(1)}% (CR 2021/16 compliant).';

    return OdometerCalibrationResult(
      vehicleId: vehicle.id,
      calibrationFactor: clampedFactor,
      driftPercent: driftPercent,
      requiresRecalibrationAlert: alert,
      anchorCount: validAnchors.length,
      totalPhysicalDeltaKm: double.parse(physicalDelta.toStringAsFixed(2)),
      totalGpsDeltaKm: double.parse(gpsDelta.toStringAsFixed(2)),
      advisoryMessage: msg,
    );
  }

  /// Evaluates whether total fuel litres purchased is plausible against total
  /// claimed/logged km for the vehicle. Clearly labeled as an estimate.
  static FuelPlausibilityResult evaluateFuelPlausibility({
    required Vehicle vehicle,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    double? totalFuelLitresOverride,
    double? expectedMinLPer100Km,
    double? expectedMaxLPer100Km,
  }) {
    final (defaultMin, defaultMax) = _defaultConsumptionBand(vehicle.vehicleType);
    final minBand = expectedMinLPer100Km ?? defaultMin;
    final maxBand = expectedMaxLPer100Km ?? defaultMax;

    final vehicleTrips =
        trips.where((t) => t.vehicleId == vehicle.id && !t.isDeleted).toList();
    final totalKm =
        vehicleTrips.fold<double>(0.0, (sum, t) => sum + t.distanceKm);

    double totalLitres = totalFuelLitresOverride ?? 0.0;
    if (totalFuelLitresOverride == null) {
      for (final e in expenses) {
        if (e.vehicleId != vehicle.id ||
            e.isDeleted ||
            e.category != ExpenseCategory.fuel) {
          continue;
        }
        final fieldLitres = e.receiptAudit?.currentFields['litres'];
        if (fieldLitres is num && fieldLitres > 0) {
          totalLitres += fieldLitres.toDouble();
        } else {
          final parsed = _extractLitresFromNotes(e.notes);
          if (parsed != null) {
            totalLitres += parsed;
          }
        }
      }
    }

    if (totalLitres <= 0 || totalKm < 100.0) {
      return FuelPlausibilityResult(
        totalFuelLitres: double.parse(totalLitres.toStringAsFixed(1)),
        claimedKm: double.parse(totalKm.toStringAsFixed(1)),
        estimatedLitresPer100Km: null,
        expectedMinLPer100Km: minBand,
        expectedMaxLPer100Km: maxBand,
        isPlausible: true,
        hasSufficientData: false,
        statusLabel: 'Insufficient Fuel/Km Data',
        advisoryMessage:
            'Need recorded fuel litres and ≥100 km logged to estimate fuel-to-km plausibility.',
      );
    }

    final actualLPer100 =
        double.parse(((totalLitres / totalKm) * 100.0).toStringAsFixed(1));
    final plausible = actualLPer100 >= minBand && actualLPer100 <= maxBand;

    final statusLabel = plausible
        ? 'Plausible (${actualLPer100.toStringAsFixed(1)} L/100km est.)'
        : actualLPer100 < minBand
            ? 'Low Fuel vs Claimed Km (${actualLPer100.toStringAsFixed(1)} L/100km est.)'
            : 'High Fuel vs Claimed Km (${actualLPer100.toStringAsFixed(1)} L/100km est.)';

    final msg = plausible
        ? 'Estimated fuel burn ($actualLPer100 L/100km) sits within expected ${minBand.toStringAsFixed(0)}–${maxBand.toStringAsFixed(0)} L/100km band.'
        : 'Estimated fuel burn ($actualLPer100 L/100km) falls outside expected ${minBand.toStringAsFixed(0)}–${maxBand.toStringAsFixed(0)} L/100km band. Check for missing fuel receipts or unlogged trips.';

    return FuelPlausibilityResult(
      totalFuelLitres: double.parse(totalLitres.toStringAsFixed(1)),
      claimedKm: double.parse(totalKm.toStringAsFixed(1)),
      estimatedLitresPer100Km: actualLPer100,
      expectedMinLPer100Km: minBand,
      expectedMaxLPer100Km: maxBand,
      isPlausible: plausible,
      hasSufficientData: true,
      statusLabel: statusLabel,
      advisoryMessage: msg,
    );
  }

  static (double, double) _defaultConsumptionBand(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return (5.0, 12.0);
      case VehicleType.suv:
        return (6.5, 14.5);
      case VehicleType.ute:
      case VehicleType.van:
        return (7.5, 16.5);
      case VehicleType.truck:
        return (11.0, 26.0);
    }
  }

  static double? _extractLitresFromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    final match =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:l|litres|liters)\b', caseSensitive: false)
            .firstMatch(notes);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }
}
