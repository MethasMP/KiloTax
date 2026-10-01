import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Normalized domain permission status for KiloTax location lifecycle
enum AppLocationPermissionStatus {
  grantedForeground, // While Using the App (Foreground tracking)
  grantedBackground, // Always Allow (Autonomous Background tracking)
  denied, // User denied or dismissed prompt (Can prompt again)
  deniedForever, // Denied permanently (Must redirect to OS Settings)
  serviceDisabled, // System Location Services (GPS switch) turned off
}

/// Production-Grade Location Permission & Hardware Lifecycle Service
///
/// Implements Apple HIG & Google Play Store compliant 2-phase escalation:
/// Phase 1: Request Foreground ('While In Use') during onboarding or manual drive.
/// Phase 2: Request Background ('Always Allow') when pairing Bluetooth or toggling Auto-Tracking.
class LocationPermissionService {
  static final LocationPermissionService _instance =
      LocationPermissionService._internal();
  factory LocationPermissionService() => _instance;
  LocationPermissionService._internal();

  /// Check overall current location permission and hardware status
  Future<AppLocationPermissionStatus> checkStatus() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AppLocationPermissionStatus.serviceDisabled;
    }

    final LocationPermission permission = await Geolocator.checkPermission();
    return _mapGeolocatorPermission(permission);
  }

  /// Request Phase 1 (Foreground / While Using) permission
  Future<AppLocationPermissionStatus> requestForegroundPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AppLocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _mapGeolocatorPermission(permission);
  }

  /// Request Phase 2 (Background / Always) permission escalation
  ///
  /// On iOS/Android 11+, requesting permission after having 'whileInUse'
  /// prompts the system dialog for 'Always' / 'Allow all the time'.
  Future<AppLocationPermissionStatus> requestBackgroundEscalation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AppLocationPermissionStatus.serviceDisabled;
    }

    // Attempt second-stage permission request
    final LocationPermission permission = await Geolocator.requestPermission();
    return _mapGeolocatorPermission(permission);
  }

  /// Check if the app currently has sufficient permissions to run tracking
  Future<bool> hasSufficientTrackingPermission(
      {bool requireBackground = false}) async {
    final status = await checkStatus();
    if (requireBackground) {
      return status == AppLocationPermissionStatus.grantedBackground;
    }
    return status == AppLocationPermissionStatus.grantedForeground ||
        status == AppLocationPermissionStatus.grantedBackground;
  }

  /// Deep link to system application settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[LocationPermissionService] Error opening app settings: $e');
      return false;
    }
  }

  /// Deep link to device location/GPS toggle settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint(
          '[LocationPermissionService] Error opening location settings: $e');
      return false;
    }
  }

  /// Map Geolocator plugin permission to normalized domain enum (pure mapping function)
  static AppLocationPermissionStatus mapGeolocatorPermission(
      LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return AppLocationPermissionStatus.grantedBackground;
      case LocationPermission.whileInUse:
        return AppLocationPermissionStatus.grantedForeground;
      case LocationPermission.denied:
        return AppLocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return AppLocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return AppLocationPermissionStatus.denied;
    }
  }

  AppLocationPermissionStatus _mapGeolocatorPermission(
          LocationPermission permission) =>
      mapGeolocatorPermission(permission);
}
