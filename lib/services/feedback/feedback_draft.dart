import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FeedbackTopic {
  missedTrip('A missed trip'),
  classification('Business or personal classification'),
  purpose('Trip purpose'),
  receipt('Receipts'),
  export('Exporting records'),
  accountantRequest('Information requested by my accountant'),
  other('Something else');

  const FeedbackTopic(this.label);
  final String label;
}

enum HandoffOutcome {
  notShared('Not shared yet'),
  waiting('Waiting for a response'),
  noMoreInformation('No extra information requested'),
  moreInformation('More information requested');

  const HandoffOutcome(this.label);
  final String label;
}

class FeedbackDraft {
  final FeedbackTopic topic;
  final HandoffOutcome outcome;
  final String note;

  const FeedbackDraft({
    this.topic = FeedbackTopic.other,
    this.outcome = HandoffOutcome.notShared,
    this.note = '',
  });

  String get message => '''KiloClaim product feedback
Topic: ${topic.label}
Accountant handoff: ${outcome.label}

${note.trim().isEmpty ? 'No additional note.' : note.trim()}

No trip records, locations, or receipt images are attached.''';

  Map<String, String> toJson() => {
        'topic': topic.name,
        'outcome': outcome.name,
        'note': note.length > 1000 ? note.substring(0, 1000) : note,
      };

  factory FeedbackDraft.fromJson(Map<String, dynamic> json) => FeedbackDraft(
        topic: FeedbackTopic.values.firstWhere(
          (value) => value.name == json['topic'],
          orElse: () => FeedbackTopic.other,
        ),
        outcome: HandoffOutcome.values.firstWhere(
          (value) => value.name == json['outcome'],
          orElse: () => HandoffOutcome.notShared,
        ),
        note: json['note'] is String
            ? (json['note'] as String)
                .substring(0, (json['note'] as String).length.clamp(0, 1000))
            : '',
      );
}

class FeedbackDraftStore {
  static const _key = 'product_feedback_draft_v1';

  static Future<void> save(FeedbackDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, jsonEncode(draft.toJson()));
    if (!saved) throw StateError('Could not save feedback draft');
  }

  static Future<FeedbackDraft> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) return const FeedbackDraft();
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? FeedbackDraft.fromJson(decoded)
          : const FeedbackDraft();
    } on FormatException {
      return const FeedbackDraft();
    }
  }
}
