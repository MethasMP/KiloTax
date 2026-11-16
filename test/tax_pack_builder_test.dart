import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/annual_odometer.dart';
import 'package:kilotax/data/models/logbook_period.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/user_profile.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/tax_pack_builder.dart';

import 'support/tax_pack_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pack-test-'));
  tearDown(() async => temp.delete(recursive: true));

  final vehicle = Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Corolla',
      regoPlate: 'ABC123',
      engineCapacity: '1.8L',
      initialOdometer: 100,
      taxMethod: TaxMethod.logbook,
      logbookStartDate: DateTime(2026, 7, 1));
  Trip trip(String id,
          {String vehicleId = 'v1',
          DateTime? date,
          TripClassification classification = TripClassification.business,
          DateTime? deletedAt}) =>
      Trip(
          id: id,
          vehicleId: vehicleId,
          date: date ?? DateTime(2026, 8, 1),
          distanceKm: 20,
          startOdometer: 100,
          endOdometer: 120,
          taxMethod: TaxMethod.logbook,
          purpose: classification == TripClassification.business
              ? 'Client meeting'
              : 'PRIVATE_PURPOSE_SENTINEL',
          originAddress: 'PRIVATE_ORIGIN_SENTINEL',
          destinationAddress: 'PRIVATE_DEST_SENTINEL',
          classification: classification,
          evidenceSource: 'manual_retroactive',
          deletedAt: deletedAt);
  VehicleExpense expense(String id,
          {String? path, bool vaultOnly = false, String vehicleId = 'v1'}) =>
      VehicleExpense(
          id: id,
          vehicleId: vehicleId,
          date: DateTime(2026, 8, 1),
          amount: 50,
          category: ExpenseCategory.fuel,
          receiptPath: path,
          notes: 'PRIVATE_NOTES_SENTINEL',
          linkedTripId: 'private',
          isVaultOnly: vaultOnly);
  Future<TaxPackReader> read(TaxPackArtifact pack) async =>
      TaxPackReader(ZipDecoder().decodeBytes(await pack.file.readAsBytes()));

  test(
      'two primary documents preserve scoped evidence and expose missing files',
      () async {
    final receiptBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=');
    final receipt =
        await File('${temp.path}/receipt.png').writeAsBytes(receiptBytes);
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [
          trip('private', classification: TripClassification.personal),
          trip('wrong-vehicle', vehicleId: 'v2'),
          trip('old', date: DateTime(2025, 8, 1)),
          trip('deleted', deletedAt: DateTime(2026, 8, 2))
        ],
        expenses: [
          expense('present', path: receipt.path).copyWith(
              allocations: const [
                ReceiptAllocation(
                    description: 'Fuel',
                    amount: 40,
                    purpose: AllocationPurpose.work),
                ReceiptAllocation(
                    description: 'Private',
                    amount: 10,
                    purpose: AllocationPurpose.private),
              ],
              receiptAudit: ReceiptAuditTrail(
                  reviewStatus: ReceiptReviewStatus.manualReview,
                  capturedAt: DateTime(2026, 8, 1),
                  rawOcrText: 'PRIVATE_OCR_SENTINEL')),
          expense('missing', path: '${temp.path}/absent.png'),
          expense('vault', vaultOnly: true),
          expense('other', vehicleId: 'v2')
        ],
        outputDirectory: temp,
        generatedAt: DateTime(2026, 11, 15));
    final result = await read(pack);
    expect(
        result.archive.files
            .where((file) => !file.name.contains('/'))
            .map((file) => file.name)
            .toSet(),
        {'Report.pdf', 'Details.xlsx'});
    expect(
        result.archive.files.any(
            (file) => file.name.endsWith('.csv') || file.name.endsWith('.md')),
        isFalse);
    final receiptPath = (result.metadata['receiptDocuments']['present'] as List)
        .single['archivePath'] as String;
    expect(result.archive.findFile(receiptPath)!.content, receiptBytes);
    expect(result.hyperlinkTargets('Expenses'), [receiptPath]);
    expect(result.hyperlinkTargets('Receipt items'), everyElement(receiptPath));
    expect(result.archive.findFile('Report.pdf')!.content.take(5),
        [37, 80, 68, 70, 45]);
    expect(await pack.reportFile.readAsBytes(),
        result.archive.findFile('Report.pdf')!.content);
    expect(result.metadata['tripCount'], 1);
    expect(result.metadata['expenseCount'], 3);
    expect(result.metadata['receiptCount'], 1);
    expect(result.metadata['status'], 'draft');
    expect(result.summaryValue('Trips recorded'), 1);
    expect(
        result.rows('Expenses').singleWhere(
            (row) => row['Expense ID'] == 'present')['Receipt page files'],
        receiptPath);
    expect(result.rows('Receipt items').map((row) => row['Use']),
        contains('private'));
    expect(result.rows('Review').any((row) => row['Record ID'] == 'missing'),
        isTrue);
    expect(
        result.rows('Trips').single['Evidence source'], 'manual_retroactive');
    expect(result.rows('Trips').single['Origin'], '[Private Journey]');
    for (final secret in [
      'PRIVATE_PURPOSE_SENTINEL',
      'PRIVATE_ORIGIN_SENTINEL',
      'PRIVATE_DEST_SENTINEL',
      'PRIVATE_NOTES_SENTINEL',
      'PRIVATE_OCR_SENTINEL',
      'wrong-vehicle',
      '/storage/v1/object/public/'
    ]) {
      expect(result.searchableText, isNot(contains(secret)));
    }
    expect(result.summaryValue('Receipt evidence'),
        contains('not a restorable application backup'));
    expect(result.summaryValue('Scope'), contains('depreciation'));
    expect(result.metadata['files'].toSet(),
        result.archive.files.map((file) => file.name).toSet());
    const samplePath = String.fromEnvironment('TAX_PACK_SAMPLE_PATH');
    if (samplePath.isNotEmpty) {
      final sample = File(samplePath);
      await sample.parent.create(recursive: true);
      await pack.file.copy(sample.path);
    }
  });

  test(
      'changed bytes and formula-like IDs stay intact; concurrent packs remain independent',
      () async {
    final receipt =
        await File('${temp.path}/changed').writeAsString('current bytes');
    final record = expense('=expense,"id', path: receipt.path).copyWith(
        receiptAudit: ReceiptAuditTrail(
            capturedAt: DateTime(2026, 8, 1),
            reviewStatus: ReceiptReviewStatus.verified,
            imageSha256: sha256.convert(utf8.encode('old bytes')).toString()));
    Future<TaxPackArtifact> build() => const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [trip('business')],
        expenses: [record],
        outputDirectory: temp);
    final packs = await Future.wait([build(), build()]);
    expect(packs[0].directory.path, isNot(packs[1].directory.path));
    final result = await read(packs[0]);
    expect(result.rows('Expenses').single['Receipt file status'], 'changed');
    expect(result.rows('Expenses').single['Expense ID'], '=expense,"id');
    expect(result.sheetXml('Expenses'), isNot(contains('<f>')));
    expect(result.archive.findFile('Receipts/R000001_p01.bin')!.content,
        utf8.encode('current bytes'));
    await packs[0].directory.delete(recursive: true);
    expect(await packs[1].file.exists(), isTrue);
  });

  test('CPK cap is applied once and saved expenses never inflate its estimate',
      () async {
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle.copyWith(taxMethod: TaxMethod.centsPerKm),
        taxRule: AppConstants.activeTaxRule,
        trips: [
          trip('long').copyWith(
              taxMethod: TaxMethod.centsPerKm,
              distanceKm: 6000,
              startOdometer: 100,
              endOdometer: 6100)
        ],
        expenses: [
          expense('cpk').copyWith(allocations: const [
            ReceiptAllocation(
                description: 'Fuel item',
                amount: 30,
                purpose: AllocationPurpose.work),
            ReceiptAllocation(
                description: 'Parking item',
                amount: 20,
                purpose: AllocationPurpose.work,
                category: ExpenseCategory.tollsParking),
          ])
        ],
        outputDirectory: temp);
    final result = await read(pack);
    expect(result.summaryValue('Capped business km'),
        AppConstants.activeTaxRule.centsPerKmMaxKm);
    expect(
        result.summaryValue('Recorded distance-based estimate (AUD)'),
        AppConstants.activeTaxRule.centsPerKmMaxKm *
            AppConstants.activeTaxRule.centsPerKmRate);
    expect(
        result
            .rows('Expenses')
            .single['Recorded method estimate contribution (AUD)'],
        0);
    expect(
        result
            .rows('Receipt items')
            .every((row) => row['Included in recorded estimate'] == 'false'),
        isTrue);
    expect(result.summaryValue('Expense treatment'),
        contains('Separate expense treatment'));
  });

  test(
      'all trip IDs and mixed distances survive consolidation in chronological order',
      () async {
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [
          trip('later', date: DateTime(2026, 8, 2)),
          trip('private', classification: TripClassification.personal),
          trip('earlier').copyWith(review: {
            'businessKm': 15,
            'confirmedAt': '2026-08-01',
            'history': [
              {'classification': 'business', 'businessKm': 15, 'actor': 'user'}
            ]
          })
        ],
        expenses: [],
        outputDirectory: temp);
    final result = await read(pack);
    final rows = result.rows('Trips');
    expect(rows.map((row) => row['Trip ID']), ['earlier', 'private', 'later']);
    expect(rows.first['Classification'], 'MIXED');
    expect(rows.first['Trip ref'], 'T000001');
    expect(rows.first['Business km'], 15);
    expect(rows.first['Private or undecided km'], 5);
    expect(rows.first['Odometer start (recorded)'], 100);
    expect(rows.first['Odometer end (recorded)'], 120);
    expect(rows.first['Origin'], '[Private Journey]');
    expect(result.summaryValue('Business km'), 35);
    expect(result.rows('Trip changes').single['Business km'], 15);
    expect(result.sheetXml('Trips'), contains('state="frozen"'));
    expect(result.sheetXml('Trips'), contains('<autoFilter'));
  });

  test(
      'linked unclassified routes and local paths are absent from shared records',
      () async {
    final record = expense('linked-unknown').copyWith(
        linkedTripId: 'unknown-trip',
        receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.needsReview,
            capturedAt: DateTime(2026, 8, 1),
            currentFields: {
              'pagePaths': ['/private/LOCAL_PATH_SENTINEL'],
              'notes': 'PRIVATE_NOTES_SENTINEL',
              'merchant': 'Recorded merchant',
              'abn': '00123456789'
            },
            corrections: [
              ReceiptFieldCorrection(
                  field: 'merchant',
                  oldValue: 'OCR merchant',
                  newValue: 'Recorded merchant',
                  timestamp: DateTime(2026, 8, 1),
                  revision: 2)
            ]));
    final result = await read(await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [
          trip('unknown-trip', classification: TripClassification.unclassified)
        ],
        expenses: [record],
        outputDirectory: temp));
    expect(
        result.searchableText, contains('[Private or unclassified journey]'));
    for (final secret in [
      'PRIVATE_ORIGIN_SENTINEL',
      'PRIVATE_DEST_SENTINEL',
      'PRIVATE_PURPOSE_SENTINEL',
      'PRIVATE_NOTES_SENTINEL',
      'LOCAL_PATH_SENTINEL',
      '/storage/v1/object/public/'
    ]) {
      expect(result.searchableText, isNot(contains(secret)));
    }
    expect(result.metadata['documents'][0]['audit']['currentFields']['abn'],
        '00123456789');
    expect(
        result.metadata['documents'][0]['audit']['corrections'][0]['oldValue'],
        'OCR merchant');
  });

  test(
      'multipage originals retain provenance, missing page positions and excluded drafts',
      () async {
    final first = await File('${temp.path}/one.png')
        .writeAsBytes([137, 80, 78, 71, 1, 2, 3, 4]);
    final third = await File('${temp.path}/three.png')
        .writeAsBytes([137, 80, 78, 71, 5, 6, 7, 8]);
    final captured = DateTime(2026, 8, 1);
    final record = expense('document-1').copyWith(
        amount: 44,
        gstAmount: 4,
        supplier: 'Merchant',
        supplierAbn: '00123456789',
        invoiceNumber: '000123',
        receiptPath: first.path,
        receiptAudit: ReceiptAuditTrail(
            reviewStatus: ReceiptReviewStatus.confirmed,
            capturedAt: captured,
            extractedAt: captured,
            ocrAmount: 40,
            ocrCurrency: 'AUD',
            revision: 2,
            reviewedRevision: 2,
            reviewedBy: 'user',
            reviewedAt: captured,
            engineId: 'test-engine',
            engineVersion: '1',
            parserVersion: '2',
            batchId: 'batch-1',
            currentFields: {
              'pagePaths': [first.path, '${temp.path}/missing.png', third.path],
              'pageHashes': [
                sha256.convert(await first.readAsBytes()).toString(),
                'missing-hash',
                'old-third-hash'
              ]
            }));
    final result = await read(await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [],
        expenses: [record],
        outputDirectory: temp,
        pendingDraftCount: 3));
    final pages = result.metadata['receiptDocuments']['document-1'] as List;
    expect(result.metadata['receiptCount'], 2);
    expect(pages[1]['status'], 'missing');
    expect(pages[2]['status'], 'changed');
    expect(pages[2]['archivePath'], 'Receipts/R000001_p03.png');
    expect(result.archive.findFile(pages[2]['archivePath'] as String)!.content,
        await third.readAsBytes());
    expect(result.rows('Expenses').single['Receipt page files'],
        contains('p03.png'));
    expect(result.rows('Expenses').single['Supplier ABN'], '00123456789');
    expect(result.rows('Expenses').single['Invoice number'], '000123');
    expect(result.metadata['documents'][0]['audit']['ocrAmount'], 40);
    expect(result.metadata['documents'][0]['audit']['reviewedRevision'], 2);
    expect(result.metadata['documents'][0]['audit']['engineId'], 'test-engine');
    expect(result.summaryValue('Pending receipt drafts excluded'), 3);
    expect(
        result.rows('Review').any((row) =>
            row['Review item'].toString().contains('3 pending receipt drafts')),
        isTrue);
  });

  test(
      'profile and actual annual/logbook records export without substituting trip readings or ratios',
      () async {
    final result = await read(await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [trip('business')],
        expenses: [],
        outputDirectory: temp,
        profile: const UserProfile(
            taxpayerName: 'Alex Example',
            abn: '00123456789',
            homeAddress: 'HOME_SECRET'),
        annualOdometers: [
          AnnualVehicleOdometer(
              id: 'annual',
              vehicleId: vehicle.id,
              financialYear: '2026-2027',
              openingDate: DateTime(2026, 7, 1),
              openingOdometer: 50,
              closingDate: DateTime(2027, 6, 30),
              closingOdometer: 20000),
          AnnualVehicleOdometer(
              id: 'other-vehicle-secret',
              vehicleId: 'v2',
              financialYear: '2026-27',
              openingDate: DateTime(2026, 7, 1),
              openingOdometer: 1)
        ],
        logbookPeriods: [
          LogbookPeriod(
              id: 'prior-logbook',
              vehicleId: vehicle.id,
              startDate: DateTime(2025, 7, 1),
              endDate: DateTime(2025, 9, 23),
              startOdometer: 10,
              endOdometer: 50,
              status: LogbookStatus.certifiedValid,
              certifiedBusinessPercentage: 60,
              establishedFinancialYear: '2025-26',
              validUntilFinancialYear: '2029-30')
        ]));
    expect(result.summaryValue('Taxpayer'), 'Alex Example');
    expect(result.summaryValue('ABN (if applicable)'), '00123456789');
    expect(result.summaryValue('Engine capacity'), '1.8L');
    expect(result.summaryValue('Recorded business ratio (%)'), 100);
    final context = result.rows('Logbook records');
    expect(context.first['Opening odometer'], 50);
    expect(context.first['Closing odometer'], 20000);
    expect(context.last['Stored business %'], 60);
    expect(context.last['Established year'], '2025-26');
    expect(
        result.rows('Review').any(
            (row) => row['Review item'].toString().contains('differs from')),
        isFalse);
    expect(result.searchableText, isNot(contains('other-vehicle-secret')));
    expect(result.searchableText, isNot(contains('HOME_SECRET')));
  });

  test(
      'expense contributions reconcile and vault, private and unresolved amounts are excluded',
      () async {
    final result = await read(await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [
          trip('mixed').copyWith(review: {'businessKm': 10})
        ],
        expenses: [
          expense('running').copyWith(linkedTripId: 'mixed'),
          expense('vault', vaultOnly: true),
          expense('split').copyWith(allocations: const [
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
                amount: 20,
                purpose: AllocationPurpose.unresolved),
          ])
        ],
        outputDirectory: temp));
    final total = result.rows('Expenses').fold<num>(
        0,
        (sum, row) =>
            sum + (row['Recorded method estimate contribution (AUD)'] as num));
    expect(total,
        result.summaryValue('Illustrative recorded-data estimate (AUD)'));
    expect(total, 45);
    expect(
        result
                .rows('Expenses')
                .singleWhere((row) => row['Expense ID'] == 'vault')[
            'Recorded method estimate contribution (AUD)'],
        0);
  });

  test(
      'actual-expense ZIP is named correctly without logbook-only context checks',
      () async {
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle.copyWith(taxMethod: TaxMethod.actualExpenses),
        taxRule: AppConstants.activeTaxRule,
        trips: [],
        expenses: [expense('actual').copyWith(clearLinkedTripId: true)],
        outputDirectory: temp);
    final result = await read(pack);
    expect(pack.file.path, contains('KiloTax_Actuals_'));
    expect(result.summaryValue('Selected method'), 'Actual expenses');
    expect(result.sheetNames, isNot(contains('Logbook records')));
    expect(
        result.rows('Review').any(
            (row) => row['Review item'].toString().contains('logbook period')),
        isFalse);
    expect(
        result
            .rows('Expenses')
            .single['Recorded method estimate contribution (AUD)'],
        '');
  });

  test(
      'empty or wrong-year records cannot generate an apparently complete pack',
      () async {
    await expectLater(
        const TaxPackBuilder().build(
            vehicle: vehicle,
            taxRule: AppConstants.activeTaxRule,
            trips: [trip('old', date: DateTime(2025, 1, 1))],
            expenses: [],
            outputDirectory: temp),
        throwsStateError);
  });
  test('representative 20-trip 10-expense handoff opens with reconciled totals',
      () async {
    final records = <VehicleExpense>[];
    for (var index = 0; index < 10; index++) {
      final receipt = pw.Document();
      receipt.addPage(pw.Page(
          build: (_) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('EXAMPLE RECEIPT - DEMONSTRATION ONLY'),
                    pw.Text('Example Supplier ${index + 1}'),
                    pw.Text(
                        'Date: 2026-08-${(index + 1).toString().padLeft(2, '0')}'),
                    pw.Text(
                        'Vehicle expense: AUD ${(50 + index * 5).toStringAsFixed(2)}'),
                  ])));
      final path = '${temp.path}/example-$index.pdf';
      if (index < 8) await File(path).writeAsBytes(await receipt.save());
      records.add(expense('example-expense-$index', path: path).copyWith(
          date: DateTime(2026, 8, index + 1),
          amount: (50 + index * 5).toDouble(),
          supplier: 'Example Supplier ${index + 1}',
          clearLinkedTripId: true,
          receiptAudit: ReceiptAuditTrail(
              reviewStatus: ReceiptReviewStatus.confirmed,
              capturedAt: DateTime(2026, 8, index + 1))));
    }
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        profile: const UserProfile(taxpayerName: 'Alex Example'),
        trips: [
          for (var index = 0; index < 20; index++)
            trip('example-trip-${index.toString().padLeft(2, '0')}',
                    date: DateTime(2026, 8, index + 1),
                    classification: index == 19
                        ? TripClassification.unclassified
                        : index.isEven
                            ? TripClassification.business
                            : TripClassification.personal)
                .copyWith(
                    originAddress: 'Example workshop',
                    destinationAddress: 'Example customer site',
                    purpose: index == 19 ? '' : 'Customer site visit',
                    startOdometer: (100 + index * 20).toDouble(),
                    endOdometer: (120 + index * 20).toDouble(),
                    review: index == 4
                        ? {'businessKm': 15, 'confirmedAt': '2026-08-05'}
                        : {})
        ],
        expenses: records,
        outputDirectory: temp,
        annualOdometers: [
          AnnualVehicleOdometer(
              id: 'sample-annual',
              vehicleId: vehicle.id,
              financialYear: '2026-27',
              openingDate: DateTime(2026, 7, 1),
              openingOdometer: 100,
              closingDate: DateTime(2026, 11, 15),
              closingOdometer: 800)
        ],
        logbookPeriods: [
          LogbookPeriod(
              id: 'sample-logbook',
              vehicleId: vehicle.id,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2026, 9, 23),
              startOdometer: 100,
              endOdometer: 600,
              certifiedBusinessPercentage: 60,
              status: LogbookStatus.certifiedValid,
              establishedFinancialYear: '2026-27',
              validUntilFinancialYear: '2030-31')
        ],
        generatedAt: DateTime(2026, 11, 15, 12));
    final result = await read(pack);
    expect(result.summaryValue('Trips recorded'), 20);
    expect(result.metadata['reviewGroupCount'], 4);
    expect(pack.issueCount, 4);
    expect(result.metadata['reviewItemCount'], 6);
    expect(result.summaryValue('Business km'), 195);
    expect(result.summaryValue('Receipt pages included'), 8);
    expect(result.hyperlinkTargets('Expenses'), hasLength(8));
    for (final target in result.hyperlinkTargets('Expenses')) {
      expect(result.archive.findFile(target), isNotNull);
    }
    expect(result.rows('Expenses'), hasLength(10));
    expect(result.summaryValue('Total recorded km'), 400);
    final contribution = result.rows('Expenses').fold<num>(
        0,
        (sum, row) =>
            sum + (row['Recorded method estimate contribution (AUD)'] as num));
    expect(
        contribution,
        closeTo(
            result.summaryValue('Illustrative recorded-data estimate (AUD)')
                as num,
            0.000001));
    const samplePath = String.fromEnvironment('TAX_PACK_SAMPLE_PATH');
    if (samplePath.isNotEmpty) await pack.file.copy(samplePath);
  });
}
