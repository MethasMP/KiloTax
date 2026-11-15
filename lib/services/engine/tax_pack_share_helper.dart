import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../state/app_state.dart';
import '../../ui/screens/feedback/feedback_screen.dart';
import '../receipts/receipt_inbox_service.dart';
import '../tax/ato_tax_period_engine.dart';
import 'receipt_export_resolver.dart';
import 'tax_email_dispatch_service.dart';
import 'tax_pack_builder.dart';

class TaxPackShareHelper {
  static final _active = Expando<bool>();

  static Future<void> shareTaxPack(
      BuildContext context, AppState appState) async {
    if (_active[appState] == true) return;
    _active[appState] = true;
    try {
      await _prepare(context, appState);
    } finally {
      _active[appState] = false;
    }
  }

  static Future<void> _prepare(BuildContext context, AppState appState) async {
    final vehicle = appState.primaryVehicle;
    if (vehicle == null || !appState.evidenceReview.hasRecords) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Add a vehicle and records before preparing your accountant pack.'),
      ));
      return;
    }
    final owner = appState.currentUser?.id;
    final token = owner == null ? null : appState.currentAccessToken;
    bool isCurrent() =>
        context.mounted &&
        appState.isAccountantExportSessionCurrent(owner, token);
    if (!isCurrent()) return;
    final trips = appState.trips;
    final expenses = appState.expenses;
    final rule = appState.activeTaxRule;
    final profile = appState.userProfile;
    final jobs = appState.jobSites;
    final annualOdometers = appState.annualOdometers;
    final logbookPeriods = appState.logbookPeriods;
    final hasOdometerGaps =
        appState.odometerGapsForVehicle(vehicle.id).isNotEmpty;
    final resolver = ReceiptExportResolver(
        ownerId: owner, accessToken: token, isCurrent: isCurrent);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Preparing your accountant pack and collecting receipts…'),
    ));
    TaxPackArtifact? pack;
    try {
      final inbox =
          await ReceiptInboxService.open(owner ?? 'guest', vehicle.id);
      if (!context.mounted || !isCurrent()) throw AccountantExportCancelled();
      final pendingDraftCount = inbox
          .load()
          .where((draft) =>
              draft.expense.vehicleId == vehicle.id &&
              draft.state != ReceiptDraftState.recorded &&
              const AtoTaxPeriodEngine()
                      .forDate(draft.expense.date)
                      .shortLabel
                      .replaceAll('–', '-') ==
                  rule.financialYear.replaceAll('–', '-'))
          .length;
      pack = await const TaxPackBuilder().build(
        pendingDraftCount: pendingDraftCount,
        vehicle: vehicle,
        taxRule: rule,
        trips: trips,
        expenses: expenses,
        jobs: jobs,
        profile: profile,
        annualOdometers: annualOdometers,
        logbookPeriods: logbookPeriods,
        hasOdometerGaps: hasOdometerGaps,
        receiptResolver: resolver,
        outputDirectory: await getTemporaryDirectory(),
      );
      if (!context.mounted || !isCurrent()) throw AccountantExportCancelled();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final prepared = pack;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ListenableBuilder(
            listenable: appState,
            builder: (listContext, child) {
              if (!isCurrent()) {
                return AlertDialog(
                  title: const Text('Preparation cancelled'),
                  content: const Text(
                      'Your session changed. Prepare a new pack from the current account.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Close'))
                  ],
                );
              }
              return AlertDialog(
                scrollable: true,
                title: const Text('Ready for your accountant'),
                content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('FY ${rule.financialYear} · ${vehicle.regoPlate}'),
                      const SizedBox(height: 8),
                      Text(
                          '${prepared.report.trips.length} trips · ${prepared.report.expenses.length} expenses · ${prepared.receiptCount} receipt pages'),
                      const SizedBox(height: 8),
                      const Text(
                          'Your summary, spreadsheet and available receipts are included together.'),
                      if (prepared.issueCount > 0) ...[
                        const SizedBox(height: 16),
                        Text('${prepared.issueCount} items for review',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        for (final group in prepared.reviewGroups.take(3))
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${group[0]}: ${group[1]}')),
                        if (prepared.issueCount > 3)
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'The remaining items are listed in your report.')),
                        const SizedBox(height: 8),
                        const Text(
                            'These items stay visible for your accountant. The pack is labelled as a draft.'),
                      ],
                    ]),
                actions: [
                  TextButton(
                      onPressed: () async {
                        if (!isCurrent()) return;
                        final bytes = await prepared.reportFile.readAsBytes();
                        if (!isCurrent() || !dialogContext.mounted) return;
                        await Navigator.of(dialogContext)
                            .push(MaterialPageRoute<void>(
                          builder: (_) => ListenableBuilder(
                              listenable: appState,
                              builder: (listContext, child) => Scaffold(
                                    appBar: AppBar(
                                        title: const Text('Report preview')),
                                    body: isCurrent()
                                        ? PdfPreview(
                                            build: (_) async => bytes,
                                            allowPrinting: false,
                                            allowSharing: false,
                                            canChangePageFormat: false,
                                            canChangeOrientation: false,
                                            canDebug: false)
                                        : const Center(
                                            child: Text(
                                                'Your session changed. Prepare a new pack.')),
                                  )),
                        ));
                      },
                      child: const Text('Preview report')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Send to accountant')),
                ],
              );
            }),
      );
      if (proceed != true || !context.mounted || !isCurrent()) return;
      Rect? origin;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      final result = await TaxEmailDispatchService.dispatchTaxPackEmail(
        attachmentPaths: [prepared.file.path],
        subject:
            'FY${rule.financialYear} Vehicle Records for Review - ${vehicle.regoPlate}',
        body: prepared.description,
        sharePositionOrigin: origin,
      );
      if (!context.mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(switch (result) {
            EmailDispatchResult.sentViaMailApp =>
              'Accountant pack opened in your email app. Delivery is not confirmed.',
            EmailDispatchResult.fallbackToShareSheet =>
              'Accountant pack opened in the share sheet.',
            EmailDispatchResult.failed =>
              'Could not open the email app or share sheet. Please try again.',
          }),
          action: SnackBarAction(
              label: 'Feedback',
              onPressed: () => FeedbackScreen.show(context))));
    } on AccountantExportCancelled {
      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not prepare your accountant pack. Your records are unchanged. Please try again.')));
      }
    } finally {
      resolver.close();
      if (pack != null) {
        try {
          await pack.directory.delete(recursive: true);
        } on FileSystemException {/* Already removed. */}
      }
    }
  }
}
