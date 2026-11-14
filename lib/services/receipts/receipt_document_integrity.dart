import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';

class ReceiptDocumentIntegrity {
  static Future<List<String>> inspect(List<String> paths,
      {List<String>? expectedHashes}) async {
    if (paths.isEmpty) {
      throw const FormatException(
          'Attach the receipt pages before confirming.');
    }
    final hashes = <String>[];
    for (var i = 0; i < paths.length; i++) {
      final bytes = await File(paths[i]).readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (expectedHashes != null &&
          i < expectedHashes.length &&
          expectedHashes[i] != hash) {
        throw const FormatException(
            'A receipt page changed after reading. Read and review it again.');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final valid = frame.image.width > 0 && frame.image.height > 0;
        frame.image.dispose();
        if (!valid) {
          throw const FormatException('A receipt page cannot be read.');
        }
      } finally {
        codec.dispose();
      }
      hashes.add(hash);
    }
    return hashes;
  }
}
