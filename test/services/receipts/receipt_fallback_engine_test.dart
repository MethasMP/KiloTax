import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/data/models/vehicle_expense.dart';
import 'package:kiloclaim/services/ocr/receipt_fallback_engine.dart';
import 'package:kiloclaim/services/ocr/receipt_intelligence_service.dart';
import 'package:kiloclaim/services/receipts/receipt_workflow_policy.dart';

class MockReceiptFallbackEngine implements ReceiptFallbackEngine {
  int callCount = 0;
  String? lastImagePath;
  ReceiptOcrResult? stubbedResult;
  Exception? exceptionToThrow;

  @override
  Future<ReceiptOcrResult?> parseImage(String imagePath) async {
    callCount++;
    lastImagePath = imagePath;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return stubbedResult;
  }
}

void main() {
  group('ReceiptFallbackEngine & ReceiptWorkflowPolicy integration', () {
    late MockReceiptFallbackEngine mockFallbackEngine;

    setUp(() {
      mockFallbackEngine = MockReceiptFallbackEngine();
    });

    final highConfidenceResult = ReceiptOcrResult(
      merchant: 'Bunnings Warehouse',
      amount: 154.20,
      currency: 'AUD',
      category: ExpenseCategory.toolsMaterials,
      confidence: 0.95,
      date: DateTime(2026, 11, 18),
      dateNeedsReview: false,
      hasMixedItems: false,
      evidence: const ['total:154.20', 'merchant:Bunnings Warehouse', 'tools'],
      rawText: r'BUNNINGS TOTAL AUD $154.20',
    );

    final lowConfidenceResult = ReceiptOcrResult(
      merchant: '',
      amount: 0.0,
      currency: null,
      category: ExpenseCategory.toolsMaterials,
      confidence: 0.40,
      date: DateTime(2026, 11, 18),
      dateNeedsReview: true,
      hasMixedItems: false,
      evidence: const [],
      rawText: 'CRUMPLED UNREADABLE TEXT',
    );

    final fallbackEnhancedResult = ReceiptOcrResult(
      merchant: 'Bunnings Warehouse',
      amount: 210.50,
      currency: 'AUD',
      category: ExpenseCategory.toolsMaterials,
      confidence: 0.96,
      date: DateTime(2026, 11, 18),
      dateNeedsReview: false,
      hasMixedItems: false,
      evidence: const ['tier2_vision_multimodal'],
      rawText: 'BUNNINGS 210.50',
    );

    test('isHighConfidence getter behaves correctly', () {
      expect(highConfidenceResult.isHighConfidence, isTrue);
      expect(lowConfidenceResult.isHighConfidence, isFalse);
    });

    test('skips fallback when result is high confidence', () async {
      final policy = ReceiptWorkflowPolicy(fallbackEngine: mockFallbackEngine);

      final result = await policy.processWithFallback(
        initialResult: highConfidenceResult,
        imagePath: '/path/to/receipt.jpg',
      );

      expect(mockFallbackEngine.callCount, equals(0));
      expect(result, equals(highConfidenceResult));
    });

    test('skips fallback when fallback engine is null even if low confidence', () async {
      const policy = ReceiptWorkflowPolicy(fallbackEngine: null);

      final result = await policy.processWithFallback(
        initialResult: lowConfidenceResult,
        imagePath: '/path/to/receipt.jpg',
      );

      expect(result, equals(lowConfidenceResult));
    });

    test('triggers fallback when initial result is !isHighConfidence and engine configured', () async {
      mockFallbackEngine.stubbedResult = fallbackEnhancedResult;
      final policy = ReceiptWorkflowPolicy(fallbackEngine: mockFallbackEngine);

      final result = await policy.processWithFallback(
        initialResult: lowConfidenceResult,
        imagePath: '/tmp/crumpled_receipt.jpg',
      );

      expect(mockFallbackEngine.callCount, equals(1));
      expect(mockFallbackEngine.lastImagePath, equals('/tmp/crumpled_receipt.jpg'));
      expect(result, equals(fallbackEnhancedResult));
      expect(result.amount, equals(210.50));
      expect(result.merchant, equals('Bunnings Warehouse'));
    });

    test('returns initial result if fallback engine returns null', () async {
      mockFallbackEngine.stubbedResult = null;
      final policy = ReceiptWorkflowPolicy(fallbackEngine: mockFallbackEngine);

      final result = await policy.processWithFallback(
        initialResult: lowConfidenceResult,
        imagePath: '/tmp/damaged.jpg',
      );

      expect(mockFallbackEngine.callCount, equals(1));
      expect(result, equals(lowConfidenceResult));
    });

    test('safely recovers to initial result if fallback engine throws an exception', () async {
      mockFallbackEngine.exceptionToThrow = Exception('Network timeout / API unreachable');
      final policy = ReceiptWorkflowPolicy(fallbackEngine: mockFallbackEngine);

      final result = await policy.processWithFallback(
        initialResult: lowConfidenceResult,
        imagePath: '/tmp/damaged.jpg',
      );

      expect(mockFallbackEngine.callCount, equals(1));
      expect(result, equals(lowConfidenceResult));
    });
  });
}
