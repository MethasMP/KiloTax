import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/core/constants/app_constants.dart';
import 'package:kiloclaim/data/models/annual_odometer.dart';
import 'package:kiloclaim/data/models/job_site.dart';
import 'package:kiloclaim/data/models/logbook_period.dart';
import 'package:kiloclaim/data/models/trip.dart';
import 'package:kiloclaim/data/models/user_profile.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/engine/evidence_review_service.dart';
import 'package:kiloclaim/services/engine/tax_calculator_service.dart';
import 'package:kiloclaim/services/engine/tax_pack_analysis.dart';
import 'package:kiloclaim/services/engine/tax_pack_documents.dart';

void main() {
  final vehicle = Vehicle(
      id: 'v',
      make: 'Toyota',
      model: 'Corolla',
      regoPlate: 'TEST',
      taxMethod: TaxMethod.logbook);
  Trip trip(String id, DateTime date,
          {double km = 20,
          TripClassification classification = TripClassification.business,
          Map<String, dynamic> review = const {},
          String? jobId}) =>
      Trip(
          id: id,
          vehicleId: 'v',
          date: date,
          distanceKm: km,
          purpose: 'Client meeting',
          classification: classification,
          review: review,
          taxMethod: TaxMethod.logbook,
          jobId: jobId);
  VehicleExpense expense(String id,
          {double amount = 100,
          String? currency = 'AUD',
          bool vault = false,
          List<ReceiptAllocation> allocations = const [],
          String? linkedTripId,
          String? jobId}) =>
      VehicleExpense(
          id: id,
          vehicleId: 'v',
          date: DateTime(2026, 8, 1),
          amount: amount,
          currency: currency,
          category: ExpenseCategory.fuel,
          isVaultOnly: vault,
          allocations: allocations,
          linkedTripId: linkedTripId,
          jobId: jobId);
  AnnualVehicleOdometer annual(String id,
          {DateTime? start,
          DateTime? end,
          double opening = 100,
          double? closing = 200}) =>
      AnnualVehicleOdometer(
          id: id,
          vehicleId: 'v',
          financialYear: '2026-27',
          openingDate: start ?? DateTime(2026, 8, 2),
          closingDate: end ?? DateTime(2026, 8, 3),
          openingOdometer: opening,
          closingOdometer: closing);
  TaxPackDocuments documents(
      {TaxMethod method = TaxMethod.logbook,
      List<Trip> trips = const [],
      List<VehicleExpense> expenses = const [],
      List<AnnualVehicleOdometer> annuals = const [],
      List<LogbookPeriod> periods = const [],
      List<List<String>> issues = const [],
      List<JobSite> jobs = const [],
      Map<String, ReceiptFileInspection> inspections = const {},
      Map<String, List<Map<String, dynamic>>> pages = const {}}) {
    final report = EvidenceReviewReport(
        vehicle: vehicle.copyWith(taxMethod: method),
        financialYear: AppConstants.activeTaxRule.financialYear,
        trips: trips,
        expenses: expenses,
        items: const []);
    return TaxPackDocuments(
        report: report,
        summary: TaxCalculatorService.evaluateSummary(
            trips: trips, expenses: expenses),
        taxRule: AppConstants.activeTaxRule,
        profile: const UserProfile(),
        jobs: jobs,
        inspections: inspections,
        receiptPages: pages,
        issues: [...issues],
        generatedAt: DateTime(2026, 11, 15),
        pendingDraftCount: 0,
        annualOdometers: annuals,
        logbookPeriods: periods);
  }

  test(
      'odometer comparison uses matched calendar dates and keeps a signed difference',
      () {
    final trips = [
      trip('before', DateTime(2026, 8, 1), km: 30),
      trip('start', DateTime(2026, 8, 2, 1), km: 20),
      trip('end', DateTime(2026, 8, 3, 23), km: 40),
      trip('after', DateTime(2026, 8, 4), km: 50)
    ];
    final comparison = AnnualOdometerComparison(annual('a'), trips);
    expect(comparison.matchedTrips.map((trip) => trip.id), ['start', 'end']);
    expect(comparison.odometerKm, 100);
    expect(comparison.recordedKm, 60);
    expect(comparison.differenceKm, 40);
    final shorterOdo =
        AnnualOdometerComparison(annual('b', closing: 150), trips);
    expect(shorterOdo.differenceKm, -10,
        reason:
            'Over-recorded travel must not be clamped or classified as private.');
  });

  test('unclosed, reversed and nonfinite odometers have no denominator', () {
    for (final record in [
      annual('open', closing: null),
      annual('reversed', closing: 90),
      annual('dates', end: DateTime(2026, 8, 1)),
      annual('infinite', opening: double.infinity)
    ]) {
      final comparison =
          AnnualOdometerComparison(record, [trip('t', DateTime(2026, 8, 2))]);
      expect(comparison.problem, isNotNull);
      expect(comparison.odometerKm, isNull);
      expect(comparison.recordedKm, isNull);
      expect(comparison.differenceKm, isNull);
    }
  });

  test(
      'overlapping annual records remain separate and are flagged, never added',
      () {
    final data = documents(
        trips: [trip('t', DateTime(2026, 8, 2))],
        annuals: [annual('a'), annual('b')]);
    expect(data.annualComparisons, hasLength(2));
    expect(data.contextReviewItems.any((row) => row[2].contains('overlap')),
        isTrue);
    expect((data.pdfData['annual'] as List), hasLength(2));
  });

  test(
      'business, known private and undecided distances conserve the original total',
      () {
    final data = documents(trips: [
      trip('business', DateTime(2026, 8, 1)),
      trip('mixed', DateTime(2026, 8, 2), review: {'businessKm': 15}),
      trip('private', DateTime(2026, 8, 3),
          classification: TripClassification.personal),
      trip('unknown', DateTime(2026, 8, 4),
          classification: TripClassification.unclassified)
    ]);
    expect(data.analysis.privateKm, 25);
    expect(data.analysis.undecidedKm, 20);
    expect(
        data.summary.businessKm +
            data.analysis.privateKm +
            data.analysis.undecidedKm,
        80);
  });

  test(
      'a stored logbook percentage is context, not automatically applied or an error',
      () {
    final period = LogbookPeriod(
        id: 'period',
        vehicleId: 'v',
        startDate: DateTime(2025, 7, 1),
        endDate: DateTime(2025, 9, 23),
        startOdometer: 10,
        endOdometer: 100,
        certifiedBusinessPercentage: 60,
        status: LogbookStatus.certifiedValid,
        establishedFinancialYear: '2025-26',
        validUntilFinancialYear: '2029-30');
    final data =
        documents(trips: [trip('t', DateTime(2026, 8, 1))], periods: [period]);
    expect(data.summary.businessPercentage, 100);
    expect(data.contextReviewItems.any((row) => row[2].contains('differs')),
        isFalse);
    expect((data.pdfData['periods'] as List).single[2], 60);
    expect((data.pdfData['calculation'] as List).last[1],
        contains('Not determined'));
    expect(data.pdfData['calculation'].toString(),
        isNot(contains('Illustrative')));
  });

  test(
      'actual-expense vehicles do not acquire logbook-only requirements or a logbook formula',
      () {
    final data =
        documents(method: TaxMethod.actualExpenses, expenses: [expense('e')]);
    expect(data.method, 'Actual expenses');
    expect(data.contextReviewItems, isEmpty);
    expect(data.tables.containsKey('Logbook records'), isFalse);
    expect(data.calculationRows.toString(),
        isNot(contains('Illustrative recorded-data estimate')));
    expect(data.tables['Expenses']![1][12], isNull);
  });

  test(
      'split receipt categories reconcile gross once, basis and source exposure separately',
      () {
    final records = [
      expense('split', allocations: const [
        ReceiptAllocation(
            description: 'Fuel', amount: 40, purpose: AllocationPurpose.work),
        ReceiptAllocation(
            description: 'Parking',
            amount: 20,
            purpose: AllocationPurpose.work,
            category: ExpenseCategory.tollsParking),
        ReceiptAllocation(
            description: 'Private',
            amount: 10,
            purpose: AllocationPurpose.private),
        ReceiptAllocation(
            description: 'Unknown',
            amount: 30,
            purpose: AllocationPurpose.unresolved),
      ]),
      expense('vault', amount: 50, vault: true)
    ];
    final data = documents(expenses: records);
    final analysis = data.analysis;
    expect(analysis.grossAud, 150);
    expect(analysis.categories.fold<double>(0, (sum, row) => sum + row.gross),
        150);
    expect(analysis.runningBasis, 40);
    expect(analysis.directBasis, 20);
    expect(analysis.vaultAud, 50);
    expect(analysis.excludedAllocationAud, 40);
    expect(
        analysis.grossAud - analysis.vaultAud - analysis.excludedAllocationAud,
        analysis.runningBasis + analysis.directBasis);
    expect(analysis.evidenceGapAud, 150);
  });

  test(
      'missing pages affect one whole document amount once and generic checks are grouped',
      () {
    final data = documents(expenses: [
      expense('e')
    ], inspections: {
      'e': const ReceiptFileInspection(status: ReceiptFileStatus.missing)
    }, pages: {
      'e': [
        {
          'page': 1,
          'archivePath': 'Receipts/R000001_p01.pdf',
          'status': 'available'
        },
        {'page': 2, 'status': 'missing'},
        {'page': 3, 'status': 'missing'},
      ]
    }, issues: [
      ['expense', 'e', 'Receipt file is unavailable'],
      ['expense', 'e', 'Receipt page 2 is unavailable.'],
      ['expense', 'e', 'Receipt page 3 is unavailable.'],
    ]);
    expect(data.analysis.completeDocumentCount, 0);
    expect(data.analysis.evidenceGapAud, 100);
    expect(data.reviewGroups, hasLength(1));
    expect(data.reviewGroups.single[1], contains('page 2'));
    expect(data.reviewGroups.single[1], contains('page 3'));
    expect(data.reviewGroups.single[1],
        isNot(contains('Receipt file is unavailable')));
  });

  test(
      'foreign, unknown and nonfinite amounts never become AUD totals or an AUD illustration',
      () {
    final data = documents(expenses: [
      expense('aud', amount: 50),
      expense('eur', currency: 'EUR'),
      expense('unknown', currency: null),
      expense('invalid', amount: double.nan)
    ]);
    expect(data.analysis.grossAud, 50);
    expect(data.analysis.outsideAudCount, 3);
    expect(data.analysis.canIllustrateCosts, isFalse);
    expect(data.calculationRows.toString(),
        isNot(contains('Illustrative recorded-data estimate')));
    expect(data.tables['Expenses']!.skip(1).every((row) => row[12] == null),
        isTrue);
    expect(
        data.contextReviewItems
            .where((row) => row[2].contains('Currency or amount')),
        hasLength(3));
    expect(data.tables['Expenses']![2][6], 'EUR');
  });

  test(
      'expense links cannot inherit job context from legacy private or undecided trips',
      () {
    final jobs = [
      JobSite(
          id: 'secret',
          name: 'PRIVATE_JOB_SENTINEL',
          clientName: 'PRIVATE_CLIENT_SENTINEL',
          projectCode: 'PRIVATE_PROJECT_SENTINEL',
          latitude: 0,
          longitude: 0)
    ];
    final data = documents(jobs: jobs, trips: [
      trip('private', DateTime(2026, 8, 1),
          classification: TripClassification.personal, jobId: 'secret')
    ], expenses: [
      expense('linked', linkedTripId: 'private'),
      expense('explicit', linkedTripId: 'private', jobId: 'secret')
    ]);
    final linked = data.tables['Expenses']![1];
    expect(linked[18], isNull);
    expect(linked[19], '');
    expect(linked[20], '');
    expect(linked[21], '');
    expect(data.tables['Expenses']![2][19], 'PRIVATE_JOB_SENTINEL',
        reason:
            'An explicitly assigned expense job is its own recorded work context.');
  });
}
