import '../../data/models/job_site.dart';
import '../../data/models/trip.dart';
import '../../data/models/user_profile.dart';
import 'wgs84_geodesic_engine.dart';

class SuggestedJobSite {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int visitCount;

  const SuggestedJobSite({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
  });
}

class JobSiteAutoLearner {
  static const double _homeExclusionMeters = 200.0;

  static List<SuggestedJobSite> suggest({
    required List<Trip> trips,
    required List<JobSite> existingSites,
    UserProfile? userProfile,
    int minVisits = 2,
    double clusterRadiusMeters = 150.0,
  }) {
    final clusters = <_Cluster>[];

    for (final trip in trips) {
      if (trip.isDeleted || !trip.isBusiness) continue;
      final lat = trip.endLat;
      final lng = trip.endLng;
      if (lat == null || lng == null) continue;

      if (_isNearHome(lat, lng, userProfile)) continue;
      if (_isInsideExistingSite(lat, lng, existingSites)) continue;

      _Cluster? match;
      for (final cluster in clusters) {
        final dist = Wgs84GeodesicEngine.calculateDistanceMeters(
          lat1: cluster.lat,
          lon1: cluster.lng,
          lat2: lat,
          lon2: lng,
        );
        if (dist <= clusterRadiusMeters) {
          match = cluster;
          break;
        }
      }

      if (match != null) {
        match.count++;
        if (match.address.isEmpty && (trip.destinationAddress ?? '').trim().isNotEmpty) {
          match.address = trip.destinationAddress!.trim();
        }
      } else {
        clusters.add(
          _Cluster(
            lat: lat,
            lng: lng,
            address: (trip.destinationAddress ?? '').trim(),
          ),
        );
      }
    }

    final suggestions = clusters
        .where((c) => c.count >= minVisits)
        .map(
          (c) => SuggestedJobSite(
            name: _deriveSiteName(c.address),
            address: c.address,
            latitude: c.lat,
            longitude: c.lng,
            visitCount: c.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.visitCount.compareTo(a.visitCount));

    return suggestions;
  }

  static bool _isNearHome(double lat, double lng, UserProfile? profile) {
    if (profile == null || !profile.hasHomeCoordinates) return false;
    final dist = Wgs84GeodesicEngine.calculateDistanceMeters(
      lat1: lat,
      lon1: lng,
      lat2: profile.homeLatitude!,
      lon2: profile.homeLongitude!,
    );
    return dist <= _homeExclusionMeters;
  }

  static bool _isInsideExistingSite(
    double lat,
    double lng,
    List<JobSite> sites,
  ) {
    return sites.any(
      (s) => s.isActive && s.containsCoordinate(lat: lat, lng: lng),
    );
  }

  static String _deriveSiteName(String address) {
    if (address.isEmpty) return 'Frequent Work Site';
    final firstSegment = address.split(',').first.trim();
    return firstSegment.isNotEmpty ? firstSegment : 'Frequent Work Site';
  }
}

class _Cluster {
  final double lat;
  final double lng;
  String address;
  int count = 1;

  _Cluster({
    required this.lat,
    required this.lng,
    required this.address,
  });
}
