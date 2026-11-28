import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiloclaim/services/feedback/feedback_draft.dart';
import 'package:kiloclaim/ui/screens/feedback/feedback_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mailChannel = MethodChannel('flutter_email_sender');
  final drafts = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    drafts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mailChannel, (call) async {
      drafts.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mailChannel, null);
  });

  testWidgets('preview and save stay local until explicit email action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FeedbackScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'I could not find my receipt.');
    await tester.tap(find.text('Preview feedback'));
    await tester.pumpAndSettle();
    expect(find.textContaining('I could not find my receipt.'), findsWidgets);
    expect(drafts, isEmpty);
    await tester.tap(find.text('Back to editing'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save on this phone'));
    await tester.tap(find.text('Save on this phone'));
    await tester.pumpAndSettle();
    expect(
        (await FeedbackDraftStore.load()).note, 'I could not find my receipt.');
    expect(drafts, isEmpty);

    await tester.ensureVisible(find.text('Preview feedback'));
    await tester.tap(find.text('Preview feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open email draft'));
    await tester.pumpAndSettle();
    expect(drafts.length, 1);
    final args = drafts.single.arguments as Map;
    expect(args['recipients'], ['methaspak@gmail.com']);
    expect(args['body'], contains('I could not find my receipt.'));
    expect(args['attachment_paths'], isEmpty);
    expect(find.text('Feedback saved on this phone.'), findsOneWidget);
  });

  testWidgets('restores a saved draft at large text without overflow',
      (tester) async {
    await FeedbackDraftStore.save(const FeedbackDraft(
      topic: FeedbackTopic.accountantRequest,
      outcome: HandoffOutcome.moreInformation,
      note: 'Please include an expense index.',
    ));
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.8)),
        child: child!,
      ),
      home: const FeedbackScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Please include an expense index.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(drafts, isEmpty);
  });
}
