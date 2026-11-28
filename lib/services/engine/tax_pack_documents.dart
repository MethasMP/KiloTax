import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_constants.dart';
import '../../data/models/annual_odometer.dart';
import '../../data/models/job_site.dart';
import '../../data/models/logbook_period.dart';
import '../../data/models/tax_summary.dart';
import '../../data/models/trip.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';
import 'evidence_review_service.dart';
import 'openxml_workbook_builder.dart';
import 'tax_pack_analysis.dart';

class TaxPackDocuments {
  final EvidenceReviewReport report;
  final TaxSummary summary;
  final AtoTaxRule taxRule;
  final UserProfile profile;
  final List<JobSite> jobs;
  final Map<String, ReceiptFileInspection> inspections;
  final Map<String, List<Map<String, dynamic>>> receiptPages;
  final List<List<String>> issues;
  final DateTime generatedAt;
  final int pendingDraftCount;
  final List<AnnualVehicleOdometer> annualOdometers;
  final List<LogbookPeriod> logbookPeriods;

  TaxPackDocuments({
    required this.report,
    required this.summary,
    required this.taxRule,
    required this.profile,
    required this.jobs,
    required this.inspections,
    required this.receiptPages,
    required this.issues,
    required this.generatedAt,
    required this.pendingDraftCount,
    required this.annualOdometers,
    required this.logbookPeriods,
  });

  static const scope =
      'Vehicle trips, recorded expenses and saved receipt files only. '
      'Purchase and finance documents, depreciation schedules, GST adjustments '
      'and final tax treatment are outside this report. Taxpayer type and method eligibility are not assessed.';
  static const evidenceNote =
      'Receipt files are included as recorded; check that all pages are legible. '
      'Files are collected from this device or, when available, authenticated private storage. Unavailable files are listed in Review. '
      'Keep source evidence for the applicable retention period; this ZIP is not a restorable application backup.';
  static const calculationNote =
      'Workbook scenario only, not an adopted annual percentage or final deduction. '
      'The observed ratio uses saved financial-year trips. The appropriate annual business-use estimate '
      'may consider logbooks, odometers, changes in use and other records. Neither the observed ratio '
      'nor a stored logbook percentage is automatically adopted by this export.';

  Vehicle get vehicle => report.vehicle!;
  bool get isCpk => vehicle.taxMethod == TaxMethod.centsPerKm;
  bool get isLogbook => vehicle.taxMethod == TaxMethod.logbook;
  String get method => switch (vehicle.taxMethod) {
        TaxMethod.centsPerKm => 'Cents per kilometre',
        TaxMethod.logbook => 'Logbook',
        TaxMethod.actualExpenses => 'Actual expenses',
      };
  TaxPackAnalysis get analysis =>
      TaxPackAnalysis(report, inspections, receiptPages);
  List<AnnualOdometerComparison> get annualComparisons => [
        for (final record in scopedOdometers)
          AnnualOdometerComparison(record, report.trips)
      ];
  String get status => issues.isEmpty
      ? 'Prepared for accountant review'
      : 'Draft - ${reviewGroups.length} review groups';
  String get packId =>
      '${vehicle.id}-${taxRule.financialYear}-${generatedAt.toUtc().microsecondsSinceEpoch}';
  int get receiptCount => receiptPages.values
      .expand((pages) => pages)
      .where((page) => page['archivePath'] != null)
      .length;
  int get documentsWithFiles => receiptPages.values
      .where((pages) => pages.any((page) => page['archivePath'] != null))
      .length;
  List<AnnualVehicleOdometer> get scopedOdometers => annualOdometers
      .where((record) =>
          record.vehicleId == vehicle.id &&
          _startYear(record.financialYear) == _startYear(taxRule.financialYear))
      .toList()
    ..sort((a, b) => a.openingDate.compareTo(b.openingDate));
  List<LogbookPeriod> get scopedPeriods => logbookPeriods
      .where((period) =>
          period.vehicleId == vehicle.id &&
          _startYear(period.establishedFinancialYear) <=
              _startYear(taxRule.financialYear) &&
          _startYear(period.validUntilFinancialYear) >=
              _startYear(taxRule.financialYear))
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  static int _startYear(String value) {
    final full = RegExp(r'\d{4}').firstMatch(value);
    if (full != null) return int.parse(full.group(0)!);
    final short = RegExp(r'\d{2}').firstMatch(value);
    return short == null ? -1 : 2000 + int.parse(short.group(0)!) - 1;
  }

  String _tripRef(Trip trip) =>
      'T${(report.trips.indexOf(trip) + 1).toString().padLeft(6, '0')}';
  String _receiptRef(VehicleExpense expense) =>
      'R${(report.expenses.indexOf(expense) + 1).toString().padLeft(6, '0')}';
  String _paths(VehicleExpense expense) => (receiptPages[expense.id] ?? [])
      .map((page) => page['archivePath'])
      .whereType<String>()
      .join('; ');
  ExcelCell _receiptLink(VehicleExpense expense) {
    final paths = (receiptPages[expense.id] ?? [])
        .map((page) => page['archivePath'])
        .whereType<String>()
        .toList();
    return paths.isEmpty
        ? const ExcelCell.text('')
        : ExcelCell.link(_paths(expense), paths.first);
  }

  String _jobName(String? id) =>
      jobs.where((job) => job.id == id).firstOrNull?.name ?? '';
  String _jobClient(String? id) =>
      jobs.where((job) => job.id == id).firstOrNull?.clientName ?? '';
  String _jobReference(String? id) =>
      jobs.where((job) => job.id == id).firstOrNull?.projectCode ?? '';
  String _date(DateTime? date) => date?.toIso8601String() ?? 'Not recorded';

  List<List<String>> get contextReviewItems => [
        if (isLogbook && scopedOdometers.isEmpty)
          [
            'setup',
            '',
            'No annual odometer record is saved for this vehicle/year. Trip readings do not establish annual opening and closing readings.'
          ],
        for (final comparison in annualComparisons)
          if (comparison.problem != null)
            ['odometer', comparison.record.id, comparison.problem!]
          else if (comparison.differenceKm!.abs() > 0.01)
            [
              'odometer',
              comparison.record.id,
              'Odometer movement minus trips dated within saved boundaries is ${comparison.differenceKm!.toStringAsFixed(2)} km. Reconcile dates and records; the difference is not classified as private use.'
            ],
        for (var index = 0; index < annualComparisons.length; index++)
          for (var other = index + 1; other < annualComparisons.length; other++)
            if (annualComparisons[index].overlaps(annualComparisons[other]))
              [
                'odometer',
                annualComparisons[index].record.id,
                'Saved annual odometer dates overlap another record. Comparisons are separate and must not be added together.'
              ],
        if (isLogbook && scopedPeriods.isEmpty)
          [
            'setup',
            '',
            'No saved logbook period covers this financial year. This export does not establish a representative logbook.'
          ],
        if (isLogbook)
          for (final period in scopedPeriods)
            if (period.status != LogbookStatus.certifiedValid ||
                period.endOdometer == null ||
                period.certifiedBusinessPercentage == null ||
                !period.startOdometer.isFinite ||
                !period.endOdometer!.isFinite ||
                period.endOdometer! < period.startOdometer ||
                period.endDate.isBefore(period.startDate) ||
                !period.certifiedBusinessPercentage!.isFinite ||
                period.certifiedBusinessPercentage! < 0 ||
                period.certifiedBusinessPercentage! > 100)
              [
                'logbook',
                period.id,
                'Saved logbook period requires review. A stored date range or app status alone does not establish representative use.'
              ],
        for (final expense in report.expenses)
          if (!analysis.usableAud(expense))
            [
              'expense',
              expense.id,
              'Currency or amount requires review; this record is outside AUD totals. No currency conversion is made.'
            ],
      ];

  double? _contribution(VehicleExpense expense) => isCpk
      ? 0
      : !isLogbook || !analysis.canIllustrateCosts
          ? null
          : expense.claimComponents.fold<double>(
              0,
              (sum, component) =>
                  sum +
                  component.calculateClaimWithLogbookRate(
                      summary.businessPercentage));

  String? _expenseJob(VehicleExpense expense, Map<String, Trip> trips) =>
      expense.jobId ??
      (trips[expense.linkedTripId]?.isBusiness == true
          ? trips[expense.linkedTripId]?.jobId
          : null);

  String _shortDate(DateTime? date) => date == null
      ? 'Not recorded'
      : '${date.day.toString().padLeft(2, '0')} ${const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ][date.month - 1]} ${date.year}';
  String _dateRange(Iterable<DateTime> dates) {
    final values = dates.toList()..sort();
    return values.isEmpty
        ? 'None recorded'
        : '${_shortDate(values.first)} to ${_shortDate(values.last)}';
  }

  String get reportingWindow =>
      '${_shortDate(DateTime(_startYear(taxRule.financialYear), 7, 1))} to ${_shortDate(DateTime(_startYear(taxRule.financialYear) + 1, 6, 30))}';

  List<List<String>> get reviewGroups {
    final groups = <String, List<List<String>>>{};
    for (final issue in issues) {
      final key = issue[1].isEmpty
          ? '${issue[0]}:${issue[2]}'
          : '${issue[0]}:${issue[1]}';
      groups.putIfAbsent(key, () => []).add(issue);
    }
    final entries = groups.values.toList();
    int priority(String type) => switch (type) {
          'setup' => 0,
          'odometer' => 1,
          'logbook' => 2,
          'trip' => 3,
          'expense' => 4,
          _ => 5
        };
    entries
        .sort((a, b) => priority(a.first[0]).compareTo(priority(b.first[0])));
    return [
      for (final group in entries)
        [
          _reviewLabel(group.first),
          group
              .map((item) => item[2])
              .toSet()
              .where((reason) => !(reason == 'Receipt file is unavailable' &&
                  group.any((item) => item[2].startsWith('Receipt page '))))
              .join(' '),
        ]
    ];
  }

  String _reviewLabel(List<String> issue) {
    final expense =
        report.expenses.where((item) => item.id == issue[1]).firstOrNull;
    if (issue[0] == 'expense' && expense != null) {
      return '${_receiptRef(expense)} | ${_shortDate(expense.date)}';
    }
    final trip = report.trips.where((item) => item.id == issue[1]).firstOrNull;
    if (issue[0] == 'trip' && trip != null) {
      return '${_tripRef(trip)} | ${_shortDate(trip.date)}';
    }
    final annualIndex =
        scopedOdometers.indexWhere((item) => item.id == issue[1]);
    if (issue[0] == 'odometer' && annualIndex >= 0) {
      return 'Odometer A${annualIndex + 1}';
    }
    final logbookIndex =
        scopedPeriods.indexWhere((item) => item.id == issue[1]);
    if (issue[0] == 'logbook' && logbookIndex >= 0) {
      return 'Logbook L${logbookIndex + 1}';
    }
    return issue[0] == 'setup' ? 'Record basis' : issue[0];
  }

  List<List<Object?>> get overviewRows => [
        [
          'Taxpayer',
          profile.taxpayerName?.trim().isNotEmpty == true
              ? profile.taxpayerName
              : 'Not provided'
        ],
        [
          'ABN (if applicable)',
          profile.abn?.trim().isNotEmpty == true ? profile.abn : 'Not provided'
        ],
        ['Vehicle', '${vehicle.make} ${vehicle.model} (${vehicle.regoPlate})'],
        ['Engine capacity', vehicle.engineCapacity ?? 'Not recorded'],
        ['Financial year', taxRule.financialYear],
        ['Selected method', method],
        ['Status', status],
        ['Generated at', generatedAt.toIso8601String()],
        ['Pack ID', packId],
        ['Trips recorded', report.trips.length],
        ['Total recorded km', summary.totalKm],
        ['Business km', summary.businessKm],
        ['Private or undecided km', summary.personalKm],
        ['Known private km', analysis.privateKm],
        ['Undecided km', analysis.undecidedKm],
        ['Recorded business ratio (%)', summary.businessPercentage],
        ['Expense records (including vault)', report.expenses.length],
        ['Receipt documents with files', documentsWithFiles],
        ['Receipt pages included', receiptCount],
        ['Pending receipt drafts excluded', pendingDraftCount],
        ['Review items', issues.length],
        ['Review groups', reviewGroups.length],
        ['Reporting window', reportingWindow],
        ['Saved trip dates', _dateRange(report.trips.map((trip) => trip.date))],
        [
          'Saved expense dates',
          _dateRange(report.expenses.map((expense) => expense.date))
        ],
        ['Adopted annual business-use estimate', 'Not adopted in this export'],
      ];

  List<List<Object?>> get calculationRows => [
        if (isCpk) ...[
          ['Rate (AUD per km)', taxRule.centsPerKmRate],
          ['Business km cap', taxRule.centsPerKmMaxKm],
          [
            'Capped business km',
            math.min(summary.businessKm, taxRule.centsPerKmMaxKm)
          ],
          ['Recorded distance-based estimate (AUD)', summary.centsPerKmClaim],
          [
            'Expense treatment',
            'Saved expenses do not increase the distance-based estimate. Separate expense treatment is for accountant review.'
          ],
        ] else if (isLogbook && analysis.canIllustrateCosts) ...[
          [
            'Recorded running-cost subtotal (AUD)',
            summary.totalRunningExpenses
          ],
          ['Recorded direct-cost portion (AUD)', summary.totalDirectDeductions],
          ['Illustrative recorded-data estimate (AUD)', summary.logbookClaim],
          [
            'Formula',
            'Recorded running costs x recorded-year business ratio + recorded direct-cost portion'
          ],
        ],
        if (!isCpk && (!isLogbook || !analysis.canIllustrateCosts))
          [
            'Cost illustration',
            isLogbook
                ? 'Not calculated: non-AUD or invalid active costs require review.'
                : 'Not calculated: actual-expense treatment is for accountant review.'
          ],
        [
          'Calculation basis',
          isCpk
              ? 'Recorded business kilometres capped at the selected-year limit, multiplied by the selected-year rate. Eligibility is not determined.'
              : calculationNote
        ],
      ];

  Map<String, List<List<Object?>>> get tables {
    final tripsById = {for (final trip in report.trips) trip.id: trip};
    final result = <String, List<List<Object?>>>{
      'Summary': [
        ['Field', 'Recorded value'],
        [
          'Start here',
          'Read Report.pdf first. Use Trips and Expenses for detail; Receipt items for split receipts; Review for outstanding items. Receipt references match files in Receipts/. File links open the first saved page; all included page filenames are listed. Extract the ZIP before opening links.'
        ],
        ...overviewRows,
        ...calculationRows,
        ['Scope', scope],
        ['Receipt evidence', evidenceNote],
        [
          'Privacy',
          'Private and mixed route addresses are withheld. Original receipt images may contain personal information.'
        ],
        [
          'Record history',
          'Supporting/record-history.json holds receipt fingerprints, extraction metadata and saved corrections. It is not required for routine review.'
        ],
      ],
      'Trips': [
        [
          'Trip ref',
          'Trip ID',
          'Date and time',
          'Recorded method',
          'Classification',
          'Total km',
          'Business km',
          'Private or undecided km',
          'Odometer start (recorded)',
          'Odometer end (recorded)',
          'Origin',
          'Destination',
          'Recorded business purpose',
          'Evidence source',
          'Job ID',
          'Job name',
          'Client',
          'Project reference',
          'Confirmed at',
          'Allocation basis',
          'Passenger unverified'
        ],
        for (final trip in report.trips)
          [
            _tripRef(trip),
            trip.id,
            trip.date.toIso8601String(),
            trip.taxMethod.name,
            trip.isMixed ? 'MIXED' : trip.classification.name,
            trip.distanceKm,
            trip.businessDistanceKm,
            trip.distanceKm - trip.businessDistanceKm,
            trip.startOdometer > 0 ? trip.startOdometer : null,
            trip.endOdometer > 0 ? trip.endOdometer : null,
            trip.shareRoute
                ? trip.originAddress ?? 'Not recorded'
                : '[Private Journey]',
            trip.shareRoute
                ? trip.destinationAddress ?? 'Not recorded'
                : '[Private Journey]',
            trip.isBusiness
                ? trip.purpose
                : trip.classification == TripClassification.personal
                    ? 'Personal travel'
                    : 'Unclassified',
            trip.evidenceSource,
            trip.isBusiness ? trip.jobId : null,
            trip.isBusiness
                ? _jobName(trip.jobId).isNotEmpty
                    ? _jobName(trip.jobId)
                    : trip.jobReference
                : null,
            trip.isBusiness ? _jobClient(trip.jobId) : null,
            trip.isBusiness ? _jobReference(trip.jobId) : null,
            trip.review['confirmedAt'],
            trip.shareRoute
                ? trip.review['allocationReason']
                : '[Private details withheld]',
            trip.isPassengerUnverified.toString()
          ],
      ],
      'Expenses': [
        [
          'Receipt ref',
          'Expense ID',
          'Date',
          'Merchant',
          'Category',
          'Receipt total',
          'Currency (recorded)',
          'GST (recorded, not a credit)',
          'Supplier ABN',
          'Invoice number',
          'Recorded business %',
          'Work allocation subtotal',
          'Recorded method estimate contribution (AUD)',
          'Allocation status',
          'Vault only',
          'Vault reason',
          'Linked trip ID',
          'Linked trip route',
          'Job ID',
          'Job name',
          'Client',
          'Project reference',
          'Receipt file status',
          'Receipt page files',
          'Saved review status',
          'Revision',
          'Reviewed revision',
          'Reviewed at'
        ],
        for (final expense in report.expenses)
          [
            _receiptRef(expense),
            expense.id,
            expense.date.toIso8601String(),
            expense.supplier ?? expense.receiptAudit?.ocrMerchant ?? '',
            expense.category.displayName,
            expense.amount,
            expense.currency,
            expense.gstAmount,
            expense.supplierAbn,
            expense.invoiceNumber,
            expense.businessPercentage,
            expense.allocatedWorkAmount,
            _contribution(expense),
            expense.allocationError ??
                (expense.allocations.any(
                        (line) => line.purpose == AllocationPurpose.unresolved)
                    ? 'Unresolved items excluded'
                    : 'Recorded'),
            expense.isVaultOnly.toString(),
            expense.vaultReason,
            expense.linkedTripId,
            tripsById[expense.linkedTripId] == null
                ? ''
                : !tripsById[expense.linkedTripId]!.shareRoute
                    ? '[Private or unclassified journey]'
                    : '${tripsById[expense.linkedTripId]!.originAddress ?? "Not recorded"} to ${tripsById[expense.linkedTripId]!.destinationAddress ?? "Not recorded"}',
            _expenseJob(expense, tripsById),
            _jobName(_expenseJob(expense, tripsById)),
            _jobClient(_expenseJob(expense, tripsById)),
            _jobReference(_expenseJob(expense, tripsById)),
            inspections[expense.id]?.status.name ?? 'unknown',
            _receiptLink(expense),
            expense.receiptAudit?.reviewStatus.name ?? 'notRecorded',
            expense.receiptAudit?.revision,
            expense.receiptAudit?.reviewedRevision,
            expense.receiptAudit?.reviewedAt?.toIso8601String(),
          ],
      ],
      'Receipt items': [
        [
          'Receipt ref',
          'Expense ID',
          'Receipt total',
          'Item',
          'Item amount',
          'Item GST (recorded)',
          'Use',
          'Category',
          'Included in recorded estimate',
          'Receipt page files'
        ],
        for (final expense in report.expenses)
          for (final line in expense.allocations)
            [
              _receiptRef(expense),
              expense.id,
              expense.amount,
              line.description,
              line.amount,
              line.gstAmount,
              line.purpose.name,
              (line.category ?? expense.category).displayName,
              (isLogbook &&
                      analysis.canIllustrateCosts &&
                      line.purpose == AllocationPurpose.work &&
                      expense.allocationError == null &&
                      !expense.isVaultOnly &&
                      !expense.isDeleted)
                  .toString(),
              _receiptLink(expense)
            ],
      ],
      'Review': [
        ['Record type', 'Record ID', 'Review item'],
        ...issues,
      ],
    };
    if (isLogbook || scopedOdometers.isNotEmpty || scopedPeriods.isNotEmpty) {
      result['Logbook records'] = [
        [
          'Record type',
          'Record ID',
          'Financial year',
          'Start date',
          'End date',
          'Opening odometer',
          'Closing odometer',
          'Recorded km',
          'Stored business %',
          'Stored status',
          'Established year',
          'Stored valid-until year',
          'Confirmed at',
          'Reference'
        ],
        for (final record in scopedOdometers)
          [
            'Annual odometer',
            record.id,
            record.financialYear,
            _date(record.openingDate),
            _date(record.closingDate),
            record.openingOdometer,
            record.closingOdometer,
            record.totalAnnualKm,
            null,
            'Recorded',
            null,
            null,
            null,
            'A${scopedOdometers.indexOf(record) + 1}'
          ],
        for (final period in scopedPeriods)
          [
            'Logbook period',
            period.id,
            taxRule.financialYear,
            _date(period.startDate),
            _date(period.endDate),
            period.startOdometer,
            period.endOdometer,
            period.endOdometer == null
                ? null
                : period.endOdometer! - period.startOdometer,
            period.certifiedBusinessPercentage,
            period.status.name,
            period.establishedFinancialYear,
            period.validUntilFinancialYear,
            _date(period.certifiedAt),
            'L${scopedPeriods.indexOf(period) + 1}'
          ],
      ];
    }
    result['Expense summary'] = [
      ['Category', 'Recorded AUD', 'Recorded basis AUD', 'Source gap AUD'],
      ...expenseCategoryRows,
    ];
    if (annualComparisons.isNotEmpty) {
      result['Odometer comparison'] = [
        [
          'Comparison ref',
          'Record ID',
          'Opening date',
          'Closing date',
          'Odometer movement km',
          'Matched trip km',
          'Difference km',
          'Comparison status'
        ],
        for (final entry in annualComparisons.indexed)
          [
            'A${entry.$1 + 1}',
            entry.$2.record.id,
            _date(entry.$2.record.openingDate),
            _date(entry.$2.record.closingDate),
            entry.$2.odometerKm,
            entry.$2.recordedKm,
            entry.$2.differenceKm,
            entry.$2.problem ??
                'Compare recorded dates; difference is not private use'
          ],
      ];
    }
    final history = <List<Object?>>[
      [
        'Trip ID',
        'Revision',
        'Classification',
        'Business km',
        'Confirmed at',
        'Actor'
      ],
      for (final trip in report.trips)
        for (final entry in (trip.review['history'] as List? ?? []).indexed)
          if (entry.$2 is Map)
            [
              trip.id,
              entry.$1 + 1,
              entry.$2['classification'],
              entry.$2['businessKm'],
              entry.$2['confirmedAt'],
              entry.$2['actor']
            ],
    ];
    if (history.length > 1) result['Trip changes'] = history;
    return result;
  }

  Uint8List buildWorkbook() {
    final workbook = OpenXmlWorkbookBuilder();
    for (final table in tables.entries) {
      final sheet = workbook.addSheet(table.key, tabular: true);
      for (final row in table.value) {
        sheet.addRow([
          for (final cell in row)
            cell is ExcelCell
                ? cell
                : cell is num && cell.isFinite
                    ? ExcelCell.number(cell, decimal: cell is double)
                    : ExcelCell.text(cell?.toString() ?? '')
        ]);
      }
    }
    return workbook.buildBytes();
  }

  List<List<Object?>> get expenseCategoryRows => [
        for (final row in analysis.categories)
          [row.category.displayName, row.gross, row.basis, row.evidenceGap],
      ];

  List<List<Object?>> get expenseReconciliationRows => [
        ['Recorded receipt totals (AUD)', analysis.grossAud],
        ['Less: stored separately / vault (AUD)', analysis.vaultAud],
        [
          'Less: private, unresolved or invalid allocation portions (AUD)',
          analysis.excludedAllocationAud
        ],
        [
          'Recorded running-cost base, before annual-use % (AUD)',
          analysis.runningBasis
        ],
        ['Recorded direct-cost portion (AUD)', analysis.directBasis],
        [
          'AUD basis total (not a deduction)',
          analysis.runningBasis + analysis.directBasis
        ],
      ];

  Map<String, Object?> get pdfData => {
        'packId': packId,
        'status': status,
        'identity': [
          [
            'Taxpayer / ABN',
            '${profile.taxpayerName ?? 'Not provided'} | ${profile.abn ?? 'ABN not provided (if applicable)'}'
          ],
          [
            'Vehicle',
            '${vehicle.make} ${vehicle.model} | ${vehicle.regoPlate}'
          ],
          ['Selected method', '$method | eligibility not assessed'],
          ['Reporting year', '${taxRule.financialYear} | $reportingWindow'],
          [
            'As of / saved trip dates',
            '${_shortDate(generatedAt)} | ${_dateRange(report.trips.map((trip) => trip.date))}'
          ],
          [
            'Saved expense dates',
            _dateRange(report.expenses.map((expense) => expense.date))
          ],
          [
            'Vehicle details (recorded)',
            'Engine ${vehicle.engineCapacity ?? 'not recorded'} | Payload ${vehicle.payloadKg?.toStringAsFixed(0) ?? 'not recorded'} kg | Seats ${vehicle.seatingCapacity ?? 'not recorded'}'
          ],
        ],
        'distance': [
          ['Total saved trip km', summary.totalKm],
          [
            'Business / known private / undecided km',
            '${summary.businessKm.toStringAsFixed(2)} / ${analysis.privateKm.toStringAsFixed(2)} / ${analysis.undecidedKm.toStringAsFixed(2)}'
          ],
          [
            'Observed business share of saved trips (%)',
            summary.businessPercentage
          ],
        ],
        'annual': [
          for (final entry in annualComparisons.indexed)
            [
              'A${entry.$1 + 1} | ${_shortDate(entry.$2.record.openingDate)}\nto ${_shortDate(entry.$2.record.closingDate)}',
              entry.$2.record.openingOdometer.isFinite
                  ? entry.$2.record.openingOdometer
                  : 'Invalid',
              entry.$2.record.closingOdometer?.isFinite == true
                  ? entry.$2.record.closingOdometer
                  : 'Not recorded / invalid',
              entry.$2.odometerKm,
              entry.$2.recordedKm,
              entry.$2.differenceKm,
            ]
        ],
        'periods': [
          for (final period in scopedPeriods)
            [
              'L${scopedPeriods.indexOf(period) + 1} | ${_shortDate(period.startDate)} to ${_shortDate(period.endDate)}\n${period.endDate.difference(period.startDate).inDays} elapsed days (saved dates)',
              '${period.startOdometer.toStringAsFixed(2)} / ${period.endOdometer?.toStringAsFixed(2) ?? 'Not recorded'}',
              period.certifiedBusinessPercentage?.isFinite == true
                  ? period.certifiedBusinessPercentage
                  : 'Not recorded / invalid',
              switch (period.status) {
                LogbookStatus.certifiedValid => 'App marked complete',
                LogbookStatus.completedPendingReview => 'Pending review',
                LogbookStatus.inProgress => 'In progress',
                LogbookStatus.notStarted => 'Not started',
                LogbookStatus.invalidated => 'Invalidated',
                LogbookStatus.expired5Years => 'Expired in app',
              },
            ]
        ],
        'isLogbook': isLogbook,
        'isCpk': isCpk,
        'calculation': isCpk
            ? calculationRows
            : [
                [
                  'Adopted annual business-use estimate',
                  'Not adopted in this export'
                ],
                ['Deduction amount', 'Not determined in this evidence pack'],
              ],
        'expenseCategories': expenseCategoryRows,
        'expenseReconciliation': expenseReconciliationRows,
        'evidence': [
          [
            'All saved files present / total records',
            '${analysis.completeDocumentCount} / ${report.expenses.length}'
          ],
          [
            'AUD receipts: all saved files present / source gap',
            '${analysis.completeDocumentAud.toStringAsFixed(2)} / ${analysis.evidenceGapAud.toStringAsFixed(2)}'
          ],
          [
            'Receipt pages included / pending drafts excluded',
            '$receiptCount / $pendingDraftCount'
          ],
          [
            'Records outside AUD totals (no conversion)',
            analysis.outsideAudCount
          ],
        ],
        'reviewGroups': reviewGroups,
        'rawCheckCount': issues.length,
        'scope': scope,
        'evidenceNote': evidenceNote,
      };

  Map<String, Object?> buildMetadata() => {
        'format': 'KiloClaim_Tax_Pack_v2',
        'packId': packId,
        'generatedAt': generatedAt.toIso8601String(),
        'vehicleId': vehicle.id,
        'financialYear': taxRule.financialYear,
        'method': vehicle.taxMethod.name,
        'tripCount': report.trips.length,
        'expenseCount': report.expenses.length,
        'receiptCount': receiptCount,
        'pendingDraftCount': pendingDraftCount,
        'reviewItemCount': issues.length,
        'reviewGroupCount': reviewGroups.length,
        'status': issues.isEmpty ? 'preparedForReview' : 'draft',
        'receiptDocuments': receiptPages,
        'documents': [
          for (final expense in report.expenses)
            {
              'documentId': expense.id,
              'receiptRef': _receiptRef(expense),
              'audit': _safeAudit(expense.receiptAudit),
              'pages': receiptPages[expense.id] ?? []
            },
        ],
      };

  static Map<String, Object?>? _safeAudit(ReceiptAuditTrail? audit) {
    if (audit == null) return null;
    const fields = {
      'date',
      'amount',
      'gstAmount',
      'supplier',
      'merchant',
      'abn',
      'imageSha256',
      'currency',
      'supplierAbn',
      'invoiceNumber',
      'category',
      'businessPercentage'
    };
    final json = audit.toJson();
    return {
      for (final key in [
        'extractedAt',
        'ocrDate',
        'ocrCurrency',
        'ocrInvoiceNumber',
        'extractionImageSha256',
        'engineId',
        'engineVersion',
        'parserVersion',
        'revision',
        'reviewedRevision',
        'reviewedBy',
        'batchId',
        'imageSha256',
        'ocrMerchant',
        'ocrAmount',
        'ocrGstAmount',
        'ocrAbn',
        'ocrCategory',
        'ocrConfidence',
        'reviewStatus',
        'capturedAt',
        'reviewedAt'
      ])
        key: json[key],
      'currentFields': {
        for (final entry in audit.currentFields.entries)
          if (fields.contains(entry.key)) entry.key: entry.value
      },
      'corrections': [
        for (final correction in audit.corrections)
          if (fields.contains(correction.field)) correction.toJson()
      ],
    };
  }
}

Future<Uint8List> renderTaxPackPdf(
    ({
      Map<String, Object?> data,
      ByteData regular,
      ByteData bold
    }) input) async {
  final data = input.data;
  final pdf = pw.Document(
      title: 'KiloClaim vehicle evidence for accountant review',
      author: 'KiloClaim');
  final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(input.regular), bold: pw.Font.ttf(input.bold));
  const ink = PdfColor.fromInt(0xFF142D3B);
  const muted = PdfColor.fromInt(0xFF536774);
  List<List<String>> rows(String key) => (data[key] as List)
      .map((row) => (row as List)
          .map((cell) => cell is double
              ? cell.toStringAsFixed(2)
              : cell?.toString() ?? 'Not recorded')
          .toList())
      .toList();
  pw.Widget section(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 13, bottom: 6),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink)));
  pw.Widget note(String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Text(value,
          style:
              const pw.TextStyle(fontSize: 8, color: muted, lineSpacing: 2)));
  pw.Widget table(List<List<String>> values,
          {List<String>? headers,
          Map<int, pw.TableColumnWidth>? widths,
          double fontSize = 8.5}) =>
      pw.TableHelper.fromTextArray(
          headers: headers,
          data: values,
          headerCount: headers == null ? 0 : 1,
          columnWidths: widths ??
              {
                0: const pw.FlexColumnWidth(1.25),
                1: const pw.FlexColumnWidth(2)
              },
          cellAlignment: pw.Alignment.topLeft,
          cellPadding:
              const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          cellStyle: pw.TextStyle(fontSize: fontSize, color: ink),
          headerStyle: pw.TextStyle(
              fontSize: fontSize,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: ink),
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F5F6)),
          border: null);
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(34),
    theme: theme,
    footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                  child: pw.Text('KiloClaim | ${data['packId']}',
                      style: const pw.TextStyle(fontSize: 6, color: muted))),
              pw.Text('${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: muted)),
            ])),
    build: (context) => [
      pw.Text('Vehicle evidence',
          style: pw.TextStyle(
              fontSize: 24, fontWeight: pw.FontWeight.bold, color: ink)),
      pw.SizedBox(height: 4),
      pw.Text('For accountant review | ${data['status']}',
          style: const pw.TextStyle(fontSize: 10, color: muted)),
      pw.SizedBox(height: 10),
      table(rows('identity')),
      note(
          'Saved record dates do not establish continuous tracking coverage. Trip end timestamps are not captured.'),
      section('Driving recorded in this pack'),
      table(rows('distance')),
      if (data['isCpk'] != true || rows('annual').isNotEmpty) ...[
        section('Annual odometer reconciliation'),
        if (rows('annual').isEmpty)
          note(
              'No saved annual boundary readings are supplied for this vehicle/year.')
        else
          table(rows('annual'),
              headers: [
                'Saved dates',
                'Opening km',
                'Closing km',
                'Odo km',
                'Trip km',
                'Difference km'
              ],
              widths: {
                0: const pw.FlexColumnWidth(2),
                for (var i = 1; i < 6; i++) i: const pw.FlexColumnWidth(1)
              },
              fontSize: 7.5),
        note(
            'Trip km uses trips with a recorded calendar date within each saved boundary. Difference = odometer movement minus matched trip km; it is not private use. Overlapping comparisons are separate, not additive. See Odometer comparison in Details.xlsx when readings are supplied.'),
      ],
      if (data['isLogbook'] == true || rows('periods').isNotEmpty) ...[
        section('Stored logbook periods'),
        if (rows('periods').isEmpty)
          note(
              'No saved logbook period is supplied. Any original logbook held separately remains outside this financial-year trip ledger.')
        else
          table(rows('periods'),
              headers: [
                'Saved period',
                'Odo start / end km',
                'Stored business %',
                'Saved app status'
              ],
              widths: {
                0: const pw.FlexColumnWidth(2.4),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.3)
              },
              fontSize: 8),
        note(
            'Stored percentages and the observed trip ratio have different periods/bases. A difference alone is not an error. Annual business use may consider logbooks, odometers, changes in use and other records; no percentage is automatically adopted here. App status is not ATO certification. The trip ledger covers the selected financial year only; retain the original logbook separately for any period outside that year.'),
      ],
      section(data['isCpk'] == true
          ? 'Recorded distance-based calculation'
          : 'Annual-use decision'),
      table(rows('calculation')),
      pw.NewPage(),
      pw.Text('Expenses and supporting files',
          style: pw.TextStyle(
              fontSize: 20, fontWeight: pw.FontWeight.bold, color: ink)),
      section('Recorded expense categories'),
      if (rows('expenseCategories').isEmpty)
        note('No usable AUD expense amounts recorded.')
      else
        table(rows('expenseCategories'),
            headers: [
              'Category',
              'Recorded AUD',
              'Basis AUD',
              'Source gap AUD'
            ],
            widths: {
              0: const pw.FlexColumnWidth(2.4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1)
            },
            fontSize: 8),
      note(
          'Basis is the recorded running-cost base before annual-use apportionment plus the recorded direct-cost portion; it is not a deduction. Source gap is the original amount with incomplete, changed or unrecognized attached files, not a disallowed amount. Non-AUD/invalid records are outside these totals; no conversion is made.'),
      section('Gross-to-recorded-basis reconciliation'),
      table(rows('expenseReconciliation')),
      section('Supporting-file coverage'),
      table(rows('evidence')),
      note(
          'File availability does not establish legibility or tax treatment. Evidence held outside the app, including any alternative fuel/oil workings, is not assessed here. Saved costs do not increase a cents-per-kilometre distance calculation.'),
      section(
          '${rows('reviewGroups').length} review groups | ${data['rawCheckCount']} detailed checks'),
      if (rows('reviewGroups').isEmpty)
        note(
            'No outstanding application record checks; eligibility and final tax treatment remain unassessed.')
      else
        table(rows('reviewGroups').take(5).toList()),
      note(
          'All detailed checks are in Details.xlsx / Review. Receipt references match Receipts/ files; extract the ZIP before opening workbook links.'),
      section('Scope and use'),
      note(
          '${data['scope']} ${data['evidenceNote']} Private and mixed route addresses are withheld; original receipt files retain their content.'),
    ],
  ));
  return pdf.save();
}
