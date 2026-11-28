import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrBlock {
  final int page;
  final String text;

  /// Pixel coordinates: left, top, right, bottom.
  final List<double> bounds;
  final double? score;
  ReceiptOcrBlock(
      {required this.page,
      required this.text,
      required List<double> bounds,
      this.score})
      : bounds = List.unmodifiable(bounds);
}

/// Rejoins receipt columns by page and visual row before interpreting amounts.
/// Providers pass individual text lines, never a multi-line paragraph box.
class ReceiptReadingOrder {
  static String assemble(List<ReceiptOcrBlock> blocks, {String fallback = ''}) {
    if (blocks.isEmpty) return fallback;
    final sorted = [...blocks]..sort((a, b) {
        final page = a.page.compareTo(b.page);
        if (page != 0) return page;
        return ((a.bounds[1] + a.bounds[3]) / 2)
            .compareTo((b.bounds[1] + b.bounds[3]) / 2);
      });
    final rows = <List<ReceiptOcrBlock>>[];
    for (final block in sorted) {
      final center = (block.bounds[1] + block.bounds[3]) / 2;
      final height = (block.bounds[3] - block.bounds[1]).abs();
      List<ReceiptOcrBlock>? match;
      if (rows.isNotEmpty) {
        final anchor = rows.last.first;
        final anchorCenter = (anchor.bounds[1] + anchor.bounds[3]) / 2;
        final anchorHeight = (anchor.bounds[3] - anchor.bounds[1]).abs();
        final tolerance =
            (height < anchorHeight ? height : anchorHeight) * 0.45;
        if (block.page == anchor.page &&
            (center - anchorCenter).abs() <= tolerance) {
          match = rows.last;
        }
      }
      if (match == null) {
        rows.add([block]);
      } else {
        match.add(block);
      }
    }
    return rows.map((row) {
      row.sort((a, b) => a.bounds[0].compareTo(b.bounds[0]));
      return row.map((b) => b.text).join('  ');
    }).join('\n');
  }
}

class ReceiptOcrExtraction {
  final String text;
  final List<ReceiptOcrBlock> blocks;
  final String engine;
  final String version;
  final DateTime extractedAt;
  ReceiptOcrExtraction(
      {required this.text,
      required List<ReceiptOcrBlock> blocks,
      required this.engine,
      required this.version,
      required this.extractedAt})
      : blocks = List.unmodifiable(blocks);
}

abstract class ReceiptOcrEngine {
  Future<ReceiptOcrExtraction> recognizeFile(String path);
}

class MlKitReceiptOcrEngine implements ReceiptOcrEngine {
  @override
  Future<ReceiptOcrExtraction> recognizeFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      final blocks = result.blocks.expand((block) => block.lines).map((line) {
        final rect = line.boundingBox;
        return ReceiptOcrBlock(
            page: 1,
            text: line.text,
            bounds: [rect.left, rect.top, rect.right, rect.bottom]);
      }).toList();
      return ReceiptOcrExtraction(
          text: ReceiptReadingOrder.assemble(blocks, fallback: result.text),
          blocks: blocks,
          engine: 'mlkit',
          version:
              'google_mlkit_text_recognition/0.17.1;native-version-unreported;reading-order/1',
          extractedAt: DateTime.now().toUtc());
    } finally {
      await recognizer.close();
    }
  }
}

class ReceiptOcrEngineFactory {
  static ReceiptOcrEngine create() {
    return MlKitReceiptOcrEngine();
  }
}
