import 'package:flutter/foundation.dart';

import '../../data/models/trip.dart';

/// Summary of privacy redaction applied across a list of trips.
@immutable
class RedactionSummary {
  final int redactedTripCount;
  final int preservedTripCount;
  final double totalPersonalKmPreserved;

  const RedactionSummary({
    required this.redactedTripCount,
    required this.preservedTripCount,
    required this.totalPersonalKmPreserved,
  });
}

/// Output of [PrivacyRedactor.redactTrips].
@immutable
class RedactedTripBatch {
  final List<Trip> trips;
  final RedactionSummary summary;

  const RedactedTripBatch({
    required this.trips,
    required this.summary,
  });
}

/// Axis C: Stealth Personal Mode & Selective Privacy Redactor
/// Strips GPS coordinates, route polylines, POI metadata, and street addresses
/// from Personal trips and Mixed private legs while preserving Date + Km +
/// Odometer Span required for the ATO business-use denominator.
class PrivacyRedactor {
  PrivacyRedactor._();

  static const String redactedAddressLabel = 'Private (Redacted)';
  static const String mixedRedactedAddressLabel =
      'Mixed (Private Leg Redacted)';

  /// Returns a privacy-redacted copy of [trip] if it is Personal or Mixed.
  /// Pure Business, Unclassified, and deleted trips are returned unchanged.
  static Trip redactTrip(Trip trip) {
    if (trip.isDeleted) return trip;

    if (trip.classification == TripClassification.personal) {
      return Trip(
        id: trip.id,
        vehicleId: trip.vehicleId,
        distanceKm: trip.distanceKm,
        date: trip.date,
        purpose: 'Personal',
        startOdometer: trip.startOdometer,
        endOdometer: trip.endOdometer,
        classification: TripClassification.personal,
        originAddress: redactedAddressLabel,
        destinationAddress: redactedAddressLabel,
        linkedExpenseIds: const [],
        clientDedupId: trip.clientDedupId,
        deletedAt: trip.deletedAt,
        taxMethod: trip.taxMethod,
        evidenceSource: trip.evidenceSource,
        jobReference: null,
        jobId: null,
        routePolyline: null,
        detectedPoi: null,
        isPassengerUnverified: trip.isPassengerUnverified,
        startLat: null,
        startLng: null,
        endLat: null,
        endLng: null,
        stoppedAt: trip.stoppedAt,
        stoppedDuration: trip.stoppedDuration,
        evidenceLinks: const [],
        review: {
          ...trip.review,
          'privacyRedacted': true,
          'businessKm': 0.0,
        },
      );
    }

    if (trip.isMixed) {
      return Trip(
        id: trip.id,
        vehicleId: trip.vehicleId,
        distanceKm: trip.distanceKm,
        date: trip.date,
        purpose: trip.purpose,
        startOdometer: trip.startOdometer,
        endOdometer: trip.endOdometer,
        classification: trip.classification,
        originAddress: trip.originAddress,
        destinationAddress: mixedRedactedAddressLabel,
        linkedExpenseIds: trip.linkedExpenseIds,
        clientDedupId: trip.clientDedupId,
        deletedAt: trip.deletedAt,
        taxMethod: trip.taxMethod,
        evidenceSource: trip.evidenceSource,
        jobReference: trip.jobReference,
        jobId: trip.jobId,
        routePolyline: null,
        detectedPoi: null,
        isPassengerUnverified: trip.isPassengerUnverified,
        startLat: trip.startLat,
        startLng: trip.startLng,
        endLat: null,
        endLng: null,
        stoppedAt: trip.stoppedAt,
        stoppedDuration: trip.stoppedDuration,
        evidenceLinks: trip.evidenceLinks,
        review: {
          ...trip.review,
          'privacyRedacted': true,
          'businessKm': trip.businessDistanceKm,
        },
      );
    }

    return trip;
  }

  /// Redacts a batch of trips for cloud sync or accountant export, returning
  /// the redacted list and a [RedactionSummary].
  static RedactedTripBatch redactTrips(List<Trip> trips) {
    int redactedCount = 0;
    int preservedCount = 0;
    double personalKm = 0.0;

    final out = <Trip>[];
    for (final trip in trips) {
      if (!trip.isDeleted &&
          (trip.classification == TripClassification.personal || trip.isMixed)) {
        redactedCount++;
        personalKm += (trip.distanceKm - trip.businessDistanceKm).clamp(0.0, trip.distanceKm);
        out.add(redactTrip(trip));
      } else {
        preservedCount++;
        out.add(trip);
      }
    }

    return RedactedTripBatch(
      trips: List.unmodifiable(out),
      summary: RedactionSummary(
        redactedTripCount: redactedCount,
        preservedTripCount: preservedCount,
        totalPersonalKmPreserved:
            double.parse(personalKm.toStringAsFixed(2)),
      ),
    );
  }
}
