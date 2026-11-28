import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/state/app_state.dart';

void main() {
  const service = EvidenceReviewService();

  test('home review getters follow active vehicle and financial year', () {
    final appState = AppState();
    final year =
        int.parse(appState.activeTaxRule.financialYear.substring(0, 4));
    appState.addVehicle(Vehicle(
        id: 'first',
        make: 'Toyota',
        model: 'Hilux',
        regoPlate: 'FIRST',
        initialOdometer: 100));
    appState.addVehicle(Vehicle(
        id: 'second',
        make: 'Mazda',
        model: '3',
        regoPlate: 'SECOND',
        initialOdometer: 100));
    appState.selectVehicle('first');
    for (final record in [
      (id: 'current', vehicle: 'first', year: year, deleted: false),
      (id: 'other', vehicle: 'second', year: year, deleted: false),
      (id: 'past', vehicle: 'first', year: year - 1, deleted: false),
      (id: 'deleted', vehicle: 'first', year: year, deleted: true),
    ]) {
      appState.recordTrip(Trip(
          id: record.id,
          vehicleId: record.vehicle,
          date: DateTime(record.year, 8, 1),
          distanceKm: 12.0,
          startOdometer: 1000.0,
          endOdometer: 1012.0,
          purpose: 'Business',
          deletedAt: record.deleted ? DateTime(year, 8, 2) : null));
      appState.recordExpense(VehicleExpense(
          id: record.id,
          vehicleId: record.vehicle,
          amount: 12,
          category: ExpenseCategory.tollsParking,
          date: DateTime(record.year, 8, 1),
          deletedAt: record.deleted ? DateTime(year, 8, 2) : null));
    }
    expect(appState.missingComplianceTrips.map((trip) => trip.id), ['current']);
    expect(appState.unclassifiedExpenses.map((expense) => expense.id),
        ['current']);
    appState.selectVehicle('second');
    expect(appState.missingComplianceTrips.map((trip) => trip.id), ['other']);
    expect(
        appState.unclassifiedExpenses.map((expense) => expense.id), ['other']);
    appState.dispose();
  });
  final vehicle = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Hilux',
      regoPlate: 'TEST',
      initialOdometer: 100);
  Trip trip(String id,
          {String vehicleId = 'v1',
          DateTime? date,
          String purpose = 'Business',
          bool deleted = false,
          TripClassification classification = TripClassification.business}) =>
      Trip(
          id: id,
          vehicleId: vehicleId,
          date: date ?? DateTime(2026, 8, 1),
          purpose: purpose,
          classification: classification,
          deletedAt: deleted ? DateTime(2026, 8, 2) : null);

  test(
      'review and draft eligibility use live vehicle and financial year records',
      () {
    final report = service.evaluate(
      vehicle: vehicle,
      financialYear: '2026–27',
      expenses: [],
      trips: [
        trip('current'),
        trip('other', vehicleId: 'v2'),
        trip('past', date: DateTime(2025, 8, 1)),
        trip('deleted', deleted: true),
        trip('personal',
            purpose: '', classification: TripClassification.personal)
      ],
    );
    expect(
        report.trips.map((trip) => trip.id).toSet(), {'current', 'personal'});
    expect(report.items.whereType<TripReviewItem>().map((item) => item.tripId),
        ['current']);
    expect(report.canExport, true);
    expect(report.isComplete, false);
    final empty = service.evaluate(
        vehicle: vehicle, financialYear: '2026-27', trips: [], expenses: []);
    expect(empty.canExport, false);
    expect(empty.items.single.description, 'No records in this financial year');
  });

  test(
      'specific purposes allow question marks and generic fallbacks stay pending',
      () {
    final report = service.evaluate(
        vehicle: vehicle,
        financialYear: '2026-27',
        expenses: [],
        trips: [
          trip('specific',
              purpose:
                  'Discuss quote questions? with client at 42 High Street'),
          trip('fallback', purpose: 'Client / Job'),
          trip('tools', purpose: 'Business (Bulky Tools Carried)')
        ]);
    expect(
        report.items
            .whereType<TripReviewItem>()
            .map((item) => item.tripId)
            .toSet(),
        {'fallback', 'tools'});
  });

  test('confirmed files can complete, changed files and OCR matching cannot',
      () async {
    final directory = await Directory.systemTemp.createTemp('review-files-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        await File('${directory.path}/receipt.jpg').writeAsBytes([1, 2, 3]);
    VehicleExpense expense(String id, ReceiptReviewStatus status,
            {String? hash, bool vault = false}) =>
        VehicleExpense(
            id: id,
            vehicleId: 'v1',
            amount: 40,
            category: ExpenseCategory.tollsParking,
            date: DateTime(2026, 8, 1),
            receiptPath: file.path,
            isVaultOnly: vault,
            receiptAudit: ReceiptAuditTrail(
                reviewStatus: status,
                capturedAt: DateTime(2026, 8, 1),
                imageSha256: hash));
    final confirmed = expense('confirmed', ReceiptReviewStatus.confirmed);
    final inspected = await service.inspectReceipts([confirmed]);
    expect(inspected['confirmed']!.sha256,
        '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81');
    final complete = service.evaluate(
        vehicle: vehicle,
        financialYear: '2026-27',
        trips: [],
        expenses: [confirmed],
        receiptFiles: inspected);
    expect(complete.isComplete, true);
    final changed =
        expense('changed', ReceiptReviewStatus.confirmed, hash: 'old');
    final ocrOnly = expense('ocr', ReceiptReviewStatus.verified);
    final vault =
        expense('vault', ReceiptReviewStatus.manualReview, vault: true);
    final files = await service.inspectReceipts([changed, ocrOnly, vault]);
    final report = service.evaluate(
        vehicle: vehicle,
        financialYear: '2026-27',
        trips: [],
        expenses: [changed, ocrOnly, vault],
        receiptFiles: files);
    expect(report.expenses.map((expense) => expense.id).toSet(),
        {'changed', 'ocr', 'vault'});
    expect(
        report.items
            .whereType<ExpenseReviewItem>()
            .map((item) => item.expenseId)
            .toSet(),
        {'changed', 'ocr'});
    expect(
        (report.items
            .whereType<ExpenseReviewItem>()
            .firstWhere((item) => item.expenseId == 'changed')).reasons,
        [ExpenseReviewReason.changedPhoto]);
    expect(
        (report.items
            .whereType<ExpenseReviewItem>()
            .firstWhere((item) => item.expenseId == 'ocr')).reasons,
        [ExpenseReviewReason.unconfirmedDetails]);
    await file.delete();
    expect((await service.inspectReceipts([confirmed]))['confirmed']!.status,
        ReceiptFileStatus.missing);
  });
}
