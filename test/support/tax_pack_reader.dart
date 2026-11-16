import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class TaxPackReader {
  final Archive archive;
  late final Archive workbook = ZipDecoder()
      .decodeBytes(archive.findFile('Details.xlsx')!.content as List<int>);

  TaxPackReader(this.archive);

  Map<String, dynamic> get metadata => jsonDecode(utf8.decode(archive
      .findFile('Supporting/record-history.json')!
      .content as List<int>)) as Map<String, dynamic>;

  List<String> get sheetNames => XmlDocument.parse(utf8
          .decode(workbook.findFile('xl/workbook.xml')!.content as List<int>))
      .findAllElements('sheet')
      .map((sheet) => sheet.getAttribute('name')!)
      .toList();

  String sheetXml(String title) => utf8.decode(workbook
      .findFile('xl/worksheets/sheet${sheetNames.indexOf(title) + 1}.xml')!
      .content as List<int>);

  List<String> hyperlinkTargets(String title) {
    final file = workbook.findFile(
        'xl/worksheets/_rels/sheet${sheetNames.indexOf(title) + 1}.xml.rels');
    if (file == null) return [];
    return XmlDocument.parse(utf8.decode(file.content as List<int>))
        .findAllElements('Relationship')
        .map((link) => link.getAttribute('Target')!)
        .toList();
  }

  List<Map<String, Object?>> rows(String title) {
    final rows = XmlDocument.parse(sheetXml(title))
        .findAllElements('row')
        .map((row) => row.findElements('c').map((cell) {
              if (cell.getAttribute('t') == 'n') {
                return num.parse(cell.findElements('v').single.innerText);
              }
              return cell
                  .findAllElements('t')
                  .map((text) => text.innerText)
                  .join();
            }).toList())
        .toList();
    final headers = rows.first.map((cell) => cell.toString()).toList();
    return rows
        .skip(1)
        .map((row) => <String, Object?>{
              for (var index = 0; index < headers.length; index++)
                headers[index]: index < row.length ? row[index] : null,
            })
        .toList();
  }

  Object? summaryValue(String label) => rows('Summary')
      .singleWhere((row) => row['Field'] == label)['Recorded value'];

  String get searchableText => [
        jsonEncode(metadata),
        ...workbook.files
            .where((file) => file.name.endsWith('.xml'))
            .map((file) => utf8.decode(file.content as List<int>)),
      ].join('\n');
}
