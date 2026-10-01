import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/auth/supabase_auth_service.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category 2: Store Compliance & Security Suite', () {
    late LocalStorageService storageService;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = LocalStorageService(prefs);

      appState = AppState(
        storageService: storageService,
      );
      await appState.init();
    });

    test('1. iOS Info.plist does not declare external-accessory but retains location, processing, bluetooth-central', () {
      final infoPlistFile = File('ios/Runner/Info.plist');
      expect(infoPlistFile.existsSync(), isTrue);

      final content = infoPlistFile.readAsStringSync();
      expect(content.contains('<string>external-accessory</string>'), isFalse,
          reason: 'Apple Guideline 2.5.4: external-accessory must not be declared without MFi');
      expect(content.contains('<string>location</string>'), isTrue);
      expect(content.contains('<string>processing</string>'), isTrue);
      expect(content.contains('<string>bluetooth-central</string>'), isTrue);
    });

    test('2. In-App Account Deletion (Apple Guideline 5.1.1(v)) clears storage, memory state, and resets onboarding', () async {
      // Setup state with mock vehicle, trip, expense, and onboarding
      await appState.completeOnboarding();
      expect(appState.hasSeenOnboarding, isTrue);

      final vehicle = Vehicle(
        id: 'del_veh_1',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'DEL-001',
        initialOdometer: 10000.0,
      );
      appState.addVehicle(vehicle);
      expect(appState.vehicles.isNotEmpty, isTrue);
      expect(appState.hasVehicle, isTrue);

      appState.recordTrip(Trip(
        id: 'del_trip_1',
        vehicleId: vehicle.id,
        distanceKm: 20.0,
        date: DateTime.now(),
        purpose: 'Site visit',
      ));
      expect(appState.trips.isNotEmpty, isTrue);

      appState.recordExpense(VehicleExpense(
        id: 'del_exp_1',
        vehicleId: vehicle.id,
        amount: 50.0,
        category: ExpenseCategory.fuel,
        date: DateTime.now(),
      ));
      expect(appState.expenses.isNotEmpty, isTrue);

      // Perform Account Deletion
      await appState.deleteAccount();

      // State zeroization verification
      expect(appState.isAuthenticated, isFalse);
      expect(appState.currentUser, isNull);
      expect(appState.vehicles.isEmpty, isTrue);
      expect(appState.primaryVehicle, isNull);
      expect(appState.trips.isEmpty, isTrue);
      expect(appState.expenses.isEmpty, isTrue);
      expect(appState.hasVehicle, isFalse);
      expect(appState.hasSeenOnboarding, isFalse,
          reason: 'Account deletion must wipe onboarding seen flag so app resets to clean welcome state');
    });

    test('2b. Guest Mode Data Reset clears all local storage, memory state, and resets onboarding', () async {
      await appState.completeOnboarding();
      expect(appState.hasSeenOnboarding, isTrue);

      final vehicle = Vehicle(
        id: 'guest_veh_1',
        make: 'Mazda',
        model: 'BT-50',
        regoPlate: 'GST-999',
        initialOdometer: 5000.0,
      );
      appState.addVehicle(vehicle);
      expect(appState.hasVehicle, isTrue);

      appState.recordTrip(Trip(
        id: 'guest_trip_1',
        vehicleId: vehicle.id,
        distanceKm: 15.0,
        date: DateTime.now(),
        purpose: 'Site Delivery',
      ));
      expect(appState.trips.isNotEmpty, isTrue);

      // Perform Guest Reset Local Data
      await appState.resetLocalData();

      // State zeroization verification
      expect(appState.isAuthenticated, isFalse);
      expect(appState.currentUser, isNull);
      expect(appState.vehicles.isEmpty, isTrue);
      expect(appState.primaryVehicle, isNull);
      expect(appState.trips.isEmpty, isTrue);
      expect(appState.expenses.isEmpty, isTrue);
      expect(appState.hasVehicle, isFalse);
      expect(appState.hasSeenOnboarding, isFalse,
          reason: 'Local data reset must wipe onboarding seen flag so app resets to clean welcome state');
    });

    test('3. Android Release Signing is configured with key.properties support and example template exists', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content.contains('keystorePropertiesFile'), isTrue);
      expect(content.contains('signingConfigs.getByName("release")'), isTrue);
      expect(content.contains('signingConfig = signingConfigs.getByName("debug")\n        }'), isFalse,
          reason: 'Hardcoded debug signing for release build must be replaced with dynamic configuration');

      final exampleFile = File('android/key.properties.example');
      expect(exampleFile.existsSync(), isTrue);
      final exampleContent = exampleFile.readAsStringSync();
      expect(exampleContent.contains('keyAlias='), isTrue);
      expect(exampleContent.contains('storeFile='), isTrue);
    });

    test('4. Platform-Gate Apple Sign-In on non-Apple platforms', () async {
      final authService = SupabaseAuthService();
      // On non-iOS test runner (macOS unit test simulates TargetPlatform based on defaultTargetPlatform or guard)
      // When defaultTargetPlatform is Android/Windows/Linux:
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        final res = await authService.signInWithApple();
        expect(res.success, isFalse);
        expect(res.errorMessage, contains('Apple Sign In is only supported'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('5. Sync Gating: triggerSyncToCloud and restoreFromCloud abort when unauthenticated', () async {
      // Ensure appState has unauthenticated state
      expect(appState.isAuthenticated, isFalse);
      expect(appState.currentUser, isNull);

      final vehicle = Vehicle(
        id: 'sync_gate_veh',
        make: 'Isuzu',
        model: 'D-Max',
        regoPlate: 'GATE-01',
        initialOdometer: 15000.0,
      );
      appState.addVehicle(vehicle);

      // Trigger sync while unauthenticated
      final syncResult = await appState.triggerSyncToCloud();
      expect(syncResult.success, isFalse);
      expect(syncResult.errorMessage, contains('User is not authenticated'));
      expect(appState.syncStatus, equals(SyncStatus.idle));

      // Restore from cloud while unauthenticated
      final restoreResult = await appState.restoreFromCloud();
      expect(restoreResult.success, isFalse);
      expect(restoreResult.errorMessage, contains('User is not authenticated'));
      expect(appState.syncStatus, equals(SyncStatus.idle));
    });

    test('6. Apple Privacy Manifest PrivacyInfo.xcprivacy and Legal URLs exist', () {
      final privacyManifestFile = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(privacyManifestFile.existsSync(), isTrue);

      final content = privacyManifestFile.readAsStringSync();
      expect(content.contains('NSPrivacyAccessedAPICategoryUserDefaults'), isTrue);
      expect(content.contains('CA92.1'), isTrue);
      expect(content.contains('NSPrivacyAccessedAPICategoryFileTimestamp'), isTrue);
      expect(content.contains('NSPrivacyAccessedAPICategorySystemBootTime'), isTrue);
      expect(content.contains('NSPrivacyAccessedAPICategoryDiskSpace'), isTrue);

      expect(AppConstants.privacyPolicyUrl, equals('https://methasmp.github.io/KiloTax/legal/#privacy'));
      expect(AppConstants.termsOfServiceUrl, equals('https://methasmp.github.io/KiloTax/legal/#terms'));
    });
  });
}
