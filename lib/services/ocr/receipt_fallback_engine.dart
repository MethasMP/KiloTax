import 'receipt_intelligence_service.dart';

/// Tier-2 Multimodal Vision LLM Fallback Engine contract.
///
/// Invoked when local Tier-1 on-device OCR/heuristic confidence fails or is low
/// (e.g. damaged, crumpled, or complex receipts).
abstract class ReceiptFallbackEngine {
  /// Asynchronously parses a receipt image file located at [imagePath]
  /// using a multimodal vision model.
  ///
  /// Returns a [ReceiptOcrResult] if parsing succeeds, or `null` if unable to parse.
  Future<ReceiptOcrResult?> parseImage(String imagePath);
}
