import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import '../tracking/trade_poi_resolver.dart';
import '../tracking/wgs84_geodesic_engine.dart';

/// Result of an automated evidence match attempt between an Expense receipt and a Trip.
class EvidenceMatchResult {
  final Trip trip;
  final double confidenceScore; // 0.0 to 1.0
  final String matchReason;
  final double distanceKm;
  final Duration timeDifference;
  final bool isTradeSupplyMatch;

  const EvidenceMatchResult({
    required this.trip,
    required this.confidenceScore,
    required this.matchReason,
    required this.distanceKm,
    required this.timeDifference,
    this.isTradeSupplyMatch = false,
  });
}

/// Spatio-Temporal Matcher Service & Evidence Auto-Match Engine
/// (Phase 2: Complete Evidence Graph Engine)
///
/// Automatically correlates an expense receipt (fuel docket, Bunnings, service)
/// to the closest legitimate work trip using:
/// 1. Fuel stops:
///    - Trip end/start within 300m of expense GPS, OR
///    - Expense timestamp within +/- 30 minutes of trip start/end time.
/// 2. Bunnings / Trade Supply stops:
///    - Trip destination is a trade hardware store (Bunnings, Reece, Bowens, Mitre 10, etc.)
///      or waypoint, automatically linking expense to trip.
/// 3. Vehicle Continuity (Same vehicle ID).
/// 4. Bidirectional link helper to maintain:
///    `expense.linkedTripId = trip.id` and `trip.linkedExpenseIds.contains(expense.id)`.
class EvidenceAutoMatchEngine {
  /// Maximum time delta to consider a trip correlated with an expense receipt (e.g. filled fuel within 4 hours of driving)
  static const Duration maxTimeWindow = Duration(hours: 4);

  /// Fuel stop spatial radius threshold (300 meters)
  static const double fuelStopGpsThresholdMeters = 300.0;

  /// Fuel stop temporal window (+/- 30 minutes)
  static const Duration fuelStopTemporalWindow = Duration(minutes: 30);

  /// Maximum physical distance from a trip endpoint to consider a local stop (e.g. petrol station within 8 km of route)
  static const double maxSpatialDistanceKm = 8.0;

  /// Bidirectionally links a [VehicleExpense] and a [Trip] in an immutable and idempotent manner.
  /// Sets:
  /// - `expense.linkedTripId = trip.id`
  /// - `trip.linkedExpenseIds.contains(expense.id)`
  static ({VehicleExpense updatedExpense, Trip updatedTrip}) linkBidirectionally({
    required VehicleExpense expense,
    required Trip trip,
  }) {
    final updatedExpense = expense.copyWith(linkedTripId: trip.id);

    final currentExpenseIds = List<String>.from(trip.linkedExpenseIds);
    if (!currentExpenseIds.contains(expense.id)) {
      currentExpenseIds.add(expense.id);
    }

    final updatedTrip = trip.copyWith(linkedExpenseIds: currentExpenseIds);

    return (updatedExpense: updatedExpense, updatedTrip: updatedTrip);
  }

  /// Bidirectionally unlinks an expense from a trip.
  static ({VehicleExpense updatedExpense, Trip updatedTrip}) unlinkBidirectionally({
    required VehicleExpense expense,
    required Trip trip,
  }) {
    final updatedExpense = expense.copyWith(clearLinkedTripId: true);
    final currentExpenseIds = trip.linkedExpenseIds.where((id) => id != expense.id).toList();
    final updatedTrip = trip.copyWith(linkedExpenseIds: currentExpenseIds);

    return (updatedExpense: updatedExpense, updatedTrip: updatedTrip);
  }

  /// Evaluates an expense against candidate trips and finds the best matching trip if confident.
  ///
  /// INVARIANT (ATO 2-Bucket Rule):
  /// 1. General vehicle running costs (Fuel, Rego, Insurance, Servicing/Tyres, Interest)
  ///    belong to the vehicle's annual running pool scaled by Logbook Business %.
  ///    They MUST NOT be individual-trip matched, eliminating false links and user confusion.
  /// 2. Direct Job Site / Materials expenses (Tools & Materials) are eligible for
  ///    correlating with matching trade hardware stops on the same day.
  static EvidenceMatchResult? findBestMatchingTrip({
    required VehicleExpense expense,
    required List<Trip> candidateTrips,
    double? receiptLatitude,
    double? receiptLongitude,
    double? tripLatitude,
    double? tripLongitude,
    double? tripStartLatitude,
    double? tripStartLongitude,
  }) {
    if (candidateTrips.isEmpty) return null;

    // Rule 1: Vehicle running pool expenses are strictly pooled, never individual-trip linked
    if (expense.category.isCarExpense) {
      return null;
    }

    final expenseTime = expense.date;
    final vehicleId = expense.vehicleId;

    // Filter to trips by same vehicle on the same date/window
    final eligibleTrips = candidateTrips.where((t) {
      if (t.vehicleId != vehicleId) return false;
      // Statutory Firewall: Personal trips cannot be linked to substantiate business deductions
      if (t.classification == TripClassification.personal) return false;

      // Same calendar day check or within maxTimeWindow
      final isSameDay = t.date.year == expenseTime.year &&
          t.date.month == expenseTime.month &&
          t.date.day == expenseTime.day;
      final diff = (t.date.difference(expenseTime)).abs();
      return isSameDay || diff <= maxTimeWindow;
    }).toList();

    if (eligibleTrips.isEmpty) return null;

    EvidenceMatchResult? bestMatch;
    double highestScore = 0.0;

    for (final trip in eligibleTrips) {
      final timeDiff = (trip.date.difference(expenseTime)).abs();
      final timeMinutes = timeDiff.inMinutes.toDouble();

      // Check distance if GPS available
      double shortestDistMeters = double.infinity;
      double shortestDistKm = 0.0;

      if (receiptLatitude != null && receiptLongitude != null) {
        // Check trip destination (tripLatitude / tripLongitude)
        if (tripLatitude != null && tripLongitude != null) {
          final destDist = Wgs84GeodesicEngine.calculateDistanceMeters(
            lat1: receiptLatitude,
            lon1: receiptLongitude,
            lat2: tripLatitude,
            lon2: tripLongitude,
          );
          if (destDist < shortestDistMeters) shortestDistMeters = destDist;
        }

        // Check trip start (tripStartLatitude / tripStartLongitude)
        if (tripStartLatitude != null && tripStartLongitude != null) {
          final startDist = Wgs84GeodesicEngine.calculateDistanceMeters(
            lat1: receiptLatitude,
            lon1: receiptLongitude,
            lat2: tripStartLatitude,
            lon2: tripStartLongitude,
          );
          if (startDist < shortestDistMeters) shortestDistMeters = startDist;
        }

        if (shortestDistMeters != double.infinity) {
          shortestDistKm = shortestDistMeters / 1000.0;
        }
      }

      // --- CRITERIA B: BUNNINGS / TRADE SUPPLY STOPS ---
      // If trip destination or purpose or notes is a trade hardware store (Bunnings, Reece, etc.)
      final destPoi = TradePoiResolver.resolve(trip.destinationAddress);
      final origPoi = TradePoiResolver.resolve(trip.originAddress);
      final purposePoi = TradePoiResolver.resolve(trip.purpose);
      final isTradeSupplyStop = destPoi != null || origPoi != null || purposePoi != null ||
          _isTradeMerchantText(trip.destinationAddress) ||
          _isTradeMerchantText(trip.purpose);

      final isSupplyExpense = expense.category == ExpenseCategory.toolsMaterials ||
          _isTradeMerchantText(expense.notes) ||
          _isTradeMerchantText(expense.receiptAudit?.ocrMerchant);

      if (isTradeSupplyStop && isSupplyExpense) {
        final matchedMerchant = destPoi?.merchantName ??
            origPoi?.merchantName ??
            purposePoi?.merchantName ??
            'Trade Hardware Supplier';
        final confidence = 0.98;
        if (confidence > highestScore) {
          highestScore = confidence;
          bestMatch = EvidenceMatchResult(
            trip: trip,
            confidenceScore: confidence,
            matchReason: 'Matched trade supply stop at $matchedMerchant for trip on ${trip.date.day}/${trip.date.month}',
            distanceKm: shortestDistKm,
            timeDifference: timeDiff,
            isTradeSupplyMatch: true,
          );
          continue;
        }
      }

      // --- CRITERIA A: FUEL STOPS ---
      final isFuelExpense = expense.category == ExpenseCategory.fuel;
      final isGpsWithin300m = shortestDistMeters <= fuelStopGpsThresholdMeters;
      final isTimeWithin30m = timeDiff <= fuelStopTemporalWindow;

      if (isFuelExpense && (isGpsWithin300m || isTimeWithin30m)) {
        double fuelScore = 0.92;
        String fuelReason;
        if (isGpsWithin300m && isTimeWithin30m) {
          fuelScore = 0.99;
          fuelReason = 'Matched work trip with verified fuel stop within ${shortestDistMeters.round()}m of route terminal and ${timeDiff.inMinutes} mins of trip';
        } else if (isGpsWithin300m) {
          fuelScore = 0.95;
          fuelReason = 'Matched work trip: fuel stop location verified within ${shortestDistMeters.round()}m of route endpoint';
        } else {
          fuelScore = 0.90;
          fuelReason = 'Matched work trip: fuel stop timestamp matched within ${timeDiff.inMinutes} mins of trip completion';
        }

        if (fuelScore > highestScore) {
          highestScore = fuelScore;
          bestMatch = EvidenceMatchResult(
            trip: trip,
            confidenceScore: fuelScore,
            matchReason: fuelReason,
            distanceKm: shortestDistKm,
            timeDifference: timeDiff,
          );
          continue;
        }
      }

      // --- GENERAL SCORING FALLBACK ---
      final timeScore = (1.0 - (timeMinutes / maxTimeWindow.inMinutes)).clamp(0.0, 1.0);
      double spatialScore = 0.5;
      if (shortestDistMeters != double.infinity) {
        if (shortestDistKm > maxSpatialDistanceKm) {
          spatialScore = 0.0;
        } else {
          spatialScore = (1.0 - (shortestDistKm / maxSpatialDistanceKm)).clamp(0.0, 1.0);
        }
      }

      double categoryMultiplier = 1.0;
      if (expense.category == ExpenseCategory.fuel || expense.category == ExpenseCategory.tollsParking) {
        categoryMultiplier = 1.15;
      }

      final combinedScore = ((timeScore * 0.6 + spatialScore * 0.4) * categoryMultiplier).clamp(0.0, 1.0);

      if (combinedScore >= 0.60 && combinedScore > highestScore) {
        highestScore = combinedScore;
        String reason = 'Matched work trip on ${trip.date.day}/${trip.date.month} within ${timeMinutes.round()} mins';
        if (shortestDistKm > 0.0) {
          reason += ' (${shortestDistKm.toStringAsFixed(1)} km from trip)';
        }

        bestMatch = EvidenceMatchResult(
          trip: trip,
          confidenceScore: combinedScore,
          matchReason: reason,
          distanceKm: shortestDistKm,
          timeDifference: timeDiff,
        );
      }
    }

    return bestMatch;
  }

  static bool _isTradeMerchantText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains('bunnings') ||
        lower.contains('reece') ||
        lower.contains('mitre 10') ||
        lower.contains('bowens') ||
        lower.contains('tradelink') ||
        lower.contains('total tools') ||
        lower.contains('sydney tools') ||
        lower.contains('stratco') ||
        lower.contains('middy');
  }
}

/// Alias for SpatioTemporalMatcherService to support either naming cleanly
typedef SpatioTemporalMatcherService = EvidenceAutoMatchEngine;
