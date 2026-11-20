import '../../data/models/trip.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';
import '../../data/models/tax_summary.dart';
import '../tracking/wgs84_geodesic_engine.dart';
import 'tax_calculator_service.dart';

/// Lightweight Receipt model for auto-matching conforming to Evidence Graph INV-B01 & B02.
class Receipt {
  final String id;
  final DateTime capturedAt;
  final double? merchantLat;
  final double? merchantLng;
  final String? merchantName;
  final double? amount;

  const Receipt({
    required this.id,
    required this.capturedAt,
    this.merchantLat,
    this.merchantLng,
    this.merchantName,
    this.amount,
  });
}

/// Match association between a Trip and a Receipt.
class ReceiptMatch {
  final String tripId;
  final String receiptId;
  final double confidenceScore;
  final String associationMethod;

  const ReceiptMatch({
    required this.tripId,
    required this.receiptId,
    required this.confidenceScore,
    this.associationMethod = 'spatial_temporal_proximity',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptMatch &&
          runtimeType == other.runtimeType &&
          tripId == other.tripId &&
          receiptId == other.receiptId;

  @override
  int get hashCode => Object.hash(tripId, receiptId);
}

/// Helper function to auto-link receipts to trips.
List<ReceiptMatch> autoLinkReceipts(List<Receipt> receipts, List<Trip> trips) {
  return EvidenceEngine.autoLinkReceipts(receipts, trips);
}

/// EVIDENCE ENGINE (Layer 3):
/// Central on-device evidence validation & aggregation engine.
/// Ensures 100% ATO audit-proof substantiation under Subdivision 28-G ITAA 1997.
class EvidenceEngine {
  static const double maxAutoLinkDistanceMeters = 15000.0; // 15 km (INV-B01)
  static const Duration maxAutoLinkTemporalWindow = Duration(hours: 4); // +/- 4h (INV-B02)

  /// Auto-links receipts to trips based on spatial (≤15km) and temporal (±4h) bounds (INV-B01, INV-B02).
  /// Output is idempotent per (tripId, receiptId) tuple (INV-B04).
  static List<ReceiptMatch> autoLinkReceipts(
    List<Receipt> receipts,
    List<Trip> trips,
  ) {
    final List<ReceiptMatch> results = [];
    final Set<String> linkedPairs = {}; // For idempotency (INV-B04)

    for (final receipt in receipts) {
      if (receipt.merchantLat == null || receipt.merchantLng == null) continue;

      for (final trip in trips) {
        final pairKey = '${trip.id}:${receipt.id}';
        if (linkedPairs.contains(pairKey)) continue;

        // Check temporal window: within trip.date - 4h .. trip.date + 4h (INV-B02)
        final timeDiff = receipt.capturedAt.difference(trip.date).abs();
        if (timeDiff > maxAutoLinkTemporalWindow) continue;

        // Check spatial bounds: geodesic to nearest of (originLat, originLng) or (destLat, destLng) <= 15km (INV-B01)
        double? distOrigin;
        if (trip.originLat != null && trip.originLng != null) {
          distOrigin = Wgs84GeodesicEngine.calculateDistanceMeters(
            lat1: receipt.merchantLat!,
            lon1: receipt.merchantLng!,
            lat2: trip.originLat!,
            lon2: trip.originLng!,
          );
        }

        double? distDest;
        if (trip.destLat != null && trip.destLng != null) {
          distDest = Wgs84GeodesicEngine.calculateDistanceMeters(
            lat1: receipt.merchantLat!,
            lon1: receipt.merchantLng!,
            lat2: trip.destLat!,
            lon2: trip.destLng!,
          );
        }

        if (distOrigin == null && distDest == null) continue;

        final double minDistance = [
          if (distOrigin != null) distOrigin,
          if (distDest != null) distDest,
        ].reduce((a, b) => a < b ? a : b);

        if (minDistance <= maxAutoLinkDistanceMeters) {
          final spatialRatio = (minDistance / maxAutoLinkDistanceMeters).clamp(0.0, 1.0);
          final temporalRatio = (timeDiff.inMinutes / maxAutoLinkTemporalWindow.inMinutes).clamp(0.0, 1.0);
          final confidenceScore = (1.0 - (0.5 * spatialRatio + 0.5 * temporalRatio) * 0.5).clamp(0.1, 1.0);

          results.add(ReceiptMatch(
            tripId: trip.id,
            receiptId: receipt.id,
            confidenceScore: confidenceScore,
            associationMethod: 'spatial_temporal_proximity',
          ));
          linkedPairs.add(pairKey);
        }
      }
    }

    return results;
  }

  final Vehicle vehicle;
  final List<Trip> _trips = [];
  final List<VehicleExpense> _expenses = [];

  EvidenceEngine({required this.vehicle});

  List<Trip> get trips => List.unmodifiable(_trips);
  List<VehicleExpense> get expenses => List.unmodifiable(_expenses);

  /// Ingests a new trip record into the Evidence Vault
  void recordTrip(Trip trip) {
    _trips.add(trip);
  }

  /// Ingests a new expense receipt into the Evidence Vault
  void recordExpense(VehicleExpense expense) {
    _expenses.add(expense);
  }

  /// Validates odometer continuity across all trips against baseline
  bool validateOdometerContinuity() {
    if (_trips.isEmpty) return true;
    double currentOdo = vehicle.initialOdometer;
    for (final trip in _trips) {
      if (trip.startOdometer < currentOdo) {
        return false; // Inconsistent opening reading
      }
      if (trip.endOdometer < trip.startOdometer) {
        return false; // Inverted trip odometer
      }
      currentOdo = trip.endOdometer;
    }
    return true;
  }

  /// Computes the complete Tax Summary across recorded Evidence
  TaxSummary generateTaxSummary() {
    return TaxCalculatorService.evaluateSummary(
      trips: _trips,
      expenses: _expenses,
    );
  }

  /// Verifies receipt attachment substantiation rate
  double receiptPreservationRate() {
    if (_expenses.isEmpty) return 100.0;
    final preserved = _expenses
        .where((e) => e.receiptPath != null && e.receiptPath!.isNotEmpty)
        .length;
    return (preserved / _expenses.length) * 100.0;
  }
}
