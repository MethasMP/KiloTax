import 'dart:convert';
import 'dart:io';
import 'package:kilotax/data/models/vehicle_expense.dart';
import 'package:kilotax/services/ocr/receipt_intelligence_service.dart';
import 'package:kilotax/services/receipts/receipt_workflow_policy.dart';
import 'package:kilotax/services/ocr/receipt_ocr_engine.dart';

/// Parses saved real engine outputs using the same app rules, without native plugins.
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'Usage: dart run tool/paddle_ocr/parse_extractions.dart manifest.json predictions.json');
    exitCode = 64;
    return;
  }
  final manifestFile = File(args[0]);
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map;
  final predictions = <Map<String, dynamic>>[];
  for (final fixture in manifest['fixtures'] as List) {
    for (final engine in ['paddle', 'mlkit']) {
      final imageName = fixture['image'] as String;
      final extractionFile = File(
          '${manifestFile.parent.path}/${imageName.replaceFirst(RegExp(r'\.[^.]+$'), '')}.$engine.json');
      if (!extractionFile.existsSync()) continue;
      final extraction = jsonDecode(extractionFile.readAsStringSync()) as Map;
      final blocks = (extraction['blocks'] as List? ?? [])
          .map((b) => ReceiptOcrBlock(
              page: b['page'] as int,
              text: b['text'] as String,
              bounds: (b['bounds'] as List)
                  .map((n) => (n as num).toDouble())
                  .toList()))
          .toList();
      final result = const ReceiptIntelligenceService().analyseText(
          ReceiptReadingOrder.assemble(blocks,
              fallback: extraction['text'] as String));
      final expense = VehicleExpense(
          id: fixture['id'],
          vehicleId: 'benchmark',
          amount: result.amount,
          category: result.category,
          date: result.date,
          supplier: result.merchant,
          gstAmount: result.gstAmount,
          currency: result.currency,
          supplierAbn: result.abn,
          receiptAudit: ReceiptAuditTrail(
              reviewStatus: ReceiptReviewStatus.needsReview,
              capturedAt: DateTime.now(),
              rawOcrText: result.rawText));
      final issues = const ReceiptWorkflowPolicy()
          .reviewIssues(expense, purchaseDateUnknown: result.dateNeedsReview);
      predictions.add({
        'id': fixture['id'],
        'engine': extraction['engine'] ?? engine,
        'fields': {
          'merchant': result.merchant,
          'amount': result.amount,
          'gstAmount': result.gstAmount,
          'currency': result.currency,
          'date': result.dateNeedsReview
              ? null
              : result.date.toIso8601String().split('T').first,
          'abn': result.abn?.replaceAll(RegExp(r'\D'), '')
        },
        'ready': issues.isEmpty,
        'reviewReasons': issues
      });
    }
  }
  File(args[1]).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(predictions));
}
