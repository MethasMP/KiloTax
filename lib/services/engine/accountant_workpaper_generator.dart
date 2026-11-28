import '../../core/constants/app_constants.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import 'evidence_review_service.dart';

class AccountantWorkpaperGenerator {
  String generateWorkpaper({
    required String clientName,
    required String abn,
    required String vehicleModel,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    required String financialYear,
    Map<String, ReceiptFileInspection>? receiptInspections,
    Map<String, String>? receiptArchivePaths,
    String? vehicleId,
    bool includeCloudUrls = true,
  }) {
    final totalKm = trips.fold<double>(0, (sum, trip) => sum + trip.distanceKm);
    final businessKm = trips
        .where((trip) => trip.isBusiness)
        .fold<double>(0, (sum, trip) => sum + trip.businessDistanceKm);
    final businessPercentage = totalKm > 0 ? businessKm / totalKm * 100 : 0.0;
    var referenceCount = 0;
    var accessibleCount = 0;
    var confirmedCount = 0;
    var ocrMatchedCount = 0;
    var referencedExpenseTotal = 0.0;
    for (final expense in expenses) {
      if (expense.receiptPath?.trim().isNotEmpty == true) {
        referenceCount++;
        referencedExpenseTotal += expense.amount;
      }
      final status = receiptInspections?[expense.id]?.status;
      if (status == ReceiptFileStatus.available ||
          status == ReceiptFileStatus.changed) {
        accessibleCount++;
      }
      if (status == ReceiptFileStatus.available) {
        if (expense.receiptAudit?.reviewStatus ==
            ReceiptReviewStatus.confirmed) {
          confirmedCount++;
        } else if (expense.receiptAudit?.reviewStatus ==
            ReceiptReviewStatus.verified) {
          ocrMatchedCount++;
        }
      }
    }
    final buffer = StringBuffer()
      ..writeln('# KILOCLAIM RECORDED DATA WORKPAPER')
      ..writeln('Review records and tax treatment with your tax agent.')
      ..writeln('Taxpayer / Client: ${_cell(clientName)}')
      ..writeln('ABN: ${_cell(abn)}')
      ..writeln('Vehicle: ${_cell(vehicleModel)}')
      ..writeln('Financial Year: ${_cell(financialYear)}')
      ..writeln('')
      ..writeln('## Recorded travel summary')
      ..writeln('- Total Logged: ${totalKm.toStringAsFixed(1)} km')
      ..writeln('- Business Kilometres: ${businessKm.toStringAsFixed(1)} km')
      ..writeln(
          '- Business Use Percentage: ${businessPercentage.toStringAsFixed(2)}%')
      ..writeln(
          'This percentage describes the supplied records. It does not establish eligibility or a completed logbook.')
      ..writeln('')
      ..writeln('## Receipt record checks')
      ..writeln('- Recorded expenses: ${expenses.length}')
      ..writeln(
          '- Attached receipt references: $referenceCount of ${expenses.length}')
      ..writeln(
          '- Expenses with a saved receipt reference: \$${referencedExpenseTotal.toStringAsFixed(2)}')
      ..writeln('- Accessible on disk: $accessibleCount of ${expenses.length}')
      ..writeln(
          '- Human-confirmed with available files: $confirmedCount of ${expenses.length}')
      ..writeln(
          '- OCR-matched with available files: $ocrMatchedCount of ${expenses.length}')
      ..writeln(
          '- Missing or unconfirmed receipts: ${expenses.length - confirmedCount} of ${expenses.length}')
      ..writeln(
          'File inspection is unknown when no inspection result was supplied. A saved OCR match is not human confirmation.')
      ..writeln(
          'Vault-only expenses are records, not additions to the calculation. Use summary.pdf and review-issues.csv for the selected method and unresolved checks.')
      ..writeln('')
      ..writeln('## Statutory Expense Substantiation & Record Categorization')
      ..writeln(
          'ATO substantiation separates pooled vehicle running costs (Fuel, Rego, Insurance, Maintenance scaled by Logbook %) from direct work/project supply expenses.')
      ..writeln('')
      ..writeln('## Linked records')
      ..writeln(
          'Links help locate related records. They do not establish business purpose or tax eligibility.')
      ..writeln(
          '| Date | Expense ID | Category | Amount (AUD) | Linked trip ID | Linked Trip Date | Linked Trip Odometer Range | Recorded route | Cloud receipt URL | Archive file |')
      ..writeln(
          '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
    final tripsById = {for (final trip in trips) trip.id: trip};
    final resolvedVehicleId = vehicleId ??
        (trips.isNotEmpty
            ? trips.first.vehicleId
            : (expenses.isNotEmpty ? expenses.first.vehicleId : 'vehicle'));
    for (final expense in expenses) {
      final trip = tripsById[expense.linkedTripId];
      final tripDate = trip != null
          ? trip.date.toIso8601String().substring(0, 10)
          : 'Not linked in this scope';
      final tripOdoRange = trip != null
          ? '${trip.startOdometer.toStringAsFixed(0)} - ${trip.endOdometer.toStringAsFixed(0)} KM'
          : 'Not linked in this scope';
      final route = trip == null
          ? 'Not linked in this scope'
          : !trip.shareRoute
              ? '[Private or unclassified journey]'
              : '${trip.originAddress ?? "Not recorded"} to ${trip.destinationAddress ?? "Not recorded"}';
      final cloudUrl = includeCloudUrls
          ? ((expense.receiptPath != null && expense.receiptPath!.isNotEmpty)
              ? '${AppConstants.supabaseUrl}/storage/v1/object/public/${AppConstants.receiptStorageBucket}/$resolvedVehicleId/${expense.id}.webp'
              : 'No receipt file')
          : (expense.receiptPath != null && expense.receiptPath!.isNotEmpty
              ? 'Attached'
              : 'No receipt file');
      final cells = [
        expense.date.toIso8601String().substring(0, 10),
        expense.id,
        expense.category.displayName,
        '${expense.amount.toStringAsFixed(2)} (vehicle/work ${expense.allocatedWorkAmount.toStringAsFixed(2)})',
        trip?.id ?? 'Not linked in this scope',
        tripDate,
        tripOdoRange,
        route,
        cloudUrl,
        receiptArchivePaths?[expense.id] ?? 'Not included',
      ];
      buffer.writeln('| ${cells.map(_cell).join(' | ')} |');
    }
    return buffer.toString();
  }

  static String _cell(String value) {
    final plain = value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('|', '&#124;')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    const markdownCharacters = ['\\', '`', '*', '_', '[', ']', '(', ')', '!'];
    return plain.split('').map((character) {
      return markdownCharacters.contains(character)
          ? '\\$character'
          : character;
    }).join();
  }
}
