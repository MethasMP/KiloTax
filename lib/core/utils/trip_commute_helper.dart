import 'package:geolocator/geolocator.dart';

import '../../data/models/user_profile.dart';

/// Returns true when [lat]/[lng] falls within [profile]'s configured home
/// geofence, or when [address] explicitly references home/residence.
bool isHomeCommute(
  UserProfile? profile,
  double? lat,
  double? lng, {
  String? address,
}) {
  final addrLower = (address ?? '').trim().toLowerCase();
  if (addrLower.contains('home') || addrLower.contains('residence')) {
    return true;
  }
  if (profile != null &&
      profile.hasHomeCoordinates &&
      lat != null &&
      lng != null) {
    final dist = Geolocator.distanceBetween(
      lat,
      lng,
      profile.homeLatitude!,
      profile.homeLongitude!,
    );
    if (dist <= profile.homeRadiusMeters) {
      return true;
    }
  }
  return false;
}
