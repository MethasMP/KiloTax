import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

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

class PaddleReceiptOcrEngine implements ReceiptOcrEngine {
  final Uri endpoint;
  final String token;
  final Duration timeout;
  final http.Client? client;
  static const maxImageBytes = 12 * 1024 * 1024;
  PaddleReceiptOcrEngine(
      {required this.endpoint,
      this.token = '',
      this.timeout = const Duration(seconds: 90),
      this.client}) {
    if (!['http', 'https'].contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment) {
      throw ArgumentError(
          'Configure a full HTTP(S) PaddleOCR endpoint without credentials or fragment');
    }
    if (endpoint.scheme != 'https' &&
        !['localhost', '127.0.0.1', '::1'].contains(endpoint.host)) {
      throw ArgumentError('Remote PaddleOCR endpoints require HTTPS');
    }
  }

  @override
  Future<ReceiptOcrExtraction> recognizeFile(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size == 0 || size > maxImageBytes) {
      throw const FormatException('OCR image must be 1 byte to 12 MiB');
    }
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .post(endpoint,
              headers: {
                'Content-Type': 'application/octet-stream',
                if (token.isNotEmpty) 'Authorization': 'Bearer $token'
              },
              body: await file.readAsBytes())
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw HttpException('PaddleOCR failed (HTTP ${response.statusCode})');
      }
      if (response.bodyBytes.length > 4 * 1024 * 1024) {
        throw const FormatException('OCR response too large');
      }
      return parseResponse(jsonDecode(utf8.decode(response.bodyBytes)));
    } finally {
      if (client == null) transport.close();
    }
  }

  static ReceiptOcrExtraction parseResponse(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['engine'] != 'paddleocr' ||
        value['version'] is! String ||
        (value['version'] as String).isEmpty ||
        value['text'] is! String ||
        value['blocks'] is! List ||
        value['extractedAt'] is! String) {
      throw const FormatException('Invalid PaddleOCR response');
    }
    final extractedAt = DateTime.tryParse(value['extractedAt']);
    if (extractedAt == null) {
      throw const FormatException('Invalid extraction time');
    }
    final blocks = <ReceiptOcrBlock>[];
    for (final block in value['blocks']) {
      if (block is! Map ||
          block['page'] is! int ||
          block['page'] < 1 ||
          block['text'] is! String ||
          block['bounds'] is! List ||
          block['bounds'].length != 4) {
        throw const FormatException('Invalid OCR block');
      }
      final bounds = <double>[];
      for (final coordinate in block['bounds']) {
        if (coordinate is! num || !coordinate.isFinite || coordinate < 0) {
          throw const FormatException('Invalid OCR bounds');
        }
        bounds.add(coordinate.toDouble());
      }
      if (bounds[2] < bounds[0] || bounds[3] < bounds[1]) {
        throw const FormatException('Inverted OCR bounds');
      }
      final score = block['score'];
      if (score != null &&
          (score is! num || !score.isFinite || score < 0 || score > 1)) {
        throw const FormatException('Invalid OCR score');
      }
      blocks.add(ReceiptOcrBlock(
          page: block['page'],
          text: block['text'],
          bounds: bounds,
          score: (score as num?)?.toDouble()));
    }
    return ReceiptOcrExtraction(
        text: ReceiptReadingOrder.assemble(blocks,
            fallback: value['text'] as String),
        blocks: blocks,
        engine: value['engine'],
        version: value['version'],
        extractedAt: extractedAt.toUtc());
  }
}

class ReceiptOcrEngineFactory {
  /// Calling with usePaddle:true must follow a user action consenting to upload.
  static ReceiptOcrEngine create(
      {bool usePaddle = false,
      String endpoint = const String.fromEnvironment('PADDLE_OCR_URL'),
      String token = const String.fromEnvironment('PADDLE_OCR_TOKEN')}) {
    if (!usePaddle) return MlKitReceiptOcrEngine();
    if (endpoint.trim().isEmpty) {
      throw StateError('PaddleOCR is not configured; no image was uploaded');
    }
    return PaddleReceiptOcrEngine(endpoint: Uri.parse(endpoint), token: token);
  }
}
