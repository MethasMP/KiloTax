import 'package:flutter/foundation.dart';

import '../../data/models/trip.dart';

/// A captured GPS breadcrumb or stop pin along a trip route, used by the
/// Post-Trip Route Razor to trim a forgotten-stop commute tail or split a mixed trip.
@immutable
class RouteWaypoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? cumulativeKm;
  final String? label;

  const RouteWaypoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.cumulativeKm,
    this.label,
  });
}

/// Output of a Route Razor trim or split operation.
/// Guarantees odometer conservation (`primary.startOdometer == original.startOdometer`,
/// `secondary.endOdometer == original.endOdometer`, and `primary.endOdometer == secondary.startOdometer`)
/// while retaining an immutable raw telemetry snapshot in `review['routeRazorAudit']`.
@immutable
class RouteRazorResult {
  final Trip primaryTrip;
  final Trip secondaryTrip;
  final Map<String, dynamic> rawAuditSnapshot;
  final bool odometerConserved;

  const RouteRazorResult({
    required this.primaryTrip,
    required this.secondaryTrip,
    required this.rawAuditSnapshot,
    required this.odometerConserved,
  });
}

/// Axis A: Post-Trip "Route Razor"
/// Lets a tradie trim a forgotten-stop commute tail or split a mixed trip into
/// Business + Personal legs while preserving raw telemetry & odometer conservation.
class TripRouteRazor {
  TripRouteRazor._();

  /// Trims a forgotten-stop tail at [splitDistanceKm] (creating a Business primary
  /// leg and a Personal commute tail).
  static RouteRazorResult trimTailAtDistance({
    required Trip original,
    required double splitDistanceKm,
    required String secondaryTripId,
    RouteWaypoint? splitWaypoint,
    String? primaryPurposeOverride,
    String tailPurpose = 'Commute / Personal Tail',
    TripClassification tailClassification = TripClassification.personal,
    DateTime? razoredAt,
  }) {
    return _razorTrip(
      original: original,
      splitDistanceKm: splitDistanceKm,
      secondaryTripId: secondaryTripId,
      splitWaypoint: splitWaypoint,
      primaryPurposeOverride: primaryPurposeOverride,
      secondaryPurpose: tailPurpose,
      secondaryClassification: tailClassification,
      operation: 'trim_tail',
      razoredAt: razoredAt,
    );
  }

  /// Trims a forgotten-stop tail at a specific [waypoint].
  /// Requires [waypoint.cumulativeKm] to be within `(0, original.distanceKm)`.
  static RouteRazorResult trimTailAtWaypoint({
    required Trip original,
    required RouteWaypoint waypoint,
    required String secondaryTripId,
    String? primaryPurposeOverride,
    String tailPurpose = 'Commute / Personal Tail',
    TripClassification tailClassification = TripClassification.personal,
    DateTime? razoredAt,
  }) {
    final splitKm = waypoint.cumulativeKm;
    if (splitKm == null || !splitKm.isFinite) {
      throw ArgumentError(
          'Waypoint must include a finite cumulativeKm to trim at waypoint.');
    }
    return trimTailAtDistance(
      original: original,
      splitDistanceKm: splitKm,
      secondaryTripId: secondaryTripId,
      splitWaypoint: waypoint,
      primaryPurposeOverride: primaryPurposeOverride,
      tailPurpose: tailPurpose,
      tailClassification: tailClassification,
      razoredAt: razoredAt,
    );
  }

  /// Splits a mixed trip into Business leg 1 and Personal leg 2 at [businessKm].
  static RouteRazorResult splitMixedTrip({
    required Trip original,
    required double businessKm,
    required String secondaryTripId,
    RouteWaypoint? splitWaypoint,
    String? businessPurposeOverride,
    String personalPurpose = 'Personal Leg (Split)',
    DateTime? razoredAt,
  }) {
    return _razorTrip(
      original: original,
      splitDistanceKm: businessKm,
      secondaryTripId: secondaryTripId,
      splitWaypoint: splitWaypoint,
      primaryPurposeOverride: businessPurposeOverride,
      secondaryPurpose: personalPurpose,
      secondaryClassification: TripClassification.personal,
      operation: 'split_mixed',
      razoredAt: razoredAt,
    );
  }

  static RouteRazorResult _razorTrip({
    required Trip original,
    required double splitDistanceKm,
    required String secondaryTripId,
    RouteWaypoint? splitWaypoint,
    String? primaryPurposeOverride,
    required String secondaryPurpose,
    required TripClassification secondaryClassification,
    required String operation,
    DateTime? razoredAt,
  }) {
    if (original.distanceKm <= 0.2) {
      throw ArgumentError(
          'Trip distance (${original.distanceKm} km) is too short to razor.');
    }
    if (!splitDistanceKm.isFinite ||
        splitDistanceKm <= 0.05 ||
        splitDistanceKm >= original.distanceKm - 0.05) {
      throw ArgumentError(
        'Split distance ($splitDistanceKm km) must be strictly between 0.05 and ${original.distanceKm - 0.05} km.',
      );
    }

    final primaryKm = double.parse(splitDistanceKm.toStringAsFixed(2));
    final secondaryKm =
        double.parse((original.distanceKm - primaryKm).toStringAsFixed(2));
    final ratio = primaryKm / original.distanceKm;

    // Conserve odometer span proportionally if endOdometer > startOdometer.
    final hasOdo = original.endOdometer > original.startOdometer;
    final odoSpan = hasOdo ? (original.endOdometer - original.startOdometer) : 0.0;
    final midOdo = hasOdo
        ? double.parse(
            (original.startOdometer + odoSpan * ratio).toStringAsFixed(2),
          )
        : 0.0;
    final primaryStartOdo = hasOdo ? original.startOdometer : 0.0;
    final primaryEndOdo = hasOdo ? midOdo : 0.0;
    final secondaryStartOdo = hasOdo ? midOdo : 0.0;
    final secondaryEndOdo = hasOdo ? original.endOdometer : 0.0;

    final splitTime = splitWaypoint?.timestamp ??
        original.date.add(
          Duration(
            seconds: ((original.stoppedAt ?? original.date)
                        .difference(original.date)
                        .inSeconds *
                    ratio)
                .round(),
          ),
        );

    final nowIso = (razoredAt ?? DateTime.now()).toIso8601String();
    final auditSnapshot = <String, dynamic>{
      'operation': operation,
      'razoredAt': nowIso,
      'originalTripId': original.id,
      'originalDistanceKm': original.distanceKm,
      'originalStartOdometer': original.startOdometer,
      'originalEndOdometer': original.endOdometer,
      'originalEndLat': original.endLat,
      'originalEndLng': original.endLng,
      'originalDestinationAddress': original.destinationAddress,
      'originalEvidenceSource': original.evidenceSource,
      'secondaryTripId': secondaryTripId,
    };

    final primaryReview = <String, dynamic>{
      ...original.review,
      'businessKm': primaryKm,
      'routeRazorAudit': auditSnapshot,
    };

    final secondaryReview = <String, dynamic>{
      'businessKm':
          secondaryClassification == TripClassification.business ? secondaryKm : 0.0,
      'routeRazorAudit': auditSnapshot,
    };

    final primaryTrip = original.copyWith(
      distanceKm: primaryKm,
      purpose: (primaryPurposeOverride != null &&
              primaryPurposeOverride.trim().isNotEmpty)
          ? primaryPurposeOverride.trim()
          : original.purpose,
      startOdometer: primaryStartOdo,
      endOdometer: primaryEndOdo,
      classification: TripClassification.business,
      destinationAddress:
          splitWaypoint?.label ?? 'Trimmed Stop (${primaryKm.toStringAsFixed(1)} km)',
      endLat: splitWaypoint?.lat,
      endLng: splitWaypoint?.lng,
      stoppedAt: splitTime,
      review: primaryReview,
    );

    final secondaryTrip = Trip(
      id: secondaryTripId,
      vehicleId: original.vehicleId,
      distanceKm: secondaryKm,
      date: splitTime,
      purpose: secondaryPurpose,
      startOdometer: secondaryStartOdo,
      endOdometer: secondaryEndOdo,
      classification: secondaryClassification,
      originAddress: splitWaypoint?.label ?? primaryTrip.destinationAddress,
      destinationAddress: original.destinationAddress,
      taxMethod: original.taxMethod,
      evidenceSource: '${original.evidenceSource}_razored',
      startLat: splitWaypoint?.lat,
      startLng: splitWaypoint?.lng,
      endLat: original.endLat,
      endLng: original.endLng,
      stoppedAt: original.stoppedAt,
      review: secondaryReview,
    );

    final conserved = !hasOdo ||
        ((primaryTrip.startOdometer - original.startOdometer).abs() < 0.01 &&
            (secondaryTrip.endOdometer - original.endOdometer).abs() < 0.01 &&
            (primaryTrip.endOdometer - secondaryTrip.startOdometer).abs() < 0.01);

    return RouteRazorResult(
      primaryTrip: primaryTrip,
      secondaryTrip: secondaryTrip,
      rawAuditSnapshot: auditSnapshot,
      odometerConserved: conserved,
    );
  }
}
