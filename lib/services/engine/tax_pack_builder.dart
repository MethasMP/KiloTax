import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/csv_security.dart';
import '../../core/utils/export_file_name_helper.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/job_site.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import 'accountant_workpaper_generator.dart';
import 'cpk_export_service.dart';
import 'evidence_review_service.dart';
import 'logbook_export_service.dart';
import 'pdf_export_service.dart';
import 'tax_calculator_service.dart';

class TaxPackArtifact {
  final Directory directory;
  final File file;
  final EvidenceReviewReport report;
  final int receiptCount;
  final int issueCount;

  const TaxPackArtifact({
    required this.directory,
    required this.file,
    required this.report,
    required this.receiptCount,
    required this.issueCount,
  });

  String get description =>
      'Vehicle ${report.vehicle!.regoPlate}, FY${report.financialYear}. '
      'ZIP contains a recorded-data PDF, trip ledger, expense index, record sources, '
      '$receiptCount receipt files, and $issueCount review items. '
      'Receipt files are included as recorded, not verified for accuracy or tax eligibility. '
      'Review the package before lodging a claim.';
}

class TaxPackBuilder {
  const TaxPackBuilder();

  Future<TaxPackArtifact> build({
    required Vehicle vehicle,
    required AtoTaxRule taxRule,
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
    required Directory outputDirectory,
    List<JobSite> jobs = const [],
    bool hasOdometerGaps = false,
    DateTime? generatedAt,
    int pendingDraftCount = 0,
  }) async {
    const reviewer = EvidenceReviewService();
    final snapshot = reviewer.evaluate(
      vehicle: vehicle,
      financialYear: taxRule.financialYear,
      trips: trips,
      expenses: expenses,
      hasOdometerGaps: hasOdometerGaps,
    );
    if (!snapshot.canExport) {
      throw StateError(
          'Add a trip or expense for this vehicle and financial year first.');
    }
    final archive = Archive();
    final inspections = <String, ReceiptFileInspection>{};
    final receiptNames = <String, String>{};
    final extraIssues = <List<String>>[];
    var receiptCount = 0;
    final receiptExpenses = [...snapshot.expenses]..sort((left, right) {
        final byDate = left.date.compareTo(right.date);
        return byDate == 0 ? left.id.compareTo(right.id) : byDate;
      });
    final receiptPages = <String, List<Map<String, dynamic>>>{};
    if (pendingDraftCount > 0) {
      extraIssues.add([
        'inbox',
        '',
        '$pendingDraftCount pending receipt drafts are excluded from the expense ledger and totals.'
      ]);
    }
    for (final expense in receiptExpenses) {
      final audit = expense.receiptAudit;
      final recordedPages = audit?.currentFields['pagePaths'];
      final paths = recordedPages is List && recordedPages.isNotEmpty
          ? recordedPages.whereType<String>().toList()
          : [if (expense.receiptPath != null) expense.receiptPath!];
      final hashes = audit?.currentFields['pageHashes'];
      final pages = <Map<String, dynamic>>[];
      var missing = paths.isEmpty;
      var changed = false;
      String? firstDigest;
      for (var pageIndex = 0; pageIndex < paths.length; pageIndex++) {
        Uint8List? bytes;
        try {
          bytes = await File(paths[pageIndex]).readAsBytes();
        } on FileSystemException {
          bytes = null;
        }
        final savedDigest = hashes is List && pageIndex < hashes.length
            ? hashes[pageIndex] as String?
            : hashes is Map
                ? hashes[paths[pageIndex]] as String?
                : pageIndex == 0
                    ? audit?.extractionImageSha256 ?? audit?.imageSha256
                    : null;
        if (bytes == null || bytes.isEmpty) {
          missing = true;
          pages.add({
            'page': pageIndex + 1,
            'status': 'missing',
            'savedSha256': savedDigest
          });
          extraIssues.add([
            'expense',
            expense.id,
            'Receipt page ${pageIndex + 1} is unavailable.'
          ]);
          continue;
        }
        final digest = sha256.convert(bytes).toString();
        firstDigest ??= digest;
        final pageChanged = savedDigest != null && savedDigest != digest;
        changed = changed || pageChanged;
        receiptCount++;
        final extension = _extension(bytes);
        final name =
            'receipts/receipt-${receiptCount.toString().padLeft(6, '0')}.$extension';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
        receiptNames.putIfAbsent(expense.id, () => name);
        pages.add({
          'page': pageIndex + 1,
          'archivePath': name,
          'sha256': digest,
          'savedSha256': savedDigest,
          'status': pageChanged ? 'changed' : 'available'
        });
        if (pageChanged || extension == 'bin') {
          extraIssues.add([
            'expense',
            expense.id,
            pageChanged
                ? 'Receipt page ${pageIndex + 1} differs from the saved fingerprint.'
                : 'Receipt format is unrecognized. File bytes are included for manual review.'
          ]);
        }
      }
      if (missing && expense.isVaultOnly) {
        extraIssues.add([
          'expense',
          expense.id,
          'Receipt file unavailable for this vault-only record.'
        ]);
      }
      receiptPages[expense.id] = pages;
      inspections[expense.id] = ReceiptFileInspection(
          status: changed
              ? ReceiptFileStatus.changed
              : missing
                  ? ReceiptFileStatus.missing
                  : ReceiptFileStatus.available,
          sha256: firstDigest);
    }
    final inspectedReport = reviewer.evaluate(
      vehicle: vehicle,
      financialYear: taxRule.financialYear,
      trips: snapshot.trips,
      expenses: snapshot.expenses,
      receiptFiles: inspections,
      hasOdometerGaps: hasOdometerGaps,
    );
    final orderedTrips = [...inspectedReport.trips]..sort((left, right) {
        final byDate = left.date.compareTo(right.date);
        return byDate == 0 ? left.id.compareTo(right.id) : byDate;
      });
    final orderedExpenses = [...inspectedReport.expenses]..sort((left, right) {
        final byDate = left.date.compareTo(right.date);
        return byDate == 0 ? left.id.compareTo(right.id) : byDate;
      });
    final report = EvidenceReviewReport(
      vehicle: inspectedReport.vehicle,
      financialYear: inspectedReport.financialYear,
      trips: List.unmodifiable(orderedTrips),
      expenses: List.unmodifiable(orderedExpenses),
      items: inspectedReport.items,
    );
    final ledgerRows = <String, int>{};
    for (final trip in report.trips) {
      if (vehicle.taxMethod == TaxMethod.logbook || trip.isBusiness) {
        ledgerRows[trip.id] = ledgerRows.length + 1;
      }
    }
    final summary = TaxCalculatorService.evaluateSummary(
      trips: report.trips,
      expenses: report.expenses,
      taxRule: taxRule,
    );
    for (final trip in report.trips) {
      if (trip.taxMethod != vehicle.taxMethod) {
        extraIssues.add([
          'trip',
          trip.id,
          'Recorded trip method differs from the selected vehicle method. Review the method before claiming.'
        ]);
      }
    }
    for (final expense in report.expenses) {
      if (expense.linkedTripId != null &&
          !report.trips.any((t) => t.id == expense.linkedTripId)) {
        extraIssues.add([
          'expense',
          expense.id,
          'Linked trip is not available in this vehicle/year pack. Review the connection.'
        ]);
      }
    }
    final issues = <List<String>>[
      for (final item in report.items)
        [
          item is TripReviewItem
              ? 'trip'
              : item is ExpenseReviewItem
                  ? 'expense'
                  : 'setup',
          item is TripReviewItem
              ? item.tripId
              : item is ExpenseReviewItem
                  ? item.expenseId
                  : '',
          item.description,
        ],
      ...extraIssues,
    ];
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    final pdf = await compute(_renderPdf, (
      vehicle: vehicle,
      taxRule: taxRule,
      trips: report.trips,
      summary: summary,
      regular: regular,
      bold: bold,
    ));
    archive.addFile(ArchiveFile('summary.pdf', pdf.length, pdf));

    final tripsById = {for (final t in report.trips) t.id: t};
    final workpaperText = AccountantWorkpaperGenerator().generateWorkpaper(
      clientName: 'Not provided',
      abn: 'Not provided',
      vehicleModel: '${vehicle.make} ${vehicle.model} (${vehicle.regoPlate})',
      trips: report.trips,
      expenses: report.expenses,
      financialYear: taxRule.financialYear,
      receiptInspections: inspections,
      receiptArchivePaths: receiptNames,
      includeCloudUrls: false,
    );
    _addText(archive, '01_Executive_Tax_Workpaper.md', workpaperText);
    final jobsById = {for (final job in jobs) job.id: job};
    _addText(
        archive,
        'job-connections.csv',
        _csv([
          [
            'Record_Type',
            'Record_ID',
            'Job_ID',
            'Job_Name',
            'Client',
            'Project_Reference',
            'Business_KM',
            'Private_Or_Undecided_KM',
            'Review_State',
            'Confirmed_At',
            'Allocation_Basis'
          ],
          for (final trip in report.trips)
            [
              'trip',
              trip.id,
              trip.isBusiness ? trip.jobId ?? '' : '',
              trip.isBusiness
                  ? jobsById[trip.jobId]?.name ?? trip.jobReference ?? ''
                  : '',
              trip.isBusiness ? jobsById[trip.jobId]?.clientName ?? '' : '',
              trip.isBusiness ? jobsById[trip.jobId]?.projectCode ?? '' : '',
              trip.businessDistanceKm.toStringAsFixed(2),
              (trip.distanceKm - trip.businessDistanceKm).toStringAsFixed(2),
              trip.isMixed ? 'mixed' : trip.classification.name,
              trip.review['confirmedAt'] as String? ?? '',
              trip.shareRoute
                  ? trip.review['allocationReason'] as String? ?? ''
                  : '[Private details withheld]'
            ],
          for (final expense in report.expenses)
            [
              'expense',
              expense.id,
              expense.jobId ?? tripsById[expense.linkedTripId]?.jobId ?? '',
              jobsById[expense.jobId ?? tripsById[expense.linkedTripId]?.jobId]
                      ?.name ??
                  '',
              jobsById[expense.jobId ?? tripsById[expense.linkedTripId]?.jobId]
                      ?.clientName ??
                  '',
              jobsById[expense.jobId ?? tripsById[expense.linkedTripId]?.jobId]
                      ?.projectCode ??
                  '',
              '',
              '',
              expense.receiptAudit?.reviewStatus.name ?? 'unconfirmed',
              '',
              'See receipt-allocations.csv'
            ],
        ]));
    _addText(
        archive,
        'trip-review-history.csv',
        _csv([
          [
            'Trip_ID',
            'Revision',
            'Classification',
            'Business_KM',
            'Confirmed_At',
            'Actor'
          ],
          for (final trip in report.trips)
            for (final entry in (trip.review['history'] as List? ?? []).indexed)
              [
                trip.id,
                (entry.$1 + 1).toString(),
                '${entry.$2['classification'] ?? ''}',
                '${entry.$2['businessKm'] ?? ''}',
                '${entry.$2['confirmedAt'] ?? ''}',
                '${entry.$2['actor'] ?? ''}'
              ],
        ]));

    _addText(
        archive,
        'trips.csv',
        vehicle.taxMethod == TaxMethod.centsPerKm
            ? CpkExportService.generateCpkTripLedgerCsv(
                vehicle: vehicle, trips: report.trips, taxRule: taxRule)
            : LogbookExportService.generateLogbookAuditLedgerCsv(
                vehicle: vehicle, trips: report.trips));
    final expensesCsvContent = _csv([
      [
        'Expense_ID',
        'Date',
        'Category',
        'Amount_AUD',
        'Recorded_Business_Percent',
        'Linked_Trip_ID',
        'Linked_Trip_Route',
        'Receipt_File_Status',
        'Receipt_Archive_Path',
        'Exported_SHA256',
        'Saved_SHA256',
        'Saved_Review_Status',
        'Vault_Only',
        'Vault_Reason',
        'Vehicle_Work_Subtotal_AUD',
        'Allocation_Status',
        'Merchant',
        'Currency',
        'Receipt_GST',
        'Supplier_ABN',
        'Invoice_Number',
        'Document_ID',
        'Revision',
        'Reviewed_Revision',
        'Reviewed_At',
        'Captured_At',
        'Batch_ID',
        'Engine_ID',
        'Engine_Version',
        'Parser_Version',
        'Receipt_Page_Archive_Paths'
      ],
      for (final expense in report.expenses)
        [
          expense.id,
          expense.date.toIso8601String(),
          expense.category.name,
          expense.amount.toStringAsFixed(2),
          expense.businessPercentage.toStringAsFixed(2),
          expense.linkedTripId ?? '',
          tripsById[expense.linkedTripId] == null
              ? ''
              : !tripsById[expense.linkedTripId]!.shareRoute
                  ? '[Private or unclassified journey]'
                  : '${tripsById[expense.linkedTripId]!.originAddress ?? "Not recorded"} to ${tripsById[expense.linkedTripId]!.destinationAddress ?? "Not recorded"}',
          inspections[expense.id]!.status.name,
          receiptNames[expense.id] ?? '',
          inspections[expense.id]!.sha256 ?? '',
          expense.receiptAudit?.imageSha256 ?? '',
          expense.receiptAudit?.reviewStatus.name ?? 'notRecorded',
          expense.isVaultOnly.toString(),
          expense.vaultReason ?? '',
          expense.allocatedWorkAmount.toStringAsFixed(2),
          expense.allocationError ??
              (expense.allocations
                      .any((l) => l.purpose == AllocationPurpose.unresolved)
                  ? 'unresolved items excluded'
                  : 'recorded'),
          expense.supplier ?? expense.receiptAudit?.ocrMerchant ?? '',
          expense.currency ?? '',
          expense.gstAmount?.toStringAsFixed(2) ?? '',
          expense.supplierAbn ?? '',
          expense.invoiceNumber ?? '',
          expense.id,
          expense.receiptAudit?.revision.toString() ?? '',
          expense.receiptAudit?.reviewedRevision?.toString() ?? '',
          expense.receiptAudit?.reviewedAt?.toIso8601String() ?? '',
          expense.receiptAudit?.capturedAt.toIso8601String() ?? '',
          expense.receiptAudit?.batchId ?? '',
          expense.receiptAudit?.engineId ?? '',
          expense.receiptAudit?.engineVersion ?? '',
          expense.receiptAudit?.parserVersion ?? '',
          (receiptPages[expense.id] ?? [])
              .map((p) => p['archivePath'] ?? '')
              .join(';'),
        ],
    ]);
    _addText(
        archive,
        'receipt-allocations.csv',
        _csv([
          [
            'Expense_ID',
            'Receipt_Total_AUD',
            'Item',
            'Item_Amount_AUD',
            'Item_GST_AUD',
            'Use',
            'Category',
            'Included_In_Selected_Method',
            'Receipt_Archive_Path'
          ],
          for (final e in report.expenses)
            for (final line in e.allocations)
              [
                e.id,
                e.amount.toStringAsFixed(2),
                line.description,
                line.amount.toStringAsFixed(2),
                line.gstAmount?.toStringAsFixed(2) ?? '',
                line.purpose.name,
                (line.category ?? e.category).name,
                (line.purpose == AllocationPurpose.work &&
                        (vehicle.taxMethod != TaxMethod.centsPerKm ||
                            (line.category ?? e.category)
                                .isDirectlyDeductibleByDefault) &&
                        e.allocationError == null &&
                        !e.isVaultOnly &&
                        !e.isDeleted)
                    .toString(),
                receiptNames[e.id] ?? ''
              ],
        ]));
    _addText(
        archive,
        'audit-events.json',
        const JsonEncoder.withIndent('  ').convert({
          'documents': [
            for (final expense in report.expenses)
              {
                'documentId': expense.id,
                'audit': expense.receiptAudit == null
                    ? null
                    : (Map<String, dynamic>.from(expense.receiptAudit!.toJson())
                      ..remove('rawOcrText')),
                'pages': receiptPages[expense.id] ?? [],
              }
          ],
        }));
    _addText(archive, 'expenses.csv', expensesCsvContent);
    _addText(archive, '04_Cryptographic_Receipt_Index.csv', expensesCsvContent);
    _addText(
        archive,
        'record-sources.csv',
        _csv([
          [
            'Record_Type',
            'Record_ID',
            'Date',
            'Classification',
            'Recorded_Method',
            'Evidence_Source',
            'Trip_Ledger_Data_Row'
          ],
          for (final trip in report.trips)
            [
              'trip',
              trip.id,
              trip.date.toIso8601String(),
              trip.classification.name,
              trip.taxMethod.name,
              trip.evidenceSource,
              ledgerRows[trip.id]?.toString() ?? ''
            ],
        ]));
    _addText(
        archive,
        'review-issues.csv',
        _csv([
          ['Record_Type', 'Record_ID', 'Review_Issue'],
          ...issues,
        ]));
    _addText(
        archive,
        'README.txt',
        'KiloTax recorded vehicle evidence package\n'
            'Vehicle: ${vehicle.regoPlate}\nFinancial year: ${taxRule.financialYear}\n'
            'Method: ${vehicle.taxMethod.name}\n'
            'Status: ${issues.isEmpty ? "No outstanding application record checks" : "Draft, review required"}\n'
            'Receipt files: $receiptCount of ${report.expenses.length} expense records.\n'
            'Pending receipt drafts excluded from totals: $pendingDraftCount\n'
            'Review items: ${issues.length}\n\n'
            'A readable file means the application read nonempty bytes. It does not establish image legibility, authenticity, expense accuracy, or tax eligibility. '
            'Saved review status is historical metadata. A matching hash only establishes equality with the saved fingerprint.\n'
            'Missing receipt files are not embedded. Remote receipt references are not downloaded during export. Restore receipts to this device and export again if needed.\n'
            'The PDF calculation uses recorded data and is subject to review. Vault-only expenses are excluded from the calculation. '
            'For cents-per-kilometre, attached expenses are records and do not increase the distance-based calculation. '
            'Uncapped_Trip_Value_AUD in trips.csv is the uncapped value of each trip. The PDF total applies the kilometre cap.\n'
            'Trip_Ledger_Data_Row in record-sources.csv is the one-based data row in trips.csv, excluding its header. A blank value means the record is not included in that method-specific ledger. '
            'Private and unclassified route addresses and purposes are masked in the trip ledger. '
            'Receipt images retain their original content, which may include personal information. Review before sharing.\n'
            'This package is an accountant handoff, not a restorable application backup. No email delivery is established by preparing or sharing it.\n');
    _addText(
        archive,
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert({
          'format': 'KiloTax_Tax_Pack_v1',
          'generatedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
          'vehicleId': vehicle.id,
          'financialYear': taxRule.financialYear,
          'method': vehicle.taxMethod.name,
          'tripCount': report.trips.length,
          'expenseCount': report.expenses.length,
          'receiptCount': receiptCount,
          'pendingDraftCount': pendingDraftCount,
          'receiptDocuments': receiptPages,
          'reviewItemCount': issues.length,
          'status': issues.isEmpty ? 'recordChecksComplete' : 'draft',
          'files': [...archive.files.map((file) => file.name), 'manifest.json'],
        }));
    final directory = await outputDirectory.createTemp('kilotax-pack-');
    try {
      final name = ExportFileNameHelper.buildFileName(
        method: vehicle.taxMethod == TaxMethod.centsPerKm ? 'CPK' : 'Logbook',
        fy: taxRule.financialYear,
        taxpayerName: 'Evidence',
        rego: vehicle.regoPlate,
        documentType: 'Tax_Pack',
        extension: 'zip',
      );
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(await compute(_encodeZip, archive), flush: true);
      return TaxPackArtifact(
          directory: directory,
          file: file,
          report: report,
          receiptCount: receiptCount,
          issueCount: issues.length);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  static void _addText(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static String _csv(List<List<String>> rows) =>
      '${rows.map((row) => row.map(CsvSecurity.quoteCell).join(',')).join('\r\n')}\r\n';

  static String _extension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'webp';
    }
    if (bytes.length >= 5 &&
        ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-') {
      return 'pdf';
    }
    return 'bin';
  }
}

List<int> _encodeZip(Archive archive) => ZipEncoder().encode(archive);

Future<List<int>> _renderPdf(
        ({
          Vehicle vehicle,
          AtoTaxRule taxRule,
          List<Trip> trips,
          TaxSummary summary,
          ByteData regular,
          ByteData bold,
        }) input) =>
    PdfExportService.generateBoxD1SummaryPdf(
      vehicle: input.vehicle,
      trips: input.trips,
      summary: input.summary,
      taxRule: input.taxRule,
      regularFont: input.regular,
      boldFont: input.bold,
    );
