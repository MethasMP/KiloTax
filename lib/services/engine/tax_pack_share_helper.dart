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
import 'tax_pack_dispatch_service.dart';
import 'accountant_export_scope.dart';
import 'evidence_review_service.dart';
import 'tax_pack_builder.dart';

enum _PackDestination { share, save }

class TaxPackShareHelper {
  static final _active = Expando<bool>();

  static Future<void> shareTaxPack(BuildContext context, AppState appState,
      {String? vehicleId, String? financialYear}) async {
    if (_active[appState] == true) return;
    _active[appState] = true;
    try {
      await _prepare(context, appState,
          vehicleId: vehicleId, financialYear: financialYear);
    } finally {
      _active[appState] = false;
    }
  }

  static Future<void> _prepare(BuildContext context, AppState appState,
      {String? vehicleId, String? financialYear}) async {
    final candidate = vehicleId == null
        ? appState.primaryVehicle
        : appState.vehicles.where((v) => v.id == vehicleId).firstOrNull;
    final selectedYear = AccountantExportScope.normalizeYear(
        financialYear ?? appState.activeTaxRule.financialYear);
    final scoped = const EvidenceReviewService().evaluate(
        vehicle: candidate,
        financialYear: selectedYear,
        trips: appState.trips,
        expenses: appState.expenses);
    if (!scoped.canExport) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Add a vehicle and records before preparing your accountant pack.'),
      ));
      return;
    }
    final vehicle = candidate!;
    final owner = appState.currentUser?.id;
    final token = owner == null ? null : appState.currentAccessToken;
    bool isCurrent() =>
        context.mounted &&
        appState.isAccountantExportSessionCurrent(owner, token);
    if (!context.mounted || !isCurrent()) return;
    final trips = appState.trips;
    final expenses = appState.expenses;
    final rule =
        (await AccountantExportScope.loadRules(appState))[selectedYear];
    if (!context.mounted || !isCurrent()) return;
    if (rule == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Tax settings are unavailable for this year. Choose another year or try again later.')));
      return;
    }
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
      final proceed = await showDialog<_PackDestination>(
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
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'))
                  ],
                );
              }
              return AlertDialog(
                scrollable: true,
                title: const Text('Review accountant pack'),
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
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, _PackDestination.save),
                      child: const Text('Save a copy')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, _PackDestination.share),
                      child: const Text('Share pack')),
                ],
              );
            }),
      );
      if (proceed == null || !context.mounted || !isCurrent()) return;
      Rect? origin;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
      final String message;
      if (proceed == _PackDestination.save) {
        final result =
            await TaxPackDispatchService.saveCopy(prepared.file.path);
        message = switch (result) {
          TaxPackSaveResult.saved => 'Pack saved to your selected location.',
          TaxPackSaveResult.dismissed =>
            'Saving cancelled. Your records are unchanged.',
          TaxPackSaveResult.failed =>
            'Could not save the pack. Your records are unchanged. Please try again.',
        };
      } else {
        final result = await TaxPackDispatchService.share(
          path: prepared.file.path,
          subject:
              'FY${rule.financialYear} Vehicle Records for Review - ${vehicle.regoPlate}',
          description: prepared.description,
          origin: origin,
        );
        message = switch (result) {
          TaxPackShareResult.selected =>
            'Pack handed to the selected app. Delivery is not confirmed.',
          TaxPackShareResult.dismissed =>
            'Sharing cancelled. Your records are unchanged.',
          TaxPackShareResult.unavailable =>
            'Share sheet opened. Completion could not be confirmed.',
          TaxPackShareResult.failed =>
            'Could not open sharing. Your records are unchanged. Please try again.',
        };
      }
      if (!context.mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
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
