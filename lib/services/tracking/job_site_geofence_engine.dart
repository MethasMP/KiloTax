import '../../data/models/job_site.dart';
import '../../data/models/trip.dart';
import 'wgs84_geodesic_engine.dart';

/// Geofence match result conforming to Evidence Graph INV-B03 contract.
class GeofenceMatch {
  final String jobSiteId;
  final double confidenceScore;
  final String associationMethod;
  final JobSite? jobSite;

  const GeofenceMatch({
    required this.jobSiteId,
    required this.confidenceScore,
    this.associationMethod = 'spatial_geofence',
    this.jobSite,
  });
}

/// Match result indicating whether a trip origin or destination matched a JobSite geofence.
class JobSiteMatchResult {
  final JobSite jobSite;
  final bool matchedOrigin;
  final bool matchedDestination;
  final double distanceMeters;

  const JobSiteMatchResult({
    required this.jobSite,
    required this.matchedOrigin,
    required this.matchedDestination,
    required this.distanceMeters,
  });
}

/// JobSite Geofencing & POI Engine (Evidence Graph Layer 1).
///
/// Evaluates trip start/end coordinates against known JobSites within geofence radius
/// (default 150m). Automatically associates the trip with the job site name and client
/// without requiring manual typing from the user.
class JobSiteGeofenceEngine {
  /// Evaluates whether a trip stopping at a location for dwell ≥ 120s matches a JobSite geofence (INV-B03).
  GeofenceMatch? matchTripToJobSite(Trip trip, List<JobSite> sites) {
    final dwell = trip.stoppedDuration;
    if (dwell == null || dwell < 120) return null;

    final targetLat = trip.endLat ?? trip.endLatitude;
    final targetLng = trip.endLng ?? trip.endLongitude;
    if (targetLat == null || targetLng == null) return null;

    final activeSites = sites.where((s) => s.isActive && s.trackingEnabled).toList();
    if (activeSites.isEmpty) return null;

    JobSite? bestSite;
    double shortestDistance = double.infinity;

    for (final site in activeSites) {
      final dist = Wgs84GeodesicEngine.calculateDistanceMeters(
        lat1: targetLat,
        lon1: targetLng,
        lat2: site.lat,
        lon2: site.lng,
      );
      if (dist <= site.radiusMeters && dist < shortestDistance) {
        shortestDistance = dist;
        bestSite = site;
      }
    }

    if (bestSite == null) return null;

    final confidence = (1.0 - (shortestDistance / bestSite.radiusMeters) * 0.5).clamp(0.1, 1.0);

    return GeofenceMatch(
      jobSiteId: bestSite.id,
      confidenceScore: confidence,
      associationMethod: 'spatial_geofence',
      jobSite: bestSite,
    );
  }

  /// Evaluates whether a coordinate (start or end of a trip) falls within any active JobSite geofence.
  /// If multiple sites match, returns the closest one.
  static JobSiteMatchResult? matchTripEndpoints({
    required List<JobSite> jobSites,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
  }) {
    final activeSites = jobSites.where((s) => s.isActive).toList();
    if (activeSites.isEmpty) return null;

    JobSite? bestMatch;
    bool matchedOrigin = false;
    bool matchedDest = false;
    double shortestDistance = double.infinity;

    // Check Destination first (tradie arriving at job site is most common case for purpose/jobRef tagging)
    if (endLatitude != null && endLongitude != null) {
      for (final site in activeSites) {
        if (site.containsCoordinate(lat: endLatitude, lng: endLongitude)) {
          final dist = site.distanceTo(lat: endLatitude, lng: endLongitude);
          if (dist < shortestDistance) {
            shortestDistance = dist;
            bestMatch = site;
            matchedOrigin = false;
            matchedDest = true;
          }
        }
      }
    }

    // Check Origin if no destination match or if origin is also/alternatively at a job site
    if (startLatitude != null && startLongitude != null) {
      for (final site in activeSites) {
        if (site.containsCoordinate(lat: startLatitude, lng: startLongitude)) {
          final dist = site.distanceTo(lat: startLatitude, lng: startLongitude);
          // If destination didn't match, or this origin is even closer to a site
          if (bestMatch == null || (matchedDest && dist < shortestDistance)) {
            shortestDistance = dist;
            bestMatch = site;
            matchedOrigin = true;
            matchedDest = false;
          }
        }
      }
    }

    if (bestMatch == null) return null;

    return JobSiteMatchResult(
      jobSite: bestMatch,
      matchedOrigin: matchedOrigin,
      matchedDestination: matchedDest,
      distanceMeters: shortestDistance,
    );
  }

  /// Automatically enriches a [Trip] with JobSite metadata if either start or end coordinate
  /// falls within a known [JobSite] geofence.
  ///
  /// Sets:
  /// - `jobReference`: "[Site Name] - [Client Name]" (or existing if already populated)
  /// - `purpose`: Auto-synthesized or enriched with the client name & site name if purpose is empty or generic
  /// - `destinationAddress` / `originAddress`: Set to site address/name if empty or generic
  static Trip enrichTripWithJobSite({
    required Trip trip,
    required List<JobSite> jobSites,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
  }) {
    final match = matchTripEndpoints(
      jobSites: jobSites,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );

    if (match == null) return trip;

    final site = match.jobSite;
    final siteLabel = '${site.name} (${site.clientName})';

    // Auto-associate jobReference: e.g. "Barangaroo Tower - Lendlease Commercial"
    final newJobReference =
        (trip.jobReference != null && trip.jobReference!.trim().isNotEmpty)
            ? trip.jobReference
            : (site.projectCode != null && site.projectCode!.isNotEmpty)
                ? '$siteLabel [Ref: ${site.projectCode}]'
                : siteLabel;

    // Auto-associate purpose if empty or generic
    String newPurpose = trip.purpose;
    if (newPurpose.trim().isEmpty ||
        newPurpose == 'Work Travel' ||
        newPurpose == 'Business Trip') {
      newPurpose = 'Client Visit: ${site.clientName} at ${site.name}';
    }

    // Auto-fill origin/destination address if matched and currently empty/generic
    String? newOrigin = trip.originAddress;
    String? newDestination = trip.destinationAddress;

    if (match.matchedDestination &&
        (newDestination == null ||
            newDestination.trim().isEmpty ||
            newDestination == 'Trip Destination' ||
            newDestination == 'Interrupted Site')) {
      newDestination = site.address.isNotEmpty ? site.address : site.name;
    } else if (match.matchedOrigin &&
        (newOrigin == null ||
            newOrigin.trim().isEmpty ||
            newOrigin == 'Trip Origin' ||
            newOrigin == 'Start Site')) {
      newOrigin = site.address.isNotEmpty ? site.address : site.name;
    }

    return trip.copyWith(
      jobReference: newJobReference,
      jobId: trip.jobId ?? site.id,
      review: trip.review.isEmpty
          ? {'jobSuggested': true, 'suggestionSource': 'geofence'}
          : trip.review,
      purpose: newPurpose,
      originAddress: newOrigin,
      destinationAddress: newDestination,
    );
  }
}
