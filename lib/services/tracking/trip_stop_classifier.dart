import 'package:flutter/foundation.dart';

import '../../data/models/job_site.dart';
import '../../data/models/trade_persona.dart';
import '../../data/models/trip.dart';
import '../../data/models/user_profile.dart';
import 'trade_poi_resolver.dart';
import 'wgs84_geodesic_engine.dart';

/// Semantic classification of an intermediate stop detected during a trip.
enum StopClassification {
  /// Short stop (< 15 min) at fuel, trade supplier, drive-thru, or traffic.
  /// Trip remains continuous; stop is recorded as an intermediate waypoint.
  pitStopPending,

  /// Stop >= 3 min at a saved [JobSite] or >= 15 min at a trade supplier.
  jobStopSplit,

  /// Stop >= 3 min at the user's home base coordinates.
  homeStopSplit,

  /// Stop >= 3 min at a non-trade personal POI (school, gym, supermarket, etc.).
  personalStopSplit,

  /// Unclassified stop >= 15 min that should cleanly end the leg.
  unclassifiedSplit,
}

/// Input context for evaluating whether a dwell event should split a trip.
@immutable
class StopContextInput {
  final Duration dwellDuration;
  final double? latitude;
  final double? longitude;
  final String? placeNameOrAddress;
  final UserProfile? userProfile;
  final List<JobSite> jobSites;
  final TradePersona? tradePersona;

  const StopContextInput({
    required this.dwellDuration,
    this.latitude,
    this.longitude,
    this.placeNameOrAddress,
    this.userProfile,
    this.jobSites = const [],
    this.tradePersona,
  });
}

/// Result of classifying a stop under Axis A Context-Aware Pit-Stop vs Job-Stop.
@immutable
class StopClassificationResult {
  final StopClassification classification;
  final bool shouldSplitTrip;
  final String reason;
  final JobSite? matchedJobSite;
  final TradePoiMatch? matchedTradePoi;

  const StopClassificationResult({
    required this.classification,
    required this.shouldSplitTrip,
    required this.reason,
    this.matchedJobSite,
    this.matchedTradePoi,
  });

  bool get isPitStop => classification == StopClassification.pitStopPending;
}

/// Candidate group of consecutive same-day business trips eligible for
/// ITAA 1997 s 28-125(3) single-journey chaining.
@immutable
class SameDayChainCandidate {
  final String vehicleId;
  final DateTime day;
  final List<Trip> trips;
  final double totalDistanceKm;
  final double startOdometer;
  final double endOdometer;
  final String suggestedCombinedPurpose;

  const SameDayChainCandidate({
    required this.vehicleId,
    required this.day,
    required this.trips,
    required this.totalDistanceKm,
    required this.startOdometer,
    required this.endOdometer,
    required this.suggestedCombinedPurpose,
  });
}

/// Axis A: Context-Aware Pit-Stop vs Job-Stop Classifier & ITAA 1997 s 28-125(3)
/// Same-Day Business Journey Chaining Engine.
class TripStopClassifier {
  TripStopClassifier._();

  static const Duration minAnchorStopDwell = Duration(minutes: 3);
  static const Duration maxPitStopDwell = Duration(minutes: 15);

  static const List<String> _pitStopKeywords = [
    'bp',
    'shell',
    'caltex',
    'ampol',
    '7-eleven',
    '7 eleven',
    'united petroleum',
    'metro petroleum',
    'liberty',
    'servo',
    'fuel',
    'petrol',
    'diesel',
    'drive-thru',
    'drive thru',
    'mcdonald',
    'hungry jack',
    'kfc',
    'coffee',
    'zarraffa',
    'gloria jean',
    'rest area',
  ];

  static const List<String> _personalPoiKeywords = [
    'school',
    'childcare',
    'kindergarten',
    'gym',
    'fitness',
    'pub',
    'hotel',
    'tavern',
    'bws',
    'dan murphy',
    'woolworths',
    'coles',
    'aldi',
    'iga',
    'supermarket',
    'restaurant',
    'cinema',
    'medical',
    'clinic',
    'hospital',
    'pharmacy',
    'chemist',
    'westfield',
  ];

  /// Classifies a dwell stop as either a continuous pit-stop or a leg-splitting
  /// job/home/personal stop.
  static StopClassificationResult classifyStop(StopContextInput input) {
    final dwell = input.dwellDuration;
    final lat = input.latitude;
    final lng = input.longitude;

    // 1. Home base geofence check (>= 3 min splits leg).
    final profile = input.userProfile;
    if (profile != null &&
        profile.hasHomeCoordinates &&
        lat != null &&
        lng != null) {
      final distToHome = Wgs84GeodesicEngine.calculateDistanceMeters(
        lat1: profile.homeLatitude!,
        lon1: profile.homeLongitude!,
        lat2: lat,
        lon2: lng,
      );
      if (distToHome <= profile.homeRadiusMeters &&
          dwell >= minAnchorStopDwell) {
        return StopClassificationResult(
          classification: StopClassification.homeStopSplit,
          shouldSplitTrip: true,
          reason:
              'Stopped ${dwell.inMinutes}m at Home Base (${distToHome.round()}m)',
        );
      }
    }

    // 2. Active JobSite geofence check (>= 3 min splits leg).
    if (lat != null && lng != null) {
      for (final site in input.jobSites) {
        if (!site.isActive || !site.trackingEnabled) continue;
        if (site.containsCoordinate(lat: lat, lng: lng)) {
          if (dwell >= minAnchorStopDwell) {
            return StopClassificationResult(
              classification: StopClassification.jobStopSplit,
              shouldSplitTrip: true,
              reason:
                  'Stopped ${dwell.inMinutes}m at Job Site "${site.name}"',
              matchedJobSite: site,
            );
          }
          return StopClassificationResult(
            classification: StopClassification.pitStopPending,
            shouldSplitTrip: false,
            reason:
                'Brief (<3m) pass-through at Job Site "${site.name}"',
            matchedJobSite: site,
          );
        }
      }
    }

    // 3. Trade supplier check (Bunnings, Reece, etc.).
    final tradeMatch = TradePoiResolver.resolve(
      input.placeNameOrAddress,
      persona: input.tradePersona,
    );
    if (tradeMatch != null) {
      if (dwell < maxPitStopDwell) {
        return StopClassificationResult(
          classification: StopClassification.pitStopPending,
          shouldSplitTrip: false,
          reason:
              'Short trade supply pit-stop (${dwell.inMinutes}m) at ${tradeMatch.merchantName} — keeping trip continuous',
          matchedTradePoi: tradeMatch,
        );
      }
      return StopClassificationResult(
        classification: StopClassification.jobStopSplit,
        shouldSplitTrip: true,
        reason:
            'Extended stop (${dwell.inMinutes}m) at ${tradeMatch.merchantName}',
        matchedTradePoi: tradeMatch,
      );
    }

    final lowerPlace = (input.placeNameOrAddress ?? '').toLowerCase();

    // 4. Non-trade personal POI check (>= 3 min splits leg).
    if (lowerPlace.isNotEmpty &&
        _personalPoiKeywords.any((kw) => lowerPlace.contains(kw)) &&
        dwell >= minAnchorStopDwell) {
      return StopClassificationResult(
        classification: StopClassification.personalStopSplit,
        shouldSplitTrip: true,
        reason: 'Stopped ${dwell.inMinutes}m at personal POI',
      );
    }

    // 5. Fuel / coffee / drive-thru pit-stop check (< 15 min stays continuous).
    if (lowerPlace.isNotEmpty &&
        _pitStopKeywords.any((kw) => lowerPlace.contains(kw)) &&
        dwell < maxPitStopDwell) {
      return StopClassificationResult(
        classification: StopClassification.pitStopPending,
        shouldSplitTrip: false,
        reason:
            'Short pit-stop (${dwell.inMinutes}m) — keeping trip continuous',
      );
    }

    // 6. Generic duration fallback.
    if (dwell < maxPitStopDwell) {
      return StopClassificationResult(
        classification: StopClassification.pitStopPending,
        shouldSplitTrip: false,
        reason: 'Brief stop (${dwell.inMinutes}m < 15m) held as pit-stop',
      );
    }

    return StopClassificationResult(
      classification: StopClassification.unclassifiedSplit,
      shouldSplitTrip: true,
      reason: 'Extended stop (${dwell.inMinutes}m >= 15m) splits leg',
    );
  }

  /// Finds groups of 2+ consecutive same-day business trips on the same vehicle
  /// eligible for ITAA 1997 s 28-125(3) single-journey chaining.
  static List<SameDayChainCandidate> findSameDayChainCandidates(
    List<Trip> trips, {
    Duration maxInterTripGap = const Duration(minutes: 45),
  }) {
    final active = trips.where((t) => !t.isDeleted).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Group all active trips by (vehicleId, calendarDay) so personal trips
    // between two business trips break the consecutive sequence.
    final byVehicleDay = <String, List<Trip>>{};
    for (final trip in active) {
      final dayKey =
          '${trip.vehicleId}|${trip.date.year}-${trip.date.month}-${trip.date.day}';
      byVehicleDay.putIfAbsent(dayKey, () => []).add(trip);
    }

    final candidates = <SameDayChainCandidate>[];
    for (final dayTrips in byVehicleDay.values) {
      var currentRun = <Trip>[];

      void flushRun() {
        if (currentRun.length >= 2) {
          final first = currentRun.first;
          final last = currentRun.last;
          final totalKm = currentRun.fold<double>(
            0.0,
            (sum, t) => sum + t.distanceKm,
          );
          final purposes = currentRun
              .map((t) => t.purpose.trim())
              .where((p) => p.isNotEmpty)
              .toSet()
              .toList();
          candidates.add(
            SameDayChainCandidate(
              vehicleId: first.vehicleId,
              day: DateTime(first.date.year, first.date.month, first.date.day),
              trips: List.unmodifiable(currentRun),
              totalDistanceKm: double.parse(totalKm.toStringAsFixed(2)),
              startOdometer: first.startOdometer,
              endOdometer: last.endOdometer,
              suggestedCombinedPurpose: purposes.isEmpty
                  ? 'Consecutive Business Run (s 28-125(3))'
                  : purposes.join(' → '),
            ),
          );
        }
        currentRun = [];
      }

      for (final trip in dayTrips) {
        if (!trip.isBusiness) {
          flushRun();
          continue;
        }
        if (currentRun.isEmpty) {
          currentRun.add(trip);
          continue;
        }
        final prev = currentRun.last;
        final prevEnd = prev.stoppedAt ?? prev.date;
        final gap = trip.date.difference(prevEnd);
        final odoContiguous = prev.endOdometer > 0 &&
            trip.startOdometer > 0 &&
            (trip.startOdometer - prev.endOdometer).abs() <= 0.2;

        if ((gap <= maxInterTripGap && gap >= Duration.zero) || odoContiguous) {
          currentRun.add(trip);
        } else {
          flushRun();
          currentRun.add(trip);
        }
      }
      flushRun();
    }

    return candidates;
  }

  /// Combines a consecutive same-day business run into a single [Trip] record
  /// under ITAA 1997 s 28-125(3), preserving all linked evidence and source IDs.
  static Trip chainBusinessTrips(
    List<Trip> chain, {
    required String combinedTripId,
    String? purposeOverride,
  }) {
    if (chain.length < 2) {
      throw ArgumentError('At least 2 trips are required to chain a journey.');
    }
    final sorted = [...chain]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first;
    final last = sorted.last;

    final totalDistanceKm = double.parse(
      sorted.fold<double>(0.0, (sum, t) => sum + t.distanceKm).toStringAsFixed(2),
    );
    final mergedExpenses = <String>{
      for (final t in sorted) ...t.linkedExpenseIds,
    }.toList();
    final mergedEvidenceLinks = <TripEvidenceLink>[
      for (final t in sorted) ...t.evidenceLinks,
    ];
    final purposes = sorted
        .map((t) => t.purpose.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    final startOdo = first.startOdometer;
    final endOdo = last.endOdometer >= startOdo ? last.endOdometer : startOdo;

    return Trip(
      id: combinedTripId,
      vehicleId: first.vehicleId,
      distanceKm: totalDistanceKm,
      date: first.date,
      purpose: (purposeOverride != null && purposeOverride.trim().isNotEmpty)
          ? purposeOverride.trim()
          : (purposes.isEmpty
              ? 'Consecutive Business Run (s 28-125(3))'
              : purposes.join(' → ')),
      startOdometer: startOdo,
      endOdometer: endOdo,
      classification: TripClassification.business,
      originAddress: first.originAddress,
      destinationAddress: last.destinationAddress,
      linkedExpenseIds: mergedExpenses,
      taxMethod: first.taxMethod,
      evidenceSource: 'chained_s28_125_3',
      jobReference: first.jobReference ?? last.jobReference,
      jobId: first.jobId ?? last.jobId,
      routePolyline: first.routePolyline ?? last.routePolyline,
      startLat: first.startLat,
      startLng: first.startLng,
      endLat: last.endLat,
      endLng: last.endLng,
      stoppedAt: last.stoppedAt ?? last.date,
      stoppedDuration: last.stoppedDuration,
      evidenceLinks: mergedEvidenceLinks,
      review: {
        ...first.review,
        'statutoryBasis': 'ITAA 1997 s 28-125(3)',
        'chainedTripIds': sorted.map((t) => t.id).toList(),
        'chainedLegCount': sorted.length,
        'chainedAt': DateTime.now().toIso8601String(),
      },
    );
  }
}
