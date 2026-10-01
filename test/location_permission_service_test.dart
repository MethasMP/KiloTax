import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilotax/services/tracking/location_permission_service.dart';
import 'package:kilotax/ui/widgets/location_escalation_dialog.dart';

void main() {
  group('LocationPermissionService Architecture & Correctness Tests', () {
    test('Service instance is a proper singleton', () {
      final instance1 = LocationPermissionService();
      final instance2 = LocationPermissionService();
      expect(identical(instance1, instance2), isTrue);
    });

    test(
        'AppLocationPermissionStatus enums contain all 5 essential lifecycle states',
        () {
      expect(AppLocationPermissionStatus.values,
          contains(AppLocationPermissionStatus.grantedForeground));
      expect(AppLocationPermissionStatus.values,
          contains(AppLocationPermissionStatus.grantedBackground));
      expect(AppLocationPermissionStatus.values,
          contains(AppLocationPermissionStatus.denied));
      expect(AppLocationPermissionStatus.values,
          contains(AppLocationPermissionStatus.deniedForever));
      expect(AppLocationPermissionStatus.values,
          contains(AppLocationPermissionStatus.serviceDisabled));
    });

    test(
        'Permission Mapping: Correctly maps Geolocator permissions to domain enum',
        () {
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
      expect(
        LocationPermissionService.mapGeolocatorPermission(
            LocationPermission.unableToDetermine),
        equals(AppLocationPermissionStatus.denied),
      );
    });
  });

  group('LocationEscalationDialog UI & Widget Tests', () {
    testWidgets(
        'Renders all value propositions, compliance copy, and action buttons',
        (tester) async {
      bool grantedTriggered = false;
      bool manualTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationEscalationDialog(
              onGranted: () => grantedTriggered = true,
              onDismissManualMode: () => manualTriggered = true,
            ),
          ),
        ),
      );

      // Verify Header and Educational Context
      expect(find.text('Enable Background Auto-Tracking'), findsOneWidget);
      expect(
        find.textContaining(
            '12-week ATO logbook whenever you connect to your vehicle'),
        findsOneWidget,
      );

      // Verify Key Value Pillars
      expect(find.text('Zero ATO Audit Gaps'), findsOneWidget);
      expect(find.text('Battery-Optimised Geofencing'), findsOneWidget);

      // Verify CTAs
      expect(find.text('Set Location to "Always Allow"'), findsOneWidget);
      expect(find.text('Keep Manual 1-Tap Tracking'), findsOneWidget);

      // Tap Manual CTA
      await tester.tap(find.text('Keep Manual 1-Tap Tracking'));
      await tester.pumpAndSettle();

      expect(manualTriggered, isTrue);
      expect(grantedTriggered, isFalse);
    });
  });
}
