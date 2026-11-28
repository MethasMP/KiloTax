import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'support/pack_save_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiloclaim/services/engine/tax_pack_dispatch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const mail = MethodChannel('flutter_email_sender');
  late Directory temp;
  late File pack;
  final calls = <MethodCall>[];
  var mailCalls = 0;
  String response = 'test.target';
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('native-pack-test');
    pack = await File('${temp.path}/pack.zip').writeAsBytes([80, 75, 3, 4]);
    calls.clear();
    mailCalls = 0;
    response = 'test.target';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, (call) async {
      calls.add(call);
      return response;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mail, (call) async {
      mailCalls++;
      return null;
    });
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mail, null);
    await temp.delete(recursive: true);
  });
  Future<TaxPackShareResult> dispatch({String? path}) =>
      TaxPackDispatchService.share(
        path: path ?? pack.path,
        subject: 'Vehicle report',
        description: 'Review this pack',
        origin: const Rect.fromLTWH(20, 40, 48, 48),
      );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('Native ZIP sharing contract on $platform bypasses mail composer',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      expect(await dispatch(), TaxPackShareResult.selected);
      expect(calls.single.method, 'share');
      expect(calls.single.arguments['paths'], [pack.path]);
      expect(calls.single.arguments['mimeTypes'], ['application/zip']);
      expect(calls.single.arguments['subject'], 'Vehicle report');
      expect(calls.single.arguments['originWidth'], 48);
      expect(mailCalls, 0);
    });
  }
  test('Dismissal and unavailable result never report delivery', () async {
    response = '';
    expect(await dispatch(), TaxPackShareResult.dismissed);
    response = 'dev.fluttercommunity.plus/share/unavailable';
    expect(await dispatch(), TaxPackShareResult.unavailable);
  });
  test('Missing or empty attachment never opens a chooser', () async {
    expect(await dispatch(path: '${temp.path}/missing.zip'),
        TaxPackShareResult.failed);
    await pack.writeAsBytes([]);
    expect(await dispatch(), TaxPackShareResult.failed);
    expect(calls, isEmpty);
    expect(mailCalls, 0);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
        'Save-copy contract preserves ZIP bytes on $platform and handles cancellation',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final original = FilePickerPlatform.instance;
      final picker = PackSavePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      expect(await TaxPackDispatchService.saveCopy(pack.path),
          TaxPackSaveResult.saved);
      expect(picker.savedBytes, [80, 75, 3, 4]);
      expect(picker.savedName, 'pack.zip');
      expect(picker.savedMime, 'application/zip');
      picker.result = null;
      expect(await TaxPackDispatchService.saveCopy(pack.path),
          TaxPackSaveResult.dismissed);
      expect(calls, isEmpty);
      expect(mailCalls, 0);
    });
  }
}
