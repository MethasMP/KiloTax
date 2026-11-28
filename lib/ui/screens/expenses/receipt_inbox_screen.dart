import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/ocr/receipt_audit_service.dart';
import '../../../services/ocr/receipt_ocr_engine.dart';
import '../../../services/receipts/receipt_inbox_service.dart';
import '../../../services/receipts/receipt_workflow_policy.dart';
import '../../../services/receipts/receipt_document_integrity.dart';
import 'expense_detail_screen.dart';
import '../../../state/app_state.dart';

class ReceiptInboxScreen extends StatefulWidget {
  final AppState appState;
  final List<String> imagePaths;
  final ReceiptInboxService? inbox;
  final ReceiptOcrEngine? engine;
  const ReceiptInboxScreen(
      {super.key,
      required this.appState,
      this.imagePaths = const [],
      this.inbox,
      this.engine});
  @override
  State<ReceiptInboxScreen> createState() => _ReceiptInboxScreenState();
}

class _ReceiptInboxScreenState extends State<ReceiptInboxScreen> {
  ReceiptInboxService? _store;
  List<ReceiptDraft> _drafts = [];
  final Set<String> _selected = {}, _pages = {};
  late final String? _vehicleId = widget.appState.primaryVehicle?.id;
  late final String _account = widget.appState.currentUser?.id ?? 'guest';
  final _policy = const ReceiptWorkflowPolicy();
  bool _busy = true;
  String _status = 'Saving receipt photos…';
  String? _error;
  int _skipped = 0;
  bool get _sameAccount =>
      (widget.appState.currentUser?.id ?? 'guest') == _account;
  void _checkAccount() {
    if (!_sameAccount) {
      throw StateError('Account changed. Reopen the receipt inbox.');
    }
  }

  bool _unknownDate(ReceiptDraft d) =>
      d.purchaseDate == null &&
      (d.sourcePath != null || d.issues.contains('Choose purchase date'));
  List<String> _issues(ReceiptDraft d, [List<ReceiptDraft>? candidates]) {
    if (!d.processed) return d.issues;
    final confidence = d.expense.receiptAudit?.ocrConfidence;
    return {
      ..._policy.reviewIssues(d.expense,
          purchaseDateUnknown: _unknownDate(d),
          extractionReviewed: d.extractionReviewed,
          duplicateReviewed: d.duplicateReviewed,
          trips: widget.appState.trips,
          others: [
            ...widget.appState.expenses,
            ...(candidates ?? _drafts).map((e) => e.expense)
          ]),
      if (confidence != null && confidence < 0.70 && !d.extractionReviewed)
        'Low OCR confidence (${(confidence * 100).round()}%) — verify merchant, date & total',
      if (d.pagePaths.length > 1 && !d.groupingReviewed)
        'Review combined pages as one receipt',
    }.toList();
  }

  Future<void> _persist(List<ReceiptDraft> next) async {
    _checkAccount();
    await _store!.save(next);
    _drafts = _store!.load().toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_vehicleId == null) {
        throw StateError('Choose a vehicle before importing receipts.');
      }
      final store =
          widget.inbox ?? await ReceiptInboxService.open(_account, _vehicleId);
      _checkAccount();
      _store = store;
      // Migrate each known legacy per-vehicle inbox into the account-wide store.
      if (widget.inbox == null) {
        for (final v in widget.appState.vehicles) {
          await ReceiptInboxService.open(_account, v.id);
        }
        await store.initialize();
      }
      // Replay only explicitly approved, revision-bound intents; IDs make replay idempotent.
      for (final e in await store.pendingCommits()) {
        _checkAccount();
        await widget.appState.saveWorkflowReceipt(e);
        await store.completeCommit(e.id);
      }
      _drafts = store.load().toList();
      await _persist(_drafts
          .where(
              (d) => !widget.appState.expenses.any((e) => e.id == d.expense.id))
          .toList());
      for (final path in widget.imagePaths) {
        _checkAccount();
        final draft = await store.retain(path, _vehicleId);
        _checkAccount();
        if (!_drafts.any((d) => d.documentId == draft.documentId) &&
            !widget.appState.expenses
                .any((e) => e.sha256Hash == draft.expense.sha256Hash)) {
          await _persist([..._drafts, draft]);
        } else {
          _skipped++;
        }
      }
      if (!mounted) return;
      await _readPending();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _readPending({String? documentId}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final engine = widget.engine ?? ReceiptOcrEngineFactory.create();
      for (var i = 0; i < _drafts.length; i++) {
        if (!mounted) return;
        _checkAccount();
        final original = _drafts[i];
        if (documentId != null
            ? original.documentId != documentId
            : original.processed) {
          continue;
        }
        setState(
            () => _status = 'Reading receipt ${i + 1} of ${_drafts.length}…');
        ReceiptDraft result;
        try {
          final texts = <String>[], blocks = <Map<String, dynamic>>[];
          final rawBlocks = <ReceiptOcrBlock>[];
          ReceiptOcrExtraction? extraction;
          final paths = original.pagePaths.isEmpty
              ? [original.expense.receiptPath!]
              : original.pagePaths;
          for (var page = 0; page < paths.length; page++) {
            extraction = await engine.recognizeFile(paths[page]);
            _checkAccount();
            texts.add(extraction.text);
            rawBlocks.addAll(extraction.blocks);
            blocks.addAll(extraction.blocks.map((b) => {
                  'page': page + 1,
                  'text': b.text,
                  'bounds': b.bounds,
                  'score': b.score
                }));
          }
          final ocr = _policy.analyseWithContext(
            texts.join('\n\n'),
            blocks: rawBlocks,
            fallbackDate: original.capturedAt,
            trips: widget.appState.trips,
            existingExpenses: widget.appState.expenses,
          );
          final pageHashes = await ReceiptDocumentIntegrity.inspect(paths);
          final audit = await const ReceiptAuditService().create(
              merchant: ocr.merchant,
              amount: ocr.amount,
              category: ocr.category,
              date: ocr.parsedDate,
              currency: ocr.currency,
              abn: ocr.abn,
              invoiceNumber: ocr.invoiceNumber,
              gstAmount: ocr.gstAmount,
              imagePath: original.expense.receiptPath,
              ocrResult: ocr,
              engineId: extraction!.engine,
              engineVersion: extraction.version,
              blocks: blocks,
              capturedAt: original.capturedAt,
              extractedAt: extraction.extractedAt,
              existingAudit: original.expense.receiptAudit,
              detailsChanged: true,
              fieldValues: {
                'date': ocr.dateNeedsReview
                    ? null
                    : ocr.parsedDate?.toIso8601String(),
                'currency': ocr.currency,
                'pagePaths': paths,
                'pageHashes': pageHashes,
                'duplicateReviewed': false,
                'groupingReviewed': paths.length == 1
              });
          final expense = original.expense.copyWith(
              allocations: const [],
              amount: ocr.amount,
              supplier: ocr.merchant,
              date: ocr.date,
              category: ocr.category,
              gstAmount: ocr.gstAmount,
              currency: ocr.currency,
              supplierAbn: ocr.abn,
              invoiceNumber: ocr.invoiceNumber,
              receiptAudit: audit);
          result = original.copyWith(
              expense: expense,
              processed: true,
              purchaseDate: ocr.dateNeedsReview ? null : ocr.parsedDate,
              state: ReceiptDraftState.needsReview,
              extractionReviewed: false,
              duplicateReviewed: false,
              groupingReviewed: paths.length == 1,
              issues: ocr.dateNeedsReview ? ['Choose purchase date'] : []);
          result = result.copyWith(issues: _issues(result));
        } catch (e) {
          result = original.copyWith(
              processed: false,
              state: ReceiptDraftState.failed,
              error: '$e',
              issues: [
                'Could not read image — retry or enter receipt details'
              ]);
        }
        _checkAccount();
        final next = [..._drafts]..[i] = result;
        await _persist(next);
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Reading paused: $e. Saved drafts remain available.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ReceiptDraft draft) async {
    final e = draft.expense;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
              appState: widget.appState,
              existingExpense: e,
              merchant: e.supplier ?? '',
              amount: e.amount,
              categoryName: e.category.displayName,
              receiptDate: e.date.year < 2020 ? DateTime.now() : e.date,
              purchaseDateUnknown: _unknownDate(draft) || !draft.processed,
              onSaveDraft: (updated) async {
                _checkAccount();
                final current =
                    _drafts.firstWhere((d) => d.documentId == draft.documentId);
                if (current.revision != draft.revision) {
                  throw StateError(
                      'This receipt changed. Reopen it before editing.');
                }
                var edited = updated;
                final editedPages = updated.receiptPath != e.receiptPath
                    ? [updated.receiptPath!, ...current.pagePaths.skip(1)]
                    : current.pagePaths;
                if (updated.receiptPath != e.receiptPath) {
                  final hashes =
                      await ReceiptDocumentIntegrity.inspect(editedPages);
                  _checkAccount();
                  final replacementAudit =
                      await const ReceiptAuditService().create(
                    merchant: updated.supplier ?? '',
                    amount: updated.amount,
                    category: updated.category,
                    imagePath: updated.receiptPath,
                    existingAudit: updated.receiptAudit,
                    date: updated.date,
                    currency: updated.currency,
                    detailsChanged: true,
                    imageReplacementReviewed: true,
                    fieldValues: {
                      'pagePaths': editedPages,
                      'pageHashes': hashes
                    },
                  );
                  edited = updated.copyWith(receiptAudit: replacementAudit);
                }
                final revised = current.copyWith(
                    expense: edited,
                    processed: true,
                    purchaseDate: updated.date,
                    pagePaths: editedPages,
                    extractionReviewed: true,
                    duplicateReviewed: false,
                    groupingReviewed: true,
                    state: ReceiptDraftState.needsReview);
                final next = _drafts
                    .map((d) => d.documentId == current.documentId
                        ? revised.copyWith(issues: _issues(revised))
                        : d)
                    .toList();
                await _persist(next);
              },
            )));
    if (mounted) setState(() {});
  }

  Future<void> _resolveDuplicate(ReceiptDraft draft) async {
    final keep = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Is this a separate purchase?'),
                content: const Text(
                    'A receipt with matching details already exists. Keep this only if it represents a different purchase.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Back')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Keep separate purchase'))
                ]));
    if (keep != true || !mounted) return;
    final revised = draft.copyWith(duplicateReviewed: true);
    try {
      await _persist(_drafts
          .map((d) => d.documentId == draft.documentId
              ? revised.copyWith(issues: _issues(revised))
              : d)
          .toList());
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _remove(ReceiptDraft draft) async {
    final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remove this draft?'),
                content: const Text('No expense will be created.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove draft'))
                ]));
    if (remove != true || !mounted) return;
    try {
      await _persist(
          _drafts.where((d) => d.documentId != draft.documentId).toList());
      _selected.remove(draft.expense.id);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _group() async {
    setState(() => _busy = true);
    try {
      await _store!.groupDocuments(_pages.toList());
      _drafts = _store!.load().toList();
      _pages.clear();
      _selected.clear();
      if (mounted) await _readPending();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _split(ReceiptDraft draft) async {
    try {
      await _store!.splitDocument(draft.documentId);
      _drafts = _store!.load().toList();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _status = 'Saving selected receipts…';
      _error = null;
    });
    final batchId = 'batch_${DateTime.now().microsecondsSinceEpoch}';
    try {
      _checkAccount();
      final chosen =
          _drafts.where((d) => _selected.contains(d.expense.id)).toList();
      for (final d in chosen) {
        _checkAccount();
        final issues = _issues(d);
        if (issues.isNotEmpty) throw FormatException(issues.join('. '));
        final e = d.expense;
        final vehicle = widget.appState.vehicles
            .where((v) => v.id == e.vehicleId)
            .firstOrNull;
        if (vehicle == null) {
          throw StateError('Choose an available vehicle for this receipt.');
        }
        final pagePaths = d.pagePaths.isEmpty ? [e.receiptPath!] : d.pagePaths;
        final pageHashes = await ReceiptDocumentIntegrity.inspect(pagePaths,
            expectedHashes:
                (e.receiptAudit?.currentFields['pageHashes'] as List?)
                    ?.cast<String>());
        final audit = await const ReceiptAuditService().create(
            merchant: e.supplier ?? '',
            amount: e.amount,
            category: e.category,
            imagePath: e.receiptPath,
            date: e.date,
            currency: e.currency,
            abn: e.supplierAbn,
            invoiceNumber: e.invoiceNumber,
            gstAmount: e.gstAmount,
            existingAudit: e.receiptAudit,
            confirmedByUser: true,
            reviewedBy: _account,
            batchId: batchId,
            fieldValues: {
              'date': e.date.toIso8601String(),
              'currency': e.currency,
              'gstAmount': e.gstAmount,
              'allocations': e.allocations.map((a) => a.toJson()).toList(),
              'pagePaths': pagePaths,
              'pageHashes': pageHashes,
              'duplicateReviewed': d.duplicateReviewed,
              'groupingReviewed': d.groupingReviewed
            });
        _checkAccount();
        final cpk = vehicle.taxMethod == TaxMethod.centsPerKm &&
            e.category.isCarExpense &&
            !e.allocations.any((a) =>
                a.purpose == AllocationPurpose.work &&
                (a.category ?? e.category).isDirectlyDeductibleByDefault);
        final approved = e.copyWith(
            receiptAudit: audit,
            isVaultOnly: e.isVaultOnly || cpk,
            vaultReason:
                e.vaultReason ?? (cpk ? 'cents_per_km_running_cost' : null));
        if (_store!.database != null) await _store!.stageCommit(approved);
        _checkAccount();
        await widget.appState.saveWorkflowReceipt(approved);
        if (_store!.database != null) {
          await _store!.completeCommit(e.id);
          _drafts = _store!.load().toList();
        } else {
          await _persist(_drafts
              .where((item) => item.documentId != d.documentId)
              .toList());
        }
        _selected.remove(e.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Some receipts could not be saved: $e. Retry to continue.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _drafts.where((d) => d.processed && _issues(d).isEmpty).toList();
    final selected =
        ready.where((d) => _selected.contains(d.expense.id)).toList();
    final total = selected.fold<double>(0, (sum, d) => sum + d.expense.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt inbox')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            '${_drafts.length} drafts · ${ready.length} ready to review together',
            style: Theme.of(context).textTheme.titleLarge),
        const Text(
            'Check dates, totals, currency and work/private items. Group photos that belong to one receipt before confirming.'),
        if (_busy) ...[const LinearProgressIndicator(), Text(_status)],
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_skipped > 0) Text('Skipped $_skipped photo(s) already retained.'),
        if (!_busy && _drafts.any((d) => !d.processed))
          TextButton(
              onPressed: _readPending, child: const Text('Resume reading')),
        if (!_busy && _pages.length > 1)
          FilledButton.tonal(
              onPressed: _group,
              child: Text(
                  'Combine ${_pages.length} selected pages as one receipt')),
        if (!_busy && ready.isNotEmpty)
          TextButton(
              onPressed: () => setState(() {
                    if (selected.length == ready.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(ready.map((d) => d.expense.id));
                    }
                  }),
              child: Text(selected.length == ready.length
                  ? 'Deselect all'
                  : 'Select all ready receipts')),
        for (final d in _drafts)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Vehicle: ${widget.appState.vehicles.where((v) => v.id == d.expense.vehicleId).map((v) => '${v.make} ${v.model} · ${v.regoPlate}').firstOrNull ?? 'Unavailable'} · ${d.pagePaths.length} page(s)'),
                        for (final path in d.pagePaths)
                          GestureDetector(
                              onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                          child: Image.file(File(path),

                                              errorBuilder: (c, e, s) =>
                                                  const Text(
                                                      'Image unavailable'))))),
                              child: Image.file(File(path),
                                  cacheWidth: 480,
                                  height: 130,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Text(
                                      'Image unavailable — replace before confirming'))),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selected.contains(d.expense.id),
                            onChanged:
                                _busy || !d.processed || _issues(d).isNotEmpty
                                    ? null
                                    : (value) => setState(() {
                                          if (value == true) {
                                            _selected.add(d.expense.id);
                                          } else {
                                            _selected.remove(d.expense.id);
                                          }
                                        }),
                            title: Text(
                                '${d.expense.supplier ?? 'Receipt'} · ${d.expense.currency ?? 'Currency unknown'} ${d.expense.amount.toStringAsFixed(2)}'),
                            subtitle: Text(
                                '${_unknownDate(d) || !d.processed ? 'Date unknown' : d.expense.date.toIso8601String().split('T').first}\n${d.expense.category.displayName}')),
                        for (final issue in _issues(d))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                Icon(
                                  issue.startsWith('Low OCR')
                                      ? AppIcons.warning
                                      : Icons.info_outline,
                                  size: 14,
                                  color: issue.startsWith('Low OCR')
                                      ? AppColor.attentionStrong
                                      : AppColor.inkMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    issue,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: issue.startsWith('Low OCR')
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: issue.startsWith('Low OCR')
                                          ? AppColor.attentionInk
                                          : AppColor.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (d.state == ReceiptDraftState.failed)
                          const Text(
                              'Reading failed. Your photo is retained; retry or enter the details.'),
                        TextButton(
                            onPressed: _busy ? null : () => _edit(d),
                            child: const Text('Review / correct details')),
                        if (_issues(d)
                            .any((s) => s.startsWith('Possible duplicate')))
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _resolveDuplicate(d),
                              child: const Text('Review possible duplicate')),
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                      _readPending(documentId: d.documentId),
                              child: const Text('Read again on device')),
                          FilterChip(
                              label: const Text('Select pages to combine'),
                              selected: _pages.contains(d.documentId),
                              onSelected: _busy
                                  ? null
                                  : (v) => setState(() {
                                        if (v) {
                                          _pages.add(d.documentId);
                                        } else {
                                          _pages.remove(d.documentId);
                                        }
                                      })),
                          if (d.groupId != null)
                            TextButton(
                                onPressed: _busy ? null : () => _split(d),
                                child: const Text('Separate pages')),
                          TextButton(
                              onPressed: _busy ? null : () => _remove(d),
                              child: const Text('Remove draft')),
                        ]),
                      ]))),
        if (!_busy && _drafts.isEmpty)
          const Text('No pending receipts. Return to scan or import photos.'),
        const SizedBox(height: 100),
      ]),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _busy || selected.isEmpty ? null : _confirm,
                  child: Text(
                      'Confirm ${selected.length} selected · AUD ${total.toStringAsFixed(2)}')))),
    );
  }
}
