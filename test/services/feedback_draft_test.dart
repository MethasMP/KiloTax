import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilotax/services/feedback/feedback_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved draft round-trips without collecting record data', () async {
    const draft = FeedbackDraft(
      topic: FeedbackTopic.receipt,
      outcome: HandoffOutcome.moreInformation,
      note: 'The receipt index was hard to follow.',
    );
    await FeedbackDraftStore.save(draft);
    final restored = await FeedbackDraftStore.load();
    expect(restored.topic, FeedbackTopic.receipt);
    expect(restored.outcome, HandoffOutcome.moreInformation);
    expect(restored.note, 'The receipt index was hard to follow.');
    expect(restored.message, '''KiloTax product feedback
Topic: Receipts
Accountant handoff: More information requested

The receipt index was hard to follow.

No trip records, locations, or receipt images are attached.''');
  });

  test('corrupt saved data opens a blank draft and long notes stay bounded',
      () async {
    SharedPreferences.setMockInitialValues(
        {'product_feedback_draft_v1': '{bad'});
    final blank = await FeedbackDraftStore.load();
    expect(blank.topic, FeedbackTopic.other);
    expect(blank.outcome, HandoffOutcome.notShared);
    expect(blank.note, '');
    await FeedbackDraftStore.save(FeedbackDraft(note: 'a' * 1200));
    expect((await FeedbackDraftStore.load()).note.length, 1000);
  });

  test('unknown choice values retain user note with safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      'product_feedback_draft_v1':
          '{"topic":"future","outcome":"future","note":"Keep this note"}',
    });
    final draft = await FeedbackDraftStore.load();
    expect(draft.topic, FeedbackTopic.other);
    expect(draft.outcome, HandoffOutcome.notShared);
    expect(draft.note, 'Keep this note');
  });
}
