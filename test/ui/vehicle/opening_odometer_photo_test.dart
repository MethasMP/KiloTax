import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiloclaim/data/models/vehicle.dart';
import 'package:kiloclaim/ui/screens/vehicle/vehicle_setup_flow.dart';

class MockImagePicker extends Fake implements ImagePicker {
  final XFile? returnedFile;
  bool pickImageCalled = false;

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
    return returnedFile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'VehicleSetupFlow displays photo proof button and attaches SHA-256 evidence',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockPhotoPath = 'mock_odometer_proof.jpg';
    final mockBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final mockPicker = MockImagePicker(
      returnedFile: XFile.fromData(mockBytes, path: mockPhotoPath),
    );
    Vehicle? createdVehicle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleSetupFlow(
            initialStage: VehicleSetupStage.confirmVehicle,
            includeBluetoothSetup: false,
            imagePicker: mockPicker,
            onVehicleCreated: (v) {
              createdVehicle = v;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify "Add odometer photo proof" button is visible
    final addPhotoButton = find.byKey(const Key('add_odometer_photo_button'));
    await tester.ensureVisible(addPhotoButton);
    expect(addPhotoButton, findsOneWidget);
    expect(find.byKey(const Key('odometer_photo_attached_card')), findsNothing);

    // 2. Tap photo button
    await tester.tap(addPhotoButton);
    await tester.pumpAndSettle();

    expect(mockPicker.pickImageCalled, isTrue);

    // 3. Verify attached card is now displayed with SHA-256
    final attachedCard = find.byKey(const Key('odometer_photo_attached_card'));
    await tester.ensureVisible(attachedCard);
    expect(attachedCard, findsOneWidget);
    expect(find.text('Photo Proof Attached'), findsOneWidget);
    expect(find.textContaining('SHA-256:'), findsOneWidget);

    // 4. Fill in required rego and odometer
    final regoField = find.byType(TextField).first;
    await tester.ensureVisible(regoField);
    await tester.enterText(regoField, 'TEST123');
    final odoField = find.byType(TextField).at(1);
    await tester.ensureVisible(odoField);
    await tester.enterText(odoField, '45000');
    await tester.pumpAndSettle();

    // 5. Tap "Save & Continue" to advance to Tax Method
    final saveButton = find.text('Save & Continue');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 6. Explicitly select the method before saving.
    await tester.tap(find.text('Logbook Method'));
    await tester.pumpAndSettle();
    final saveVehicleButton = find.text('Save vehicle');
    expect(saveVehicleButton, findsOneWidget);
    await tester.tap(saveVehicleButton);
    await tester.pumpAndSettle();

    // 7. Verify vehicle was created with photo proof fields
    expect(createdVehicle, isNotNull);
    expect(createdVehicle!.startOdometerPhotoPath, equals(mockPhotoPath));
    expect(createdVehicle!.startOdometerImageHash, isNotNull);
    expect(createdVehicle!.startOdometerImageHash!.length, equals(64));
    expect(createdVehicle!.startOdometerVerifiedAt, isNotNull);
  });
}
