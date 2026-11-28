import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PackSavePicker extends FilePickerPlatform {
  Uri? result = Uri.parse('content://test/pack.zip');
  Uint8List? savedBytes;
  String? savedName;
  String? savedMime;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedBytes = bytes;
    savedName = fileName;
    savedMime = mimeType;
    return result;
  }
}
