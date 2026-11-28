import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiloclaim/services/scanner/document_scanner_service.dart';

class _UnavailableCamera extends ImagePicker {
  @override
  Future<XFile?> pickImage(
      {required ImageSource source,
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      bool requestFullMetadata = true}) async {
    throw PlatformException(code: 'camera_access_denied');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cunning_document_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Native cancellation remains distinct from capture failure', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(
        await DocumentScannerService(
                reportCaptureErrors: true, picker: _UnavailableCamera())
            .scanBatchDocuments(),
        isEmpty);
  });

  test('Scanner can report failure after native and fallback cameras fail',
      () async {
    messenger.setMockMethodCallHandler(channel,
        (_) async => throw PlatformException(code: 'camera_access_denied'));
    await expectLater(
        DocumentScannerService(
                reportCaptureErrors: true, picker: _UnavailableCamera())
            .scanBatchDocuments(),
        throwsStateError);
    expect(
        await DocumentScannerService(picker: _UnavailableCamera())
            .scanBatchDocuments(),
        isEmpty);
  });
}
