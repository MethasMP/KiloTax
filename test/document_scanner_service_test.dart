import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilotax/services/scanner/document_scanner_service.dart';

class MockImagePicker extends Fake implements ImagePicker {
  final XFile? returnedFile;
  bool pickImageCalled = false;
  ImageSource? lastSource;

  MockImagePicker({this.returnedFile});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCalled = true;
    lastSource = source;
    return returnedFile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentScannerService Resilience & Failsafe Tests', () {
    test('Falls back cleanly to ImagePicker camera when native scanner throws', () async {
      final mockPicker = MockImagePicker(
        returnedFile: XFile('/mock/path/receipt.jpg'),
      );

      final service = DocumentScannerService(picker: mockPicker);

      // In unit test environment without mock method channel for CunningDocumentScanner,
      // it throws MissingPluginException or PlatformException, which triggers fallback.
      final result = await service.scanDocument(allowFallbackToCamera: true);

      expect(mockPicker.pickImageCalled, isTrue);
      expect(mockPicker.lastSource, equals(ImageSource.camera));
      expect(result, equals('/mock/path/receipt.jpg'));
    });

    test('pickFromGallery invokes gallery source reliably', () async {
      final mockPicker = MockImagePicker(
        returnedFile: XFile('/mock/path/gallery_receipt.jpg'),
      );

      final service = DocumentScannerService(picker: mockPicker);
      final result = await service.pickFromGallery();

      expect(mockPicker.pickImageCalled, isTrue);
      expect(mockPicker.lastSource, equals(ImageSource.gallery));
      expect(result, equals('/mock/path/gallery_receipt.jpg'));
    });

    test('Returns null when user cancels camera fallback', () async {
      final mockPicker = MockImagePicker(returnedFile: null);
      final service = DocumentScannerService(picker: mockPicker);

      final result = await service.scanDocument(allowFallbackToCamera: true);

      expect(mockPicker.pickImageCalled, isTrue);
      expect(result, isNull);
    });
  });
}
