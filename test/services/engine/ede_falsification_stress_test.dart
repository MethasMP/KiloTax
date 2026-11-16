import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trip.dart';
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/engine/openxml_workbook_builder.dart';
import 'package:kilotax/services/engine/tax_calculator_service.dart';
// ignore: depend_on_referenced_packages
import 'package:xml/xml.dart';

void main() {
  test(
      'Falsification: Divergence between calculateLogbookClaim and evaluateSummary',
      () {
    final trips = [
      Trip(
        id: 't-1',
        vehicleId: 'v-1',
        date: DateTime(2025, 7, 10),
        distanceKm: 700.0,
        purpose: 'Work',
        classification: TripClassification.business,
        taxMethod: TaxMethod.logbook,
      ),
      Trip(
        id: 't-2',
        vehicleId: 'v-1',
        date: DateTime(2025, 7, 11),
        distanceKm: 300.0,
        purpose: 'Personal',
        classification: TripClassification.personal,
        taxMethod: TaxMethod.logbook,
      ),
    ];

    final expenses = [
      VehicleExpense(
        id: 'e-fuel',
        vehicleId: 'v-1',
        date: DateTime(2025, 7, 15),
        amount: 1000.0,
        category: ExpenseCategory.fuel,
      ),
      VehicleExpense(
        id: 'e-toll',
        vehicleId: 'v-1',
        date: DateTime(2025, 8, 5),
        amount: 100.0,
        category: ExpenseCategory.tollsParking,
        businessPercentage: 100.0,
      ),
      VehicleExpense(
        id: 'e-bunnings',
        vehicleId: 'v-1',
        date: DateTime(2025, 8, 10),
        amount: 2000.0,
        category: ExpenseCategory.toolsMaterials,
      ),
    ];

    final claimViaCalc = TaxCalculatorService.calculateLogbookClaim(
      expenses: expenses,
      businessPercentage: 70.0,
    );

    final summary = TaxCalculatorService.evaluateSummary(
      trips: trips,
      expenses: expenses,
    );

    // Diagnostic check:
    // calculateLogbookClaim: (1000 + 2000) * 0.7 + 100 = 2200
    // evaluateSummary: (1000 * 0.7) + 100 + 2000 = 2800
    print('calculateLogbookClaim: $claimViaCalc');
    print('evaluateSummary.logbookClaim: ${summary.logbookClaim}');

    expect(summary.logbookClaim, equals(claimViaCalc),
        reason:
            'FALSIFIED: Invariant 2 broken! calculateLogbookClaim and evaluateSummary disagree on logbook formula!');
  });

  group('EDE Invariant 3: OpenXML Escaping and XML 1.0 Standards', () {
    test(
        'Falsification: XML escaping of special characters and quotation marks',
        () {
      final builder = OpenXmlWorkbookBuilder();
      final sheet = builder.addSheet('XML & Tests <Special>');

      sheet.addRow([
        'Tom & Jerry <Plumbing> "Fix" & \'Tools\'',
        '<script>alert("XSS")</script>',
        'A & B && C < > " \'',
        123.45,
      ]);

      final bytes = builder.buildBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final wbFile = archive.findFile('xl/workbook.xml');
      expect(wbFile, isNotNull);
      final wbXmlStr = utf8.decode(wbFile!.content as List<int>);
      expect(() => XmlDocument.parse(wbXmlStr), returnsNormally,
          reason:
              'workbook.xml must be valid XML despite special chars in sheet name');

      final s1File = archive.findFile('xl/worksheets/sheet1.xml');
      expect(s1File, isNotNull);
      final s1XmlStr = utf8.decode(s1File!.content as List<int>);
      expect(() => XmlDocument.parse(s1XmlStr), returnsNormally,
          reason:
              'sheet1.xml must be valid XML despite XML characters in cells');
    });

    test(
        'Falsification: XML 1.0 Illegal Control Characters (e.g. \\x00, \\x08, \\x1B)',
        () {
      final builder = OpenXmlWorkbookBuilder();
      final sheet = builder.addSheet('ControlChars');

      // Check whether builder prevents XML 1.0 invalid control chars:
      final hostilePayload = 'Bunnings\x00Warehouse\x08Receipt\x1b[31m';
      sheet.addRow(['Merchant', hostilePayload]);

      final bytes = builder.buildBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final s1File = archive.findFile('xl/worksheets/sheet1.xml');
      expect(s1File, isNotNull);

      final s1XmlStr = utf8.decode(s1File!.content as List<int>);

      // In XML 1.0 W3C Section 2.2, chars 0x00, 0x08, 0x1B cannot be present in XML text
      final hasRawNullOrControl = s1XmlStr.contains('\x00') ||
          s1XmlStr.contains('\x08') ||
          s1XmlStr.contains('\x1b');
      expect(hasRawNullOrControl, isFalse,
          reason:
              'FALSIFIED: OpenXML workbook builder allowed raw illegal XML 1.0 control characters in output XML!');
    });
  });
}
