import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilotax/services/scanner/document_scanner_service.dart';

class MockImagePicker extends Fake implements ImagePicker {
  final XFile? returnedFile;
  final List<XFile>? returnedFiles;
  bool pickImageCalled = false;
  bool pickMultiImageCalled = false;
  ImageSource? lastSource;

  MockImagePicker({this.returnedFile, this.returnedFiles});

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

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    pickMultiImageCalled = true;
    return returnedFiles ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentScannerService Resilience & Failsafe Tests', () {
    test('Falls back cleanly to ImagePicker camera when native scanner throws',
        () async {
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

    test('scanBatchDocuments falls back to camera returning list with single image',
        () async {
      final mockPicker = MockImagePicker(
        returnedFile: XFile('/mock/path/batch_camera.jpg'),
      );
      final service = DocumentScannerService(picker: mockPicker);

      final result =
          await service.scanBatchDocuments(allowFallbackToCamera: true);

      expect(mockPicker.pickImageCalled, isTrue);
      expect(result, equals(['/mock/path/batch_camera.jpg']));
    });

    test('pickMultipleFromGallery invokes pickMultiImage and returns files',
        () async {
      final mockPicker = MockImagePicker(
        returnedFiles: [
          XFile('/mock/path/receipt1.jpg'),
          XFile('/mock/path/receipt2.jpg'),
        ],
      );
      final service = DocumentScannerService(picker: mockPicker);

      final results = await service.pickMultipleFromGallery();

      expect(mockPicker.pickMultiImageCalled, isTrue);
      expect(
        results,
        equals(['/mock/path/receipt1.jpg', '/mock/path/receipt2.jpg']),
      );
    });
  });
}
