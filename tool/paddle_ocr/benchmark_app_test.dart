import 'package:flutter_test/flutter_test.dart';
import 'parse_extractions.dart' as runner;

void main() {
  test('score saved engine extractions using application rules', () {
    runner.main([
      'tool/paddle_ocr/fixtures/manifest.json',
      'tool/paddle_ocr/predictions.json'
    ]);
  });
}
