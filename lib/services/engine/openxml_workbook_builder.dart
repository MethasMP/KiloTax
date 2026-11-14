import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Represents a single cell in an Excel sheet.
class ExcelCell {
  final dynamic value;
  final bool isNumber;

  const ExcelCell.text(String text)
      : value = text,
        isNumber = false;

  const ExcelCell.number(num number)
      : value = number,
        isNumber = true;

  factory ExcelCell.auto(dynamic val) {
    if (val == null) return const ExcelCell.text('');
    if (val is num) return ExcelCell.number(val);
    final str = val.toString();
    final parsed = num.tryParse(str);
    if (parsed != null && !str.startsWith('0') && str.trim().isNotEmpty) {
      return ExcelCell.number(parsed);
    }
    return ExcelCell.text(str);
  }
}

/// Represents a worksheet with a title and rows of cells.
class ExcelSheet {
  final String title;
  final List<List<ExcelCell>> rows = [];

  ExcelSheet(this.title);

  void addRow(List<dynamic> cells) {
    rows.add(cells.map((c) => c is ExcelCell ? c : ExcelCell.auto(c)).toList());
  }
}

/// Lightweight, zero-dependency OpenXML (.xlsx) Workbook Generator.
/// Creates fully compliant multi-tab Excel workbooks natively readable by
/// Microsoft Excel, Google Sheets, Apple Numbers, and LibreOffice.
class OpenXmlWorkbookBuilder {
  final List<ExcelSheet> _sheets = [];

  ExcelSheet addSheet(String title) {
    // Excel sheet names max 31 chars and cannot contain: \ / ? * [ ] :
    final safeTitle = title.replaceAll(RegExp(r'[\/\\\?\*\[\]:]'), '_').trim();
    final truncatedTitle =
        safeTitle.length > 31 ? safeTitle.substring(0, 31) : safeTitle;
    final sheet = ExcelSheet(
        truncatedTitle.isEmpty ? 'Sheet${_sheets.length + 1}' : truncatedTitle);
    _sheets.add(sheet);
    return sheet;
  }

  static final RegExp _illegalXmlChars =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

  static String _escapeXml(String input) {
    return input
        .replaceAll(_illegalXmlChars, '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _colName(int colIndex) {
    var dividend = colIndex + 1;
    var columnName = '';
    while (dividend > 0) {
      final modulo = (dividend - 1) % 26;
      columnName = String.fromCharCode(65 + modulo) + columnName;
      dividend = (dividend - modulo) ~/ 26;
    }
    return columnName;
  }

  Uint8List buildBytes() {
    if (_sheets.isEmpty) {
      addSheet('Sheet1');
    }

    final archive = Archive();

    // 1. [Content_Types].xml
    final ctBuffer = StringBuffer();
    ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ctBuffer.writeln(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    ctBuffer.writeln(
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    ctBuffer
        .writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    ctBuffer.writeln(
        '  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>');
    for (var i = 1; i <= _sheets.length; i++) {
      ctBuffer.writeln(
          '  <Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    ctBuffer.writeln(
        '  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');
    ctBuffer.writeln('</Types>');
    final ctBytes = utf8.encode(ctBuffer.toString());
    archive
        .addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    // 2. _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
        '</Relationships>';
    final rootRelsBytes = utf8.encode(rootRels);
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. xl/_rels/workbook.xml.rels
    final wbRelsBuffer = StringBuffer();
    wbRelsBuffer
        .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    wbRelsBuffer.writeln(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 1; i <= _sheets.length; i++) {
      wbRelsBuffer.writeln(
          '  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>');
    }
    final styleRelId = _sheets.length + 1;
    wbRelsBuffer.writeln(
        '  <Relationship Id="rId$styleRelId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    wbRelsBuffer.writeln('</Relationships>');
    final wbRelsBytes = utf8.encode(wbRelsBuffer.toString());
    archive.addFile(ArchiveFile(
        'xl/_rels/workbook.xml.rels', wbRelsBytes.length, wbRelsBytes));

    // 4. xl/workbook.xml
    final wbBuffer = StringBuffer();
    wbBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    wbBuffer.writeln(
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    wbBuffer.writeln('  <sheets>');
    for (var i = 0; i < _sheets.length; i++) {
      final sheetId = i + 1;
      final safeName = _escapeXml(_sheets[i].title);
      wbBuffer.writeln(
          '    <sheet name="$safeName" sheetId="$sheetId" r:id="rId$sheetId"/>');
    }
    wbBuffer.writeln('  </sheets>');
    wbBuffer.writeln('</workbook>');
    final wbBytes = utf8.encode(wbBuffer.toString());
    archive.addFile(ArchiveFile('xl/workbook.xml', wbBytes.length, wbBytes));

    // 5. xl/styles.xml
    const stylesXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n'
        '  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>\n'
        '  <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>\n'
        '  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>\n'
        '  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\n'
        '  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>\n'
        '</styleSheet>';
    final stylesBytes = utf8.encode(stylesXml);
    archive
        .addFile(ArchiveFile('xl/styles.xml', stylesBytes.length, stylesBytes));

    // 6. xl/worksheets/sheetN.xml
    for (var i = 0; i < _sheets.length; i++) {
      final sheet = _sheets[i];
      final sheetNum = i + 1;
      final sBuffer = StringBuffer();
      sBuffer
          .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      sBuffer.writeln(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
      sBuffer.writeln('  <sheetData>');
      for (var r = 0; r < sheet.rows.length; r++) {
        final rowNum = r + 1;
        final row = sheet.rows[r];
        sBuffer.writeln('    <row r="$rowNum">');
        for (var c = 0; c < row.length; c++) {
          final cell = row[c];
          final ref = '${_colName(c)}$rowNum';
          if (cell.isNumber) {
            sBuffer.writeln('      <c r="$ref" t="n"><v>${cell.value}</v></c>');
          } else {
            final val = _escapeXml(cell.value.toString());
            sBuffer.writeln(
                '      <c r="$ref" t="inlineStr"><is><t>$val</t></is></c>');
          }
        }
        sBuffer.writeln('    </row>');
      }
      sBuffer.writeln('  </sheetData>');
      sBuffer.writeln('</worksheet>');
      final sheetBytes = utf8.encode(sBuffer.toString());
      archive.addFile(ArchiveFile(
          'xl/worksheets/sheet$sheetNum.xml', sheetBytes.length, sheetBytes));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }
}
