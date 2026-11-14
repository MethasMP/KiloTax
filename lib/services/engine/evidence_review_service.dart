import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../data/models/trip.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';
import '../tax/ato_tax_period_engine.dart';

enum ReceiptFileStatus { unknown, available, missing, changed }

enum TripReviewReason { classification, purpose }

enum ExpenseReviewReason {
  missingPhoto,
  unavailablePhoto,
  changedPhoto,
  uncheckedPhoto,
  unconfirmedDetails,
  allocationReview,
}

enum SetupReviewReason { vehicle, noRecords, openingOdometer }

sealed class EvidenceReviewItem {
  const EvidenceReviewItem();

  String get description;
}

final class TripReviewItem extends EvidenceReviewItem {
  final String tripId;
  final List<TripReviewReason> reasons;

  const TripReviewItem({required this.tripId, required this.reasons});

  @override
  String get description => reasons
      .map((reason) => switch (reason) {
            TripReviewReason.classification => 'Choose business or personal',
            TripReviewReason.purpose => 'Add a business purpose',
          })
      .join('. ');
}

final class ExpenseReviewItem extends EvidenceReviewItem {
  final String expenseId;
  final List<ExpenseReviewReason> reasons;

  const ExpenseReviewItem({required this.expenseId, required this.reasons});

  @override
  String get description => reasons
      .map((reason) => switch (reason) {
            ExpenseReviewReason.missingPhoto => 'Attach a receipt',
            ExpenseReviewReason.unavailablePhoto =>
              'Receipt file is unavailable',
            ExpenseReviewReason.changedPhoto => 'Receipt file has changed',
            ExpenseReviewReason.uncheckedPhoto =>
              'Receipt file has not been checked',
            ExpenseReviewReason.allocationReview =>
              'Review receipt allocations; unresolved items excluded',
            ExpenseReviewReason.unconfirmedDetails =>
              'Confirm the expense details',
          })
      .join('. ');
}

final class SetupReviewItem extends EvidenceReviewItem {
  final SetupReviewReason reason;

  const SetupReviewItem(this.reason);

  @override
  String get description => switch (reason) {
        SetupReviewReason.vehicle => 'Add a vehicle to start your records',
        SetupReviewReason.noRecords => 'No records in this financial year',
        SetupReviewReason.openingOdometer => 'Record the starting odometer',
      };
}

final class OdometerReviewItem extends EvidenceReviewItem {
  const OdometerReviewItem();

  @override
  String get description =>
      'Unexplained odometer distance: review unrecorded travel (never auto-filled)';
}

final class ReceiptFileInspection {
  final ReceiptFileStatus status;
  final String? sha256;

  const ReceiptFileInspection({required this.status, this.sha256});
}

final class EvidenceReviewReport {
  final Vehicle? vehicle;
  final String financialYear;
  final List<Trip> trips;
  final List<VehicleExpense> expenses;
  final List<EvidenceReviewItem> items;

  const EvidenceReviewReport({
    required this.vehicle,
    required this.financialYear,
    required this.trips,
    required this.expenses,
    required this.items,
  });

  static DateTime weekStart(DateTime date) {
    return DateTime(
        date.year, date.month, date.day - (date.weekday - DateTime.monday));
  }

  List<EvidenceReviewItem> itemsBetween(DateTime? start, DateTime end) {
    final tripDates = {for (final trip in trips) trip.id: trip.date};
    final expenseDates = {
      for (final expense in expenses) expense.id: expense.date
    };
    return items.where((item) {
      final date = switch (item) {
        TripReviewItem() => tripDates[item.tripId],
        ExpenseReviewItem() => expenseDates[item.expenseId],
        _ => null,
      };
      return date != null &&
          (start == null || !date.isBefore(start)) &&
          date.isBefore(end);
    }).toList(growable: false);
  }

  List<EvidenceReviewItem> itemsForWeek(DateTime date) {
    final start = weekStart(date);
    return itemsBetween(
        start, DateTime(start.year, start.month, start.day + 7));
  }

  bool get hasRecords => trips.isNotEmpty || expenses.isNotEmpty;
  bool get canExport => vehicle != null && hasRecords;
  bool get isComplete => canExport && items.isEmpty;
}

class EvidenceReviewService {
  const EvidenceReviewService();

  static bool hasMeaningfulBusinessPurpose(String purpose) {
    final normalized = purpose
        .replaceAll(
            RegExp(r'\s*\(Bulky Tools Carried\)', caseSensitive: false), '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return !const {
      '',
      '?',
      '-',
      'business',
      'work',
      'business trip',
      'work trip',
      'client / job',
      'client job site',
      'client / job site visit',
      'supplier / materials',
      'work site inspection',
      'unclassified',
      'unknown',
      'unknown purpose',
    }.contains(normalized);
  }

  EvidenceReviewReport evaluate({
    required Vehicle? vehicle,
    required String financialYear,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    Map<String, ReceiptFileInspection> receiptFiles = const {},
    bool hasOdometerGaps = false,
  }) {
    const periods = AtoTaxPeriodEngine();
    final normalizedYear = financialYear.replaceAll('–', '-');
    bool inYear(DateTime date) =>
        periods.forDate(date).shortLabel.replaceAll('–', '-') == normalizedYear;
    final scopedTrips = trips
        .where((trip) =>
            vehicle != null &&
            trip.vehicleId == vehicle.id &&
            !trip.isDeleted &&
            inYear(trip.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final scopedExpenses = expenses
        .where((expense) =>
            vehicle != null &&
            expense.vehicleId == vehicle.id &&
            !expense.isDeleted &&
            inYear(expense.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final items = <EvidenceReviewItem>[];
    if (vehicle == null) {
      items.add(const SetupReviewItem(SetupReviewReason.vehicle));
    } else {
      if (scopedTrips.isEmpty && scopedExpenses.isEmpty) {
        items.add(const SetupReviewItem(SetupReviewReason.noRecords));
      }
      if (vehicle.taxMethod == TaxMethod.logbook &&
          vehicle.initialOdometer <= 0) {
        items.add(const SetupReviewItem(SetupReviewReason.openingOdometer));
      }
    }
    for (final trip in scopedTrips) {
      final reasons = <TripReviewReason>[
        if (trip.classification == TripClassification.unclassified)
          TripReviewReason.classification,
        if (trip.classification != TripClassification.personal &&
            !hasMeaningfulBusinessPurpose(trip.purpose))
          TripReviewReason.purpose,
      ];
      if (reasons.isNotEmpty) {
        items.add(TripReviewItem(
            tripId: trip.id, reasons: List.unmodifiable(reasons)));
      }
    }
    for (final expense in scopedExpenses) {
      if (expense.isVaultOnly) continue;
      final reasons = <ExpenseReviewReason>[];
      if (expense.allocationError != null ||
          expense.allocations
              .any((line) => line.purpose == AllocationPurpose.unresolved)) {
        reasons.add(ExpenseReviewReason.allocationReview);
      }
      if (expense.receiptPath == null || expense.receiptPath!.trim().isEmpty) {
        reasons.add(ExpenseReviewReason.missingPhoto);
      } else {
        final status =
            receiptFiles[expense.id]?.status ?? ReceiptFileStatus.unknown;
        switch (status) {
          case ReceiptFileStatus.unknown:
            reasons.add(ExpenseReviewReason.uncheckedPhoto);
          case ReceiptFileStatus.missing:
            reasons.add(ExpenseReviewReason.unavailablePhoto);
          case ReceiptFileStatus.changed:
            reasons.add(ExpenseReviewReason.changedPhoto);
          case ReceiptFileStatus.available:
            break;
        }
      }
      if (expense.receiptAudit?.reviewStatus != ReceiptReviewStatus.confirmed) {
        reasons.add(ExpenseReviewReason.unconfirmedDetails);
      }
      if (reasons.isNotEmpty) {
        items.add(ExpenseReviewItem(
            expenseId: expense.id, reasons: List.unmodifiable(reasons)));
      }
    }
    if (hasOdometerGaps && vehicle?.taxMethod == TaxMethod.logbook) {
      items.add(const OdometerReviewItem());
    }
    return EvidenceReviewReport(
      vehicle: vehicle,
      financialYear: financialYear,
      trips: List.unmodifiable(scopedTrips),
      expenses: List.unmodifiable(scopedExpenses),
      items: List.unmodifiable(items),
    );
  }

  Future<Map<String, ReceiptFileInspection>> inspectReceipts(
    List<VehicleExpense> expenses,
  ) async {
    final inspections = <String, ReceiptFileInspection>{};
    for (final expense in expenses) {
      final path = expense.receiptPath;
      if (path == null || path.trim().isEmpty) {
        inspections[expense.id] =
            const ReceiptFileInspection(status: ReceiptFileStatus.missing);
        continue;
      }
      try {
        final bytes = await File(path).readAsBytes();
        if (bytes.isEmpty) {
          inspections[expense.id] =
              const ReceiptFileInspection(status: ReceiptFileStatus.missing);
          continue;
        }
        final digest = sha256.convert(bytes).toString();
        final expected = expense.receiptAudit?.imageSha256;
        inspections[expense.id] = ReceiptFileInspection(
          status: expected != null && expected != digest
              ? ReceiptFileStatus.changed
              : ReceiptFileStatus.available,
          sha256: digest,
        );
      } on FileSystemException {
        inspections[expense.id] =
            const ReceiptFileInspection(status: ReceiptFileStatus.missing);
      }
    }
    return Map.unmodifiable(inspections);
  }
}
