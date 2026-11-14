import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/services/tracking/location_permission_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/trips/trip_live_tracking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('TripLiveTracking Lifecycle Decoupling Tests', () {
    test('AppState.startLiveDrive is idempotent when drive is already active',
        () {
      final appState = AppState();
      final pos1 = Position(
        latitude: -33.8688,
        longitude: 151.2093,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 15.0,
        speedAccuracy: 1.0,
      );

      appState.startLiveDrive(
        startPosition: pos1,
        originAddress: 'Initial Site',
      );
      final initialStartTime = appState.activeDriveStartedAt;
      expect(appState.isDriving, isTrue);

      appState.updateLiveDriveDistance(12.5);
      expect(appState.activeDriveDistanceKm, 12.5);

      // Attempt second call to startLiveDrive while driving
      final pos2 = Position(
        latitude: -33.9000,
        longitude: 151.2500,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 15.0,
        speedAccuracy: 1.0,
      );
      appState.startLiveDrive(
        startPosition: pos2,
        originAddress: 'Second Site',
      );

      // Distance and start time must be preserved
      expect(appState.isDriving, isTrue);
      expect(appState.activeDriveDistanceKm, 12.5);
      expect(appState.activeDriveStartedAt, initialStartTime);
      expect(appState.activeDriveOriginAddress, 'Initial Site');
    });

    testWidgets(
        'TripLiveTrackingScreen widget dispose does NOT destroy in-flight drive in AppState',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final appState = AppState(storageService: storage);

      appState.startLiveDrive(originAddress: 'Site A');
      appState.updateLiveDriveDistance(8.4);
      expect(appState.isDriving, isTrue);
      expect(appState.activeDriveDistanceKm, 8.4);

      // Mount TripLiveTrackingScreen
      await tester.pumpWidget(MaterialApp(
        home: TripLiveTrackingScreen(appState: appState),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TripLiveTrackingScreen), findsOneWidget);

      // Replace with another widget (causing TripLiveTrackingScreen to dispose)
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Dashboard Screen')),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TripLiveTrackingScreen), findsNothing);

      // Verify that after dispose and microtasks, appState drive is NOT ended
      expect(appState.isDriving, isTrue);
      expect(appState.activeDriveDistanceKm, 8.4);
    });
  });
}
