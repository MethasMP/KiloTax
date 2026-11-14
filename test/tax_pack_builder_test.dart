import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/core/constants/app_constants.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/tax_pack_builder.dart';

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

  test(
      'ZIP contains scoped records, exact receipt bytes, and truthful missing-file issues',
      () async {
    final receiptBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=');
    final receipt =
        await File('${temp.path}/receipt.png').writeAsBytes(receiptBytes);
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
            isVaultOnly: vaultOnly,
            receiptAudit: ReceiptAuditTrail(
                reviewStatus: ReceiptReviewStatus.manualReview,
                capturedAt: DateTime(2026, 8, 1),
                imageSha256: sha256.convert(receiptBytes).toString(),
                rawOcrText: 'PRIVATE_OCR_SENTINEL'));
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
          expense('present', path: receipt.path).copyWith(allocations: const [
            ReceiptAllocation(
                description: 'Fuel',
                amount: 40,
                purpose: AllocationPurpose.work),
            ReceiptAllocation(
                description: 'Private',
                amount: 10,
                purpose: AllocationPurpose.private),
          ]),
          expense('missing', path: '${temp.path}/absent.png'),
          expense('vault', vaultOnly: true),
          expense('other', vehicleId: 'v2')
        ],
        outputDirectory: temp,
        generatedAt: DateTime(2026, 11, 7));
    const samplePath = String.fromEnvironment('TAX_PACK_SAMPLE_PATH');
    if (samplePath.isNotEmpty) {
      final sample = File(samplePath);
      await sample.parent.create(recursive: true);
      await pack.file.copy(sample.path);
    }
    final zip = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    String contents(String name) =>
        utf8.decode(zip.findFile(name)!.content as List<int>);
    expect(zip.files.map((f) => f.name).toSet(), {
      'summary.pdf',
      '01_Executive_Tax_Workpaper.md',
      'job-connections.csv',
      'trip-review-history.csv',
      'trips.csv',
      'expenses.csv',
      'audit-events.json',
      'receipt-allocations.csv',
      '04_Cryptographic_Receipt_Index.csv',
      'record-sources.csv',
      'review-issues.csv',
      'README.txt',
      'manifest.json',
      'receipts/receipt-000001.png',
    });
    expect(zip.findFile('receipts/receipt-000001.png')!.content, receiptBytes);
    expect(
        ascii.decode((zip.findFile('summary.pdf')!.content as List<int>)
            .take(5)
            .toList()),
        '%PDF-');
    final manifest =
        jsonDecode(contents('manifest.json')) as Map<String, dynamic>;
    expect(manifest['tripCount'], 1);
    expect(manifest['expenseCount'], 3);
    expect(manifest['receiptCount'], 1);
    expect(manifest['status'], 'draft');
    expect(contents('expenses.csv'), contains('receipts/receipt-000001.png'));
    expect(contents('receipt-allocations.csv'), contains('"private"'));
    expect(contents('receipt-allocations.csv'), contains('"false"'));
    expect(contents('receipt-allocations.csv'),
        contains('receipts/receipt-000001.png'));
    expect(contents('expenses.csv'), contains('"missing"'));
    expect(contents('review-issues.csv'), contains('missing'));
    expect(contents('record-sources.csv'), contains('manual_retroactive'));
    final text = zip.files
        .where(
            (f) => f.name != 'summary.pdf' && !f.name.startsWith('receipts/'))
        .map((f) => utf8.decode(f.content as List<int>))
        .join('\n');
    for (final secret in [
      'PRIVATE_PURPOSE_SENTINEL',
      'PRIVATE_ORIGIN_SENTINEL',
      'PRIVATE_DEST_SENTINEL',
      'PRIVATE_NOTES_SENTINEL',
      'PRIVATE_OCR_SENTINEL',
      'wrong-vehicle',
      '/storage/v1/object/public/'
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(contents('trips.csv'), contains('[Private Journey]'));
    expect(contents('README.txt'),
        contains('not a restorable application backup'));
  });

  test(
      'changed bytes are included with changed status and concurrent packs have independent lifetimes',
      () async {
    final receipt =
        await File('${temp.path}/changed').writeAsString('current bytes');
    final expense = VehicleExpense(
        id: '=expense,"id',
        vehicleId: vehicle.id,
        date: DateTime(2026, 8, 1),
        amount: 20,
        category: ExpenseCategory.fuel,
        receiptPath: receipt.path,
        receiptAudit: ReceiptAuditTrail(
            capturedAt: DateTime(2026, 8, 1),
            reviewStatus: ReceiptReviewStatus.verified,
            imageSha256: sha256.convert(utf8.encode('old bytes')).toString()));
    Future<TaxPackArtifact> build() => const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [trip('business')],
        expenses: [expense],
        outputDirectory: temp);
    final packs = await Future.wait([build(), build()]);
    expect(packs[0].directory.path, isNot(packs[1].directory.path));
    final zip = ZipDecoder().decodeBytes(await packs[0].file.readAsBytes());
    final index =
        utf8.decode(zip.findFile('expenses.csv')!.content as List<int>);
    expect(index, contains('"changed"'));
    expect(index, contains("\"'=expense,\"\"id\""));
    expect(zip.findFile('receipts/receipt-000001.bin')!.content,
        utf8.encode('current bytes'));
    await packs[0].directory.delete(recursive: true);
    expect(await packs[1].file.exists(), isTrue);
  });
  test('allocation index reflects the selected CPK method', () async {
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle.copyWith(taxMethod: TaxMethod.centsPerKm),
        taxRule: AppConstants.activeTaxRule,
        trips: [],
        outputDirectory: temp,
        expenses: [
          VehicleExpense(
              id: 'mixed-cpk',
              vehicleId: vehicle.id,
              amount: 120,
              category: ExpenseCategory.fuel,
              date: DateTime(2026, 8, 1),
              allocations: const [
                ReceiptAllocation(
                    description: 'Fuel item',
                    amount: 100,
                    purpose: AllocationPurpose.work,
                    category: ExpenseCategory.fuel),
                ReceiptAllocation(
                    description: 'Parking item',
                    amount: 20,
                    purpose: AllocationPurpose.work,
                    category: ExpenseCategory.tollsParking)
              ])
        ]);
    final zip = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    final csv = utf8
        .decode(zip.findFile('receipt-allocations.csv')!.content as List<int>);
    expect(csv, contains('Included_In_Selected_Method'));
    expect(
        const LineSplitter()
            .convert(csv)
            .singleWhere((s) => s.contains('Fuel item')),
        contains('"false"'));
    expect(
        const LineSplitter()
            .convert(csv)
            .singleWhere((s) => s.contains('Parking item')),
        contains('"true"'));
  });

  test('CPK ledger rows map to actual records in chronological order',
      () async {
    final cpk = vehicle.copyWith(taxMethod: TaxMethod.centsPerKm);
    final pack = await const TaxPackBuilder().build(
      vehicle: cpk,
      taxRule: AppConstants.activeTaxRule,
      trips: [
        trip('later', date: DateTime(2026, 8, 2))
            .copyWith(taxMethod: TaxMethod.centsPerKm),
        trip('private', classification: TripClassification.personal)
            .copyWith(taxMethod: TaxMethod.centsPerKm),
        trip('earlier', date: DateTime(2026, 8, 1))
            .copyWith(taxMethod: TaxMethod.centsPerKm),
      ],
      expenses: [],
      outputDirectory: temp,
    );
    final zip = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    final ledger = utf8.decode(zip.findFile('trips.csv')!.content as List<int>);
    final sources =
        utf8.decode(zip.findFile('record-sources.csv')!.content as List<int>);
    expect(ledger, contains('CPK-20260801-001'));
    expect(ledger, contains('CPK-20260802-002'));
    expect(ledger, contains('Uncapped_Trip_Value_AUD'));
    final sourceLines = const LineSplitter().convert(sources);
    expect(sourceLines.first, contains('Trip_Ledger_Data_Row'));
    expect(sourceLines.singleWhere((line) => line.contains('"earlier"')),
        endsWith(',"1"'));
    expect(sourceLines.singleWhere((line) => line.contains('"later"')),
        endsWith(',"2"'));
    expect(sourceLines.singleWhere((line) => line.contains('"private"')),
        endsWith(',""'));
    expect(sourceLines.indexWhere((line) => line.contains('"earlier"')),
        lessThan(sourceLines.indexWhere((line) => line.contains('"later"'))));
  });
  test('linked unclassified routes stay masked in every text entry', () async {
    final pack = await const TaxPackBuilder().build(
      vehicle: vehicle,
      taxRule: AppConstants.activeTaxRule,
      trips: [
        trip('unknown-trip', classification: TripClassification.unclassified)
      ],
      expenses: [
        VehicleExpense(
          id: 'linked-unknown',
          vehicleId: vehicle.id,
          amount: 20,
          category: ExpenseCategory.tollsParking,
          date: DateTime(2026, 8, 1),
          linkedTripId: 'unknown-trip',
        )
      ],
      outputDirectory: temp,
    );
    final zip = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    final text = zip.files
        .where((file) => file.name != 'summary.pdf')
        .map((file) => utf8.decode(file.content as List<int>))
        .join('\n');
    expect(text, contains('[Private or unclassified journey]'));
    expect(text, isNot(contains('PRIVATE_ORIGIN_SENTINEL')));
    expect(text, isNot(contains('PRIVATE_DEST_SENTINEL')));
    expect(text, isNot(contains('PRIVATE_PURPOSE_SENTINEL')));
    expect(text, isNot(contains('/storage/v1/object/public/')));
  });
  test(
      'multi-page evidence retains field provenance and excludes pending drafts',
      () async {
    final first = await File('${temp.path}/one.png')
        .writeAsBytes([137, 80, 78, 71, 1, 2, 3, 4]);
    final second = await File('${temp.path}/two.png')
        .writeAsBytes([137, 80, 78, 71, 5, 6, 7, 8]);
    final captured = DateTime(2026, 8, 1);
    final expense = VehicleExpense(
        id: 'document-1',
        vehicleId: 'v1',
        date: captured,
        amount: 44,
        gstAmount: 4,
        category: ExpenseCategory.fuel,
        supplier: 'Merchant',
        currency: 'AUD',
        supplierAbn: '12345678901',
        invoiceNumber: 'INV-1',
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
              'pagePaths': [first.path, second.path],
              'pageHashes': [
                sha256.convert(await first.readAsBytes()).toString(),
                'original-second-hash'
              ]
            }));
    final pack = await const TaxPackBuilder().build(
        vehicle: vehicle,
        taxRule: AppConstants.activeTaxRule,
        trips: [],
        expenses: [expense],
        outputDirectory: temp,
        pendingDraftCount: 3);
    final zip = ZipDecoder().decodeBytes(await pack.file.readAsBytes());
    String content(String path) =>
        utf8.decode(zip.findFile(path)!.content as List<int>);
    final manifest = jsonDecode(content('manifest.json'));
    expect(manifest['expenseCount'], 1);
    expect(manifest['pendingDraftCount'], 3);
    expect(manifest['receiptCount'], 2);
    final pages = manifest['receiptDocuments']['document-1'];
    expect(pages[0]['page'], 1);
    expect(pages[1]['page'], 2);
    expect(pages[1]['status'], 'changed');
    expect(zip.findFile(pages[1]['archivePath'])!.content,
        await second.readAsBytes());
    final audit =
        jsonDecode(content('audit-events.json'))['documents'][0]['audit'];
    expect(audit['ocrAmount'], 40);
    expect(audit['reviewedRevision'], 2);
    expect(audit['engineId'], 'test-engine');
    expect(audit['capturedAt'], captured.toIso8601String());
    final csv = content('expenses.csv');
    for (final value in [
      'Merchant',
      'AUD',
      '4.00',
      '12345678901',
      'INV-1',
      'document-1',
      'batch-1',
      'test-engine'
    ]) {
      expect(csv, contains(value));
    }
    expect(content('README.txt'),
        contains('Pending receipt drafts excluded from totals: 3'));
    expect(content('review-issues.csv'), contains('3 pending receipt drafts'));
    expect(pack.report.expenses.single.amount, 44);
  });
}
