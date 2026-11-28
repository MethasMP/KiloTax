import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/feedback/feedback_draft.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
      );

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _note = TextEditingController();
  FeedbackTopic _topic = FeedbackTopic.other;
  HandoffOutcome _outcome = HandoffOutcome.notShared;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final draft = await FeedbackDraftStore.load();
      if (!mounted) return;
      setState(() {
        _topic = draft.topic;
        _outcome = draft.outcome;
        _note.text = draft.note;
      });
    } catch (_) {
      if (mounted) _notify('Could not load your saved feedback.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  FeedbackDraft get _draft => FeedbackDraft(
        topic: _topic,
        outcome: _outcome,
        note: _note.text,
      );

  void _notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FeedbackDraftStore.save(_draft);
      if (mounted) _notify('Feedback saved on this phone.');
    } catch (_) {
      if (mounted) _notify('Could not save feedback. Your text is still here.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    final draft = _draft;
    final share = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview feedback'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(draft.message),
              const SizedBox(height: 16),
              const Text(
                'Recipient: methaspak@gmail.com. Your email account may identify you. Remove personal details from your note before sharing.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back to editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open email draft'),
          ),
        ],
      ),
    );
    if (share != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await FeedbackDraftStore.save(draft);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      try {
        await FlutterEmailSender.send(Email(
          recipients: const ['methaspak@gmail.com'],
          subject: 'KiloClaim product feedback',
          body: draft.message,
          attachmentPaths: const [],
        ));
      } catch (_) {
        await SharePlus.instance.share(ShareParams(
          subject: 'KiloClaim product feedback',
          text: draft.message,
          sharePositionOrigin: origin,
        ));
      }
      if (mounted) _notify('Feedback saved on this phone.');
    } catch (_) {
      if (mounted) {
        _notify('Could not prepare feedback. Your text is still here.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Product feedback')),
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tell us what got in the way',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Feedback is optional. Save a draft on this phone or preview it before you choose to share. No records are attached.',
                      ),
                      const SizedBox(height: 24),
                      const Text('What was difficult?'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<FeedbackTopic>(
                        initialValue: _topic,
                        isExpanded: true,
                        items: [
                          for (final topic in FeedbackTopic.values)
                            DropdownMenuItem(
                              value: topic,
                              child: Text(topic.label,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _topic = value!),
                      ),
                      const SizedBox(height: 20),
                      const Text('If you shared records with your accountant'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<HandoffOutcome>(
                        initialValue: _outcome,
                        isExpanded: true,
                        items: [
                          for (final outcome in HandoffOutcome.values)
                            DropdownMenuItem(
                              value: outcome,
                              child: Text(outcome.label,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _outcome = value!),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _note,
                        enabled: !_saving,
                        minLines: 3,
                        maxLines: 7,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'What would help?',
                          hintText:
                              'Leave out names, addresses and tax details.',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _preview,
                        child: const Text('Preview feedback'),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _save,
                        child: const Text('Save on this phone'),
                      ),
                    ],
                  ),
                ),
              ),
      );
}
