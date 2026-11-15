import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'support/tax_pack_reader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/job_site.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/services/engine/tax_pack_builder.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/ui/screens/workflow/workflow_screen.dart';
import 'package:kilotax/ui/screens/workflow/workflow_trip_editor.dart';

class RejectingWorkflowStorage extends LocalStorageService {
  RejectingWorkflowStorage(super.prefs);
  bool reject = false;
  @override
  Future<bool> saveTrips(List<Trip> trips) =>
      reject ? Future.value(false) : super.saveTrips(trips);
  @override
  Future<bool> saveExpenses(List<VehicleExpense> expenses) =>
      reject ? Future.value(false) : super.saveExpenses(expenses);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  late LocalStorageService storage;
  final date = DateTime(2026, 8, 1, 10);
  final vehicle = Vehicle(
      id: 'v',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'JOB123',
      initialOdometer: 100,
      taxMethod: TaxMethod.logbook);
  Trip trip(String id, {String vehicleId = 'v'}) => Trip(
      id: id,
      vehicleId: vehicleId,
      date: date,
      distanceKm: 20,
      startOdometer: 100,
      endOdometer: 120,
      purpose: '?',
      classification: TripClassification.unclassified,
      originAddress: 'PRIVATE_ROUTE_SENTINEL',
      destinationAddress: 'Site',
      taxMethod: TaxMethod.logbook);
  JobSite job() => JobSite(
      id: 'job',
      name: 'Smith renovation',
      clientName: 'Smith',
      latitude: 0,
      longitude: 0,
      trackingEnabled: false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    state = AppState(storageService: storage)
      ..addVehicle(vehicle)
      ..recordTrip(trip('t'));
  });
  tearDown(() => state.dispose());

  test('capture → job → mixed review → receipt → portable accountant pack',
      () async {
    await state.addJobSite(job());
    expect(state.taxSummary.businessKm, 0);
    await state.reviewWorkflowTrip(
        tripId: 't',
        classification: TripClassification.business,
        purpose: 'Install switchboard for Smith',
        businessKm: 15,
        allocationReason: '5 km private detour measured separately',
        jobId: 'job');
    final receiptDir = await Directory.systemTemp.createTemp('workflow-e2e-');
    try {
      final receipt = await File('${receiptDir.path}/receipt.pdf')
          .writeAsString('%PDF-1.4\nmanual receipt fixture');
      state.recordExpense(VehicleExpense(
          id: 'e',
          vehicleId: 'v',
          amount: 100,
          category: ExpenseCategory.fuel,
          date: date,
          receiptPath: receipt.path));
      await state.assignWorkflowExpense(
          expenseId: 'e', tripId: 't', jobId: 'job');
      expect(state.trips.single.linkedExpenseIds, ['e']);
      expect(storage.loadExpenses().single.jobId, 'job');
      final restored = storage.loadTrips().single;
      expect(restored.jobId, 'job');
      expect(restored.businessDistanceKm, 15);
      expect(restored.distanceKm, 20);
      expect(restored.startOdometer, 100);
      expect(restored.endOdometer, 120);
      expect(state.taxSummary.businessPercentage, 75);
      expect(state.taxSummary.logbookClaim, 75);
      final pack = await const TaxPackBuilder().build(
          vehicle: vehicle,
          taxRule: AppConstants.activeTaxRule,
          trips: storage.loadTrips(),
          expenses: storage.loadExpenses(),
          jobs: storage.loadJobSites(),
          outputDirectory: receiptDir);
      final archive = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
      final result = TaxPackReader(archive);
      expect(result.rows('Trips').single['Job name'], 'Smith renovation');
      expect(result.rows('Trips').single['Business km'], 15);
      expect(result.rows('Trip changes').last['Classification'], 'business');
      expect(result.rows('Trips').single['Classification'], 'MIXED');
      expect(result.searchableText, isNot(contains('PRIVATE_ROUTE_SENTINEL')));
      expect(result.summaryValue('Business km'), 15);
      expect(archive.files.where((f) => f.name.startsWith('Receipts/')),
          hasLength(1));
      await state.removeJobSite('job');
      expect(state.jobSites.single.isActive, isFalse);
      expect(state.trips.single.jobId, 'job');
      await state.reviewWorkflowTrip(
          tripId: 't',
          classification: TripClassification.unclassified,
          purpose: '',
          businessKm: 0);
      expect(state.taxSummary.businessKm, 0);
      expect(storage.loadTrips().single.review['history'], hasLength(2));
      await state.assignWorkflowExpense(expenseId: 'e');
      expect(storage.loadExpenses().single.linkedTripId, isNull);
      expect(state.trips.single.linkedExpenseIds, isEmpty);
    } finally {
      await receiptDir.delete(recursive: true);
    }
  });

  test('invalid mixed allocation and cross-vehicle links cannot mutate records',
      () async {
    await expectLater(
        state.reviewWorkflowTrip(
            tripId: 't',
            classification: TripClassification.business,
            purpose: 'Repair client wiring',
            businessKm: 21),
        throwsArgumentError);
    await expectLater(
        state.reviewWorkflowTrip(
            tripId: 't',
            classification: TripClassification.business,
            purpose: 'Repair client wiring',
            businessKm: 15),
        throwsArgumentError);
    expect(state.trips.single.classification, TripClassification.unclassified);
    state.recordExpense(VehicleExpense(
        id: 'e',
        vehicleId: 'other',
        amount: 10,
        category: ExpenseCategory.fuel,
        date: date));
    await expectLater(state.assignWorkflowExpense(expenseId: 'e', tripId: 't'),
        throwsArgumentError);
    expect(state.expenses.single.linkedTripId, isNull);
  });

  test(
      'personal reclassification clears job and leaves prior decisions traceable',
      () async {
    await state.addJobSite(job());
    await state.reviewWorkflowTrip(
        tripId: 't',
        classification: TripClassification.business,
        purpose: 'Repair client wiring',
        businessKm: 20,
        jobId: 'job');
    await state.reviewWorkflowTrip(
        tripId: 't',
        classification: TripClassification.personal,
        purpose: '',
        businessKm: 0);
    expect(state.trips.single.jobId, isNull);
    expect(state.trips.single.businessDistanceKm, 0);
    expect(storage.loadTrips().single.review['history'], hasLength(2));
    expect(job().containsCoordinate(lat: 0, lng: 0), isFalse);
  });

  testWidgets(
      'empty vehicle can capture records before accountant sending is enabled',
      (tester) async {
    state.deleteTrip('t');
    await tester.pumpWidget(MaterialApp(home: WorkflowScreen(appState: state)));
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Tracking settings'))
            .onPressed,
        isNotNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Add trip'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('3. Receipts'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add receipt manually'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('4. Pack'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Send to accountant'))
            .onPressed,
        isNull);
  });

  testWidgets('review form saves actual mixed distance and returns to workflow',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: WorkflowScreen(appState: state)));
    await tester.tap(find.text('20.0 km · Unclassified'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowTripEditor), findsOneWidget);
    await tester.tap(find.text('Mixed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Business purpose'),
        'Repair Smith switchboard');
    await tester.enterText(
        find.widgetWithText(TextField, 'Business distance (km)'), '15');
    await tester.enterText(
        find.widgetWithText(TextField, 'Allocation explanation'),
        '5 km measured private detour');
    await tester.ensureVisible(find.text('Save review'));
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(state.trips.single.businessDistanceKm, 15);
    expect(find.byType(WorkflowScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'cloud round trip preserves undecided status, mixed review and local job identity',
      () async {
    final tables = <String, List<dynamic>>{};
    final client = MockClient((request) async {
      final table = request.url.path.split('/').last;
      if (request.method == 'POST') {
        tables[table] = jsonDecode(request.body) as List<dynamic>;
        return http.Response('[]', 201);
      }
      return http.Response(jsonEncode(tables[table] ?? []), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final sync = SyncEngineService(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test',
        httpClient: client);
    await state.addJobSite(job());
    await state.reviewWorkflowTrip(
        tripId: 't',
        classification: TripClassification.business,
        purpose: 'Repair Smith switchboard',
        businessKm: 15,
        jobId: 'job',
        allocationReason: '5 km private detour');
    state.recordTrip(trip('undecided'));
    final result = await sync.syncToCloud(
        vehicle: vehicle,
        trips: state.trips,
        expenses: [],
        userToken: 'test-token',
        userId: 'test-user');
    expect(result.success, isTrue);
    await sync.syncJobSitesToCloud(
        jobSites: state.jobSites, userToken: 'test-token', userId: 'test-user');
    expect(tables['job_sites']!.single['id'], isNot('job'));
    expect(tables['job_sites']!.single['local_id'], 'job');
    final restored = await sync.restoreFromCloud(
        userToken: 'test-token', userId: 'test-user');
    expect(restored.success, isTrue);
    expect(restored.jobSites.single.id, 'job');
    expect(restored.jobSites.single.trackingEnabled, isFalse);
    final mixed = restored.trips.firstWhere((t) => t.id == 't');
    expect(mixed.businessDistanceKm, 15);
    expect(mixed.jobId, restored.jobSites.single.id);
    expect(mixed.review['history'], hasLength(1));
    expect(restored.trips.firstWhere((t) => t.id == 'undecided').classification,
        TripClassification.unclassified);
    client.close();
  });
  test('failed persistence does not close over an unsaved decision or receipt',
      () async {
    final failing =
        RejectingWorkflowStorage(await SharedPreferences.getInstance());
    final reviewState = AppState(storageService: failing)
      ..addVehicle(vehicle)
      ..recordTrip(trip('saved'));
    addTearDown(reviewState.dispose);
    failing.reject = true;
    await expectLater(
        reviewState.reviewWorkflowTrip(
            tripId: 'saved',
            classification: TripClassification.business,
            purpose: 'Repair client switchboard',
            businessKm: 20),
        throwsStateError);
    expect(reviewState.trips.single.classification,
        TripClassification.unclassified);
    expect(failing.loadTrips().single.classification,
        TripClassification.unclassified);
    await expectLater(
        reviewState.saveWorkflowReceipt(VehicleExpense(
            id: 'failed',
            vehicleId: 'v',
            date: date,
            amount: 50,
            category: ExpenseCategory.fuel)),
        throwsStateError);
    expect(reviewState.expenses, isEmpty);
    expect(failing.loadExpenses(), isEmpty);
  });
}
