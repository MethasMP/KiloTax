import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kilotax/services/engine/openxml_workbook_builder.dart';

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
  });
}
