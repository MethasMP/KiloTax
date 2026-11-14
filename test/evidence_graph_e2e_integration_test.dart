import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/data/models/job_site.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/accountant_workpaper_generator.dart';
import 'package:kilotax/services/engine/evidence_review_service.dart';
import 'package:kilotax/services/evidence/evidence_auto_match_engine.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/services/tracking/job_site_geofence_engine.dart';
import 'package:kilotax/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Evidence Graph End-to-End Integration Suite', () {
    late AppState appState;
    late Directory tempDir;

    final primaryVehicle = Vehicle(
      id: 'veh_hilux_tradie_01',
      make: 'Toyota',
      model: 'Hilux SR5',
      regoPlate: 'TRD-778',
      vehicleType: VehicleType.ute,
      taxMethod: TaxMethod.logbook,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      appState = AppState(storageService: storage);
      await appState.init();
      await appState.addVehicle(primaryVehicle);
      tempDir = await Directory.systemTemp.createTemp('kilotax_e2e_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Full Unbroken Evidence Graph Chain: POI -> Trip -> OCR Expense -> Linking -> Cascade -> Workpaper', () async {
      // -----------------------------------------------------------------------
      // Step 2a: Create a JobSite POI (e.g. "Barangaroo South Fitout", radius 150m)
      // -----------------------------------------------------------------------
      final jobSite = JobSite(
        id: 'poi_barangaroo_01',
        name: 'Barangaroo South Fitout',
        clientName: 'Lendlease Commercial',
        projectCode: 'LL-BSF-2026',
        address: '100 Barangaroo Avenue, Sydney NSW 2000',
        latitude: -33.8640,
        longitude: 151.2010,
        radiusMeters: 150.0,
      );

      await appState.addJobSite(jobSite);
      expect(appState.jobSites, contains(predicate<JobSite>((s) => s.id == 'poi_barangaroo_01')));

      // -----------------------------------------------------------------------
      // Step 2b: Record a business Trip with endpoint arriving inside JobSite geofence
      // -> verify auto-enrichment of purpose/jobReference via JobSiteGeofenceEngine
      // -----------------------------------------------------------------------
      final tripDateTime = DateTime(2026, 11, 8, 9, 30);
      final rawTrip = Trip(
        id: 'trip_fitout_001',
        vehicleId: primaryVehicle.id,
        date: tripDateTime,
        startOdometer: 45200.0,
        endOdometer: 45242.5,
        distanceKm: 42.5,
        classification: TripClassification.business,
        taxMethod: TaxMethod.logbook,
        purpose: '', // Empty initial purpose to test auto-enrichment
      );

      // Destination coordinate is ~35m from Barangaroo center (-33.8642, 151.2011)
      final enrichedTrip = JobSiteGeofenceEngine.enrichTripWithJobSite(
        trip: rawTrip,
        jobSites: appState.jobSites,
        startLatitude: -33.8850,
        startLongitude: 151.2090,
        endLatitude: -33.8642,
        endLongitude: 151.2011,
      );

      expect(enrichedTrip.jobReference, contains('Barangaroo South Fitout (Lendlease Commercial)'));
      expect(enrichedTrip.jobReference, contains('[Ref: LL-BSF-2026]'));
      expect(enrichedTrip.purpose, equals('Client Visit: Lendlease Commercial at Barangaroo South Fitout'));
      expect(enrichedTrip.destinationAddress, equals('100 Barangaroo Avenue, Sydney NSW 2000'));

      appState.recordTrip(enrichedTrip);
      expect(appState.trips.any((t) => t.id == 'trip_fitout_001'), isTrue);

      // -----------------------------------------------------------------------
      // Step 2c: Ingest a VehicleExpense (Bunnings/Fuel) with OCR date & merchant
      // -> evaluate via EvidenceAutoMatchEngine -> verify bidirectional linking
      // -----------------------------------------------------------------------
      final receiptBytes = utf8.encode('BUNNINGS WAREHOUSE ALEXANDRIA - TAX INVOICE - ABN 26 008 672 179 - TOTAL \$184.50 AUD');
      final receiptHash = sha256.convert(receiptBytes).toString();
      final receiptFile = File('${tempDir.path}/bunnings_receipt_001.jpg');
      await receiptFile.writeAsBytes(receiptBytes);

      final expenseDateTime = tripDateTime.add(const Duration(minutes: 20)); // 9:50 AM
      final expenseWithOcr = VehicleExpense(
        id: 'exp_bunnings_trade_01',
        vehicleId: primaryVehicle.id,
        amount: 184.50,
        gstAmount: 16.77,
        category: ExpenseCategory.toolsMaterials,
        date: expenseDateTime,
        receiptPath: receiptFile.path,
        notes: 'Bunnings Building Supplies - Alexandria',
        receiptAudit: ReceiptAuditTrail(
          reviewStatus: ReceiptReviewStatus.confirmed,
          capturedAt: expenseDateTime,
          imageSha256: receiptHash,
          ocrMerchant: 'BUNNINGS WAREHOUSE',
          ocrAmount: 184.50,
          ocrAbn: '26 008 672 179',
          ocrConfidence: 0.98,
        ),
      );

      // Evaluate match with candidate trips. Alexandria Bunnings terminal GPS (-33.9100, 151.1900)
      final matchResult = EvidenceAutoMatchEngine.findBestMatchingTrip(
        expense: expenseWithOcr,
        candidateTrips: appState.trips,
        receiptLatitude: -33.8645,
        receiptLongitude: 151.2015,
        tripLatitude: -33.8642,
        tripLongitude: 151.2011,
      );

      expect(matchResult, isNotNull);
      expect(matchResult!.trip.id, equals('trip_fitout_001'));
      expect(matchResult.confidenceScore, greaterThanOrEqualTo(0.85));

      // Bidirectional linking helper
      final linkedPair = EvidenceAutoMatchEngine.linkBidirectionally(
        expense: expenseWithOcr,
        trip: matchResult.trip,
      );
      expect(linkedPair.updatedExpense.linkedTripId, equals('trip_fitout_001'));
      expect(linkedPair.updatedTrip.linkedExpenseIds, contains('exp_bunnings_trade_01'));

      // Commit to AppState
      appState.recordExpense(linkedPair.updatedExpense);

      // Verify bidirectional persistence in AppState
      final storedExpense = appState.expenses.firstWhere((e) => e.id == 'exp_bunnings_trade_01');
      final storedTrip = appState.trips.firstWhere((t) => t.id == 'trip_fitout_001');

      expect(storedExpense.linkedTripId, equals('trip_fitout_001'));
      expect(storedTrip.linkedExpenseIds, contains('exp_bunnings_trade_01'));

      // -----------------------------------------------------------------------
      // Step 2d: Verify Cascade Integrity: simulate unlinking/deleting the expense,
      // ensuring no dangling references remain in AppState.
      // -----------------------------------------------------------------------
      appState.unlinkExpenseFromTrip(expenseId: 'exp_bunnings_trade_01');

      final unlinkedExpense = appState.expenses.firstWhere((e) => e.id == 'exp_bunnings_trade_01');
      final unlinkedTrip = appState.trips.firstWhere((t) => t.id == 'trip_fitout_001');

      expect(unlinkedExpense.linkedTripId, isNull);
      expect(unlinkedTrip.linkedExpenseIds, isNot(contains('exp_bunnings_trade_01')));

      // Re-link bidirectionally to proceed with workpaper verification
      appState.linkExpenseToTrip(expenseId: 'exp_bunnings_trade_01', tripId: 'trip_fitout_001');

      final relinkedExpense = appState.expenses.firstWhere((e) => e.id == 'exp_bunnings_trade_01');
      final relinkedTrip = appState.trips.firstWhere((t) => t.id == 'trip_fitout_001');
      expect(relinkedExpense.linkedTripId, equals('trip_fitout_001'));
      expect(relinkedTrip.linkedExpenseIds, contains('exp_bunnings_trade_01'));

      // -----------------------------------------------------------------------
      // Step 2e: Verify Accountant Workpaper Generation reflects the linked trip date,
      // odometer range, and receipt SHA-256 truth.
      // -----------------------------------------------------------------------
      final reviewer = EvidenceReviewService();
      final inspections = await reviewer.inspectReceipts([relinkedExpense]);

      expect(inspections.containsKey('exp_bunnings_trade_01'), isTrue);
      expect(inspections['exp_bunnings_trade_01']!.status, equals(ReceiptFileStatus.available));
      expect(inspections['exp_bunnings_trade_01']!.sha256, equals(receiptHash));

      final workpaperGenerator = AccountantWorkpaperGenerator();
      final workpaperMarkdown = workpaperGenerator.generateWorkpaper(
        clientName: 'Dave Tradie',
        abn: '51 824 753 556',
        vehicleModel: 'Toyota Hilux SR5 (TRD-778)',
        trips: [relinkedTrip],
        expenses: [relinkedExpense],
        financialYear: '2026-2027',
        receiptInspections: inspections,
        receiptArchivePaths: {'exp_bunnings_trade_01': 'receipts/bunnings_receipt_001.jpg'},
      );

      // Assertions verifying Workpaper integrity:
      // 1. Linked Trip Date (2026-11-08)
      expect(workpaperMarkdown, contains('2026-11-08'));
      // 2. Trip Odometer Range (45200 - 45243 KM / 45242.5 rounded)
      expect(workpaperMarkdown, contains('45200 - 45243 KM'));
      // 3. Linked Trip ID & Expense ID presence in table (escaped for markdown: trip\_fitout\_001)
      expect(workpaperMarkdown, contains(r'trip\_fitout\_001'));
      expect(workpaperMarkdown, contains(r'exp\_bunnings\_trade\_01'));
      // 4. Human confirmed count reflecting valid receipt file inspection status
      expect(workpaperMarkdown, contains('Human-confirmed with available files: 1 of 1'));
      expect(workpaperMarkdown, contains('Accessible on disk: 1 of 1'));
      // 5. Crytographic SHA-256 inspection verification
      expect(inspections['exp_bunnings_trade_01']!.sha256, equals(receiptHash));
      expect(receiptHash.length, equals(64));
    });
  });
}
