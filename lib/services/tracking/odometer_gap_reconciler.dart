import '../../data/models/trip.dart';

/// An observed odometer difference, not evidence of a particular journey.
class OdometerGap {
  final String vehicleId;
  final double startOdo;
  final double endOdo;
  final String? legacyTripId;
  const OdometerGap(
      {required this.vehicleId,
      required this.startOdo,
      required this.endOdo,
      this.legacyTripId});
  double get distance => endOdo - startOdo;
  bool contains(double start, double end) =>
      start.isFinite &&
      end.isFinite &&
      start >= startOdo - 0.01 &&
      end <= endOdo + 0.01 &&
      end > start;
}

class OdometerGapReconciler {
  OdometerGapReconciler._();
  static const double defaultGapThresholdKm = 0.1;
  static const String bridgeEvidenceSource = 'auto_reconciled_odometer_gap';

  /// Existing inferred bridges stay unchanged in storage but need user review.
  static bool isInferredBridge(Trip trip) =>
      trip.evidenceSource == bridgeEvidenceSource ||
      trip.evidenceSource == 'poka_yoke_auto_reconcile' ||
      (trip.id.startsWith('gap_bridge_') &&
          trip.evidenceSource == 'auto_telemetry' &&
          trip.purpose == 'Personal travel (Bridging)');

  static List<OdometerGap> findGaps(
      {required String vehicleId,
      required double baseline,
      required Iterable<Trip> trips}) {
    final recorded = trips
        .where((t) =>
            t.vehicleId == vehicleId &&
            !t.isDeleted &&
            t.startOdometer.isFinite &&
            t.endOdometer.isFinite &&
            t.endOdometer > t.startOdometer)
        .toList()
      ..sort((a, b) => a.startOdometer.compareTo(b.startOdometer));
    final gaps = <OdometerGap>[];
    double? covered = baseline.isFinite && baseline > 0 ? baseline : null;
    for (final trip in recorded) {
      final previous = covered;
      if (previous != null &&
          trip.startOdometer - previous > defaultGapThresholdKm) {
        gaps.add(OdometerGap(
            vehicleId: vehicleId,
            startOdo: previous,
            endOdo: trip.startOdometer));
      }
      if (isInferredBridge(trip)) {
        gaps.add(OdometerGap(
            vehicleId: vehicleId,
            startOdo: trip.startOdometer,
            endOdo: trip.endOdometer,
            legacyTripId: trip.id));
      }
      if (covered == null || trip.endOdometer > covered) {
        covered = trip.endOdometer;
      }
    }
    return List.unmodifiable(gaps);
  }
}
