import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/engine/tax_email_dispatch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final calls = <MethodCall>[];
  const channel = MethodChannel('flutter_email_sender');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tax-mail-test-');
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  Future<EmailDispatchResult> dispatch(List<String> paths) =>
      TaxEmailDispatchService.dispatchTaxPackEmail(
          attachmentPaths: paths,
          subject: 'Review records',
          body: 'Package attached');

  test('hands every requested nonempty attachment to the native composer',
      () async {
    final file =
        await File('${temp.path}/pack.zip').writeAsBytes([80, 75, 3, 4]);
    expect(await dispatch([file.path]), EmailDispatchResult.sentViaMailApp);
    expect(calls.single.method, 'send');
    expect(calls.single.arguments['attachment_paths'], [file.path]);
    expect(calls.single.arguments['subject'], 'Review records');
  });

  test(
      'does not open a composer with missing, empty, or silently dropped attachments',
      () async {
    final valid =
        await File('${temp.path}/valid.zip').writeAsString('nonempty');
    final empty = await File('${temp.path}/empty.zip').writeAsString('');
    for (final paths in <List<String>>[
      [],
      [empty.path],
      [valid.path, '${temp.path}/missing.zip'],
    ]) {
      expect(await dispatch(paths), EmailDispatchResult.failed);
    }
    expect(calls, isEmpty);
  });
}
