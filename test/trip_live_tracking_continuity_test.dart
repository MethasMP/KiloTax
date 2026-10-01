import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilotax/services/tracking/location_permission_service.dart';

void main() {
  group('TripLiveTracking Continuity & Platform Settings Architecture', () {
    test(
        'AndroidSettings preserves Foreground Service notification & wake lock',
        () {
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'KiloTax Live Tracking Active',
          notificationText:
              'Accurately recording your business trip for ATO tax compliance...',
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      expect(
          androidSettings.accuracy, equals(LocationAccuracy.bestForNavigation));
      expect(androidSettings.distanceFilter, equals(3));
      expect(
          androidSettings.intervalDuration, equals(const Duration(seconds: 1)));
      expect(androidSettings.foregroundNotificationConfig, isNotNull);
      expect(
          androidSettings.foregroundNotificationConfig!.enableWakeLock, isTrue);
      expect(androidSettings.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(androidSettings.foregroundNotificationConfig!.notificationTitle,
          contains('KiloTax'));
    });

    test('AppleSettings enables background updates without automatic pausing',
        () {
      final appleSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );

      expect(
          appleSettings.accuracy, equals(LocationAccuracy.bestForNavigation));
      expect(appleSettings.distanceFilter, equals(3));
      expect(appleSettings.activityType,
          equals(ActivityType.automotiveNavigation));
      expect(appleSettings.pauseLocationUpdatesAutomatically, isFalse);
      expect(appleSettings.showBackgroundLocationIndicator, isTrue);
      expect(appleSettings.allowBackgroundLocationUpdates, isTrue);
    });

    test('LocationPermissionService has sufficient permissions check',
        () async {
      final service = LocationPermissionService();
      expect(service, isNotNull);
      // Verify mapGeolocatorPermission pure contract
      expect(
        LocationPermissionService.mapGeolocatorPermission(
            LocationPermission.always),
        equals(AppLocationPermissionStatus.grantedBackground),
      );
      expect(
        LocationPermissionService.mapGeolocatorPermission(
            LocationPermission.whileInUse),
        equals(AppLocationPermissionStatus.grantedForeground),
      );
      expect(
        LocationPermissionService.mapGeolocatorPermission(
            LocationPermission.denied),
        equals(AppLocationPermissionStatus.denied),
      );
      expect(
        LocationPermissionService.mapGeolocatorPermission(
            LocationPermission.deniedForever),
        equals(AppLocationPermissionStatus.deniedForever),
      );
    });
  });
}
