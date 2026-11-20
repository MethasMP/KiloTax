import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/openxml_workbook_builder.dart';

List<String> _extractSheetNames(Archive archive) {
  final wbFile = archive.findFile('xl/workbook.xml');
  if (wbFile == null) return [];
  final content = utf8.decode(wbFile.content as List<int>);
  final regex = RegExp(r'<sheet\s+name="([^"]+)"');
  return regex
      .allMatches(content)
      .map((m) => m.group(1)!.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'"))
      .toList();
}

void main() {
  group('OpenXmlWorkbookBuilder', () {
    test('builds multi-tab xlsx file with correct structure and cell types', () {
      final builder = OpenXmlWorkbookBuilder();

      final summarySheet = builder.addSheet('Tax Summary');
      summarySheet.addRow(['Metric', 'Value', 'Notes']);
      summarySheet.addRow(['Business %', 82.5, 'ATO Logbook']);
      summarySheet.addRow(['Total Claim (AUD)', 4250.75, 'Box D1']);

      final tripsSheet = builder.addSheet('Logbook Trips');
      tripsSheet.addRow(['Trip ID', 'Date', 'Distance KM', 'Purpose']);
      tripsSheet.addRow(['TRIP-01', '2026-08-14', 18.5, 'Site visit & contract works']);

      final expensesSheet = builder.addSheet('Expenses & Receipts');
      expensesSheet.addRow(['Expense ID', 'Vendor', 'Amount AUD', 'Linked Trip', 'Cloud Receipt URL']);
      expensesSheet.addRow([
        'EXP-01',
        'Bunnings Warehouse',
        142.50,
        'TRIP-01',
        'https://example.com/receipts/exp-01.webp'
      ]);

      final bytes = builder.buildBytes();
      expect(bytes, isNotEmpty);

      // Verify ZIP archive decoding
      final zip = ZipDecoder().decodeBytes(bytes);
      final fileNames = zip.files.map((f) => f.name).toSet();

      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('xl/workbook.xml'));
      expect(fileNames, contains('xl/_rels/workbook.xml.rels'));
      expect(fileNames, contains('xl/styles.xml'));
      expect(fileNames, contains('xl/worksheets/sheet1.xml'));
      expect(fileNames, contains('xl/worksheets/sheet2.xml'));
      expect(fileNames, contains('xl/worksheets/sheet3.xml'));

      // Check workbook sheet names
      final wbXml = utf8.decode(zip.findFile('xl/workbook.xml')!.content as List<int>);
      expect(wbXml, contains('name="Tax Summary"'));
      expect(wbXml, contains('name="Logbook Trips"'));
      expect(wbXml, contains('name="Expenses &amp; Receipts"')); // XML escaped &

      // Check sheet 1 content (numbers and text)
      final s1Xml = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
      expect(s1Xml, contains('<c r="A1" t="inlineStr"><is><t>Metric</t></is></c>'));
      expect(s1Xml, contains('<c r="B2" t="n"><v>82.5</v></c>'));
      expect(s1Xml, contains('<c r="B3" t="n"><v>4250.75</v></c>'));
    });

    final cpkInput = WorkbookInput(
      method: 'cpk',
      taxpayerName: 'Dave Smith',
      abn: '51 824 753 556',
      rego: 'CPK-999',
      fy: '2026',
      openingOdometer: 10000,
      closingOdometer: 14500,
      ratePerKm: 0.88,
      deductibleClaim: 3960.0,
      trips: [
        Trip(
          id: 't-1',
          vehicleId: 'v1',
          date: DateTime(2026, 8, 1),
          distanceKm: 45.0,
          purpose: 'Plumbing callout',
          classification: TripClassification.business,
          startOdometer: 10000,
          endOdometer: 10045,
        ),
      ],
    );

    final logbookInput = WorkbookInput(
      method: 'logbook',
      taxpayerName: 'Sarah Connor',
      abn: '12 345 678 901',
      rego: 'LOG-888',
      fy: '2026',
      openingOdometer: 50000,
      closingOdometer: 58000,
      deductibleClaim: 4250.0,
      trips: [
        Trip(
          id: 't-2',
          vehicleId: 'v2',
          date: DateTime(2026, 8, 2),
          distanceKm: 80.0,
          purpose: 'Site inspection',
          classification: TripClassification.business,
          startOdometer: 50000,
          endOdometer: 50080,
        ),
      ],
      expenses: [
        VehicleExpense(
          id: 'exp-1',
          vehicleId: 'v2',
          date: DateTime(2026, 8, 2),
          amount: 110.0,
          category: ExpenseCategory.fuel,
        ),
      ],
    );

    test('CPK xlsx has exactly 2 worksheets', () async {
      final bytes = await OpenXmlWorkbookBuilder().build(cpkInput);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheetNames = _extractSheetNames(archive);
      expect(sheetNames, hasLength(2));
      expect(sheetNames, containsAll(['Tax Summary', 'CPK Trip Ledger']));
    });

    test('Logbook xlsx has exactly 3 worksheets', () async {
      final bytes = await OpenXmlWorkbookBuilder().build(logbookInput);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheetNames = _extractSheetNames(archive);
      expect(sheetNames, hasLength(3));
      expect(sheetNames,
          containsAll(['Tax Summary', 'Logbook Trips', 'Expenses & Receipts']));
    });

    test('xlsx bytes form a valid zip', () async {
      final bytes = await OpenXmlWorkbookBuilder().build(cpkInput);
      expect(() => ZipDecoder().decodeBytes(bytes), returnsNormally);
    });

    test('xlsx Tab 1 contains all 7 ATO required field headers', () async {
      final bytes = await OpenXmlWorkbookBuilder().build(cpkInput);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet1File = archive.findFile('xl/worksheets/sheet1.xml')!;
      final content = utf8.decode(sheet1File.content as List<int>);

      const requiredFields = [
        'taxpayerName',
        'abn',
        'vehicleRego',
        'financialYear',
        'openingOdometer',
        'closingOdometer',
        'deductibleClaim',
      ];
      for (final field in requiredFields) {
        expect(content, contains(field),
            reason: 'Tab 1 must contain required field: $field');
      }
    });
  });
}

