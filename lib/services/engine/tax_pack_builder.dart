import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/export_file_name_helper.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/job_site.dart';
import '../../data/models/annual_odometer.dart';
import '../../data/models/logbook_period.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';
import 'tax_pack_documents.dart';
import 'evidence_review_service.dart';
import 'tax_calculator_service.dart';
import 'receipt_export_resolver.dart';

class TaxPackArtifact {
  final Directory directory;
  final File file;
  final EvidenceReviewReport report;
  final int receiptCount;
  final int issueCount;
  final List<List<String>> reviewGroups;

  File get reportFile => File('${directory.path}/Report.pdf');

  const TaxPackArtifact({
    required this.directory,
    required this.file,
    required this.report,
    required this.receiptCount,
    required this.issueCount,
    this.reviewGroups = const [],
  });

  String get description =>
      'Vehicle ${report.vehicle!.regoPlate}, FY${report.financialYear}. '
      'Open Report.pdf for the overview and Details.xlsx for trips, expenses and review items. ZIP includes '
      '$receiptCount receipt files, and $issueCount review groups. '
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
    UserProfile profile = const UserProfile(),
    List<AnnualVehicleOdometer> annualOdometers = const [],
    List<LogbookPeriod> logbookPeriods = const [],
    ReceiptExportResolver? receiptResolver,
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
    for (final entry in receiptExpenses.indexed) {
      final expense = entry.$2;
      final document =
          await (receiptResolver ?? ReceiptExportResolver()).resolve(expense);
      if (document.issue != null) {
        extraIssues.add(['expense', expense.id, document.issue!]);
      }
      final pages = <Map<String, dynamic>>[];
      var missing = document.pages.isEmpty;
      var changed = false;
      String? firstDigest;
      for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++) {
        final resolved = document.pages[pageIndex];
        final bytes = resolved.bytes;
        final savedDigest = resolved.savedSha256;
        if (bytes == null || bytes.isEmpty) {
          missing = true;
          pages.add({
            'page': pageIndex + 1,
            'status': 'missing',
            'savedSha256': savedDigest,
            'source': resolved.source,
          });
          extraIssues.add([
            'expense',
            expense.id,
            'Receipt page ${pageIndex + 1} is unavailable.'
                '${resolved.issue == null ? '' : ' ${resolved.issue}'}'
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
            'Receipts/R${(entry.$1 + 1).toString().padLeft(6, '0')}_p${(pageIndex + 1).toString().padLeft(2, '0')}.$extension';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
        pages.add({
          'page': pageIndex + 1,
          'archivePath': name,
          'sha256': digest,
          'savedSha256': savedDigest,
          'status': pageChanged ? 'changed' : 'available',
          'source': resolved.source
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
    final documents = TaxPackDocuments(
      report: report,
      summary: summary,
      taxRule: taxRule,
      profile: profile,
      jobs: jobs,
      inspections: inspections,
      receiptPages: receiptPages,
      issues: issues,
      generatedAt: generatedAt ?? DateTime.now(),
      pendingDraftCount: pendingDraftCount,
      annualOdometers: annualOdometers,
      logbookPeriods: logbookPeriods,
    );
    issues.addAll(documents.contextReviewItems);
    final workbook = documents.buildWorkbook();
    archive.addFile(ArchiveFile('Details.xlsx', workbook.length, workbook));
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    final pdf = await compute(renderTaxPackPdf,
        (data: documents.pdfData, regular: regular, bold: bold));
    archive.addFile(ArchiveFile('Report.pdf', pdf.length, pdf));
    final metadata = documents.buildMetadata();
    metadata['files'] = [
      ...archive.files.map((file) => file.name),
      'Supporting/record-history.json'
    ];
    final metadataBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(metadata));
    archive.addFile(ArchiveFile(
        'Supporting/record-history.json', metadataBytes.length, metadataBytes));
    final directory = await outputDirectory.createTemp('kilotax-pack-');
    try {
      final name = ExportFileNameHelper.buildFileName(
        method: switch (vehicle.taxMethod) {
          TaxMethod.centsPerKm => 'CPK',
          TaxMethod.logbook => 'Logbook',
          TaxMethod.actualExpenses => 'Actuals'
        },
        fy: taxRule.financialYear,
        taxpayerName: 'Evidence',
        rego: vehicle.regoPlate,
        documentType: 'Tax_Pack',
        extension: 'zip',
      );
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(await compute(_encodeZip, archive), flush: true);
      await File('${directory.path}/Report.pdf').writeAsBytes(pdf, flush: true);
      return TaxPackArtifact(
          directory: directory,
          file: file,
          report: report,
          receiptCount: receiptCount,
          issueCount: documents.reviewGroups.length,
          reviewGroups: List.unmodifiable(documents.reviewGroups
              .map((row) => List<String>.unmodifiable(row))));
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

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
