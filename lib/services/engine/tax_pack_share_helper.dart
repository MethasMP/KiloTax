import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../state/app_state.dart';
import '../../data/models/vehicle.dart';
import '../../ui/screens/logbook/logbook_progress_screen.dart';
import '../../ui/screens/feedback/feedback_screen.dart';
import 'tax_email_dispatch_service.dart';
import 'tax_pack_builder.dart';
import '../receipts/receipt_inbox_service.dart';

class TaxPackShareHelper {
  static Future<void> shareTaxPack(BuildContext context, AppState appState,
      {bool allowDraftWithGaps = false}) async {
    final vehicle = appState.primaryVehicle;
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a vehicle before preparing a tax pack.')),
      );
      return;
    }
    if (!allowDraftWithGaps &&
        vehicle.taxMethod == TaxMethod.logbook &&
        appState.pendingOdometerGaps.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Review the unrecorded odometer travel before preparing this tax pack.'),
        action: SnackBarAction(
            label: 'Review',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const LogbookProgressScreen()))),
      ));
      return;
    }
    final trips = appState.trips;
    final expenses = appState.expenses;
    final rule = appState.activeTaxRule;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Preparing ZIP with records and receipt files…')),
    );
    TaxPackArtifact? pack;
    try {
      final inbox = await ReceiptInboxService.open(
          appState.currentUser?.id ?? 'guest', vehicle.id);
      final pendingDraftCount = inbox
          .load()
          .where((draft) =>
              draft.expense.vehicleId == vehicle.id &&
              draft.state != ReceiptDraftState.recorded)
          .length;
      pack = await const TaxPackBuilder().build(
        pendingDraftCount: pendingDraftCount,
        vehicle: vehicle,
        taxRule: rule,
        trips: trips,
        expenses: expenses,
        jobs: appState.jobSites,
        hasOdometerGaps: appState.pendingOdometerGaps.isNotEmpty,
        outputDirectory: await getTemporaryDirectory(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final preparedPack = pack;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(preparedPack.issueCount == 0
              ? 'Tax pack ready for review'
              : 'Draft tax pack ready'),
          content: Text(
            '${preparedPack.report.trips.length} trips, ${preparedPack.report.expenses.length} expenses, '
            'and ${preparedPack.receiptCount} receipt files.\n\n'
            '${preparedPack.issueCount} review items are listed in the ZIP. '
            'Receipt files are included as recorded. Their accuracy and tax eligibility are not verified. '
            'Review the files before lodging a claim.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(preparedPack.issueCount == 0
                  ? 'Share ZIP'
                  : 'Share draft ZIP'),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
      Rect? shareOrigin;
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        shareOrigin = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      }
      final dispatchResult = await TaxEmailDispatchService.dispatchTaxPackEmail(
        attachmentPaths: [pack.file.path],
        subject:
            'FY${rule.financialYear} Vehicle Records for Review - ${vehicle.regoPlate}',
        body: pack.description,
        sharePositionOrigin: shareOrigin,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (dispatchResult) {
          EmailDispatchResult.sentViaMailApp =>
            'Tax pack handed to the email app. Delivery is not confirmed.',
          EmailDispatchResult.fallbackToShareSheet =>
            'Tax pack handed to the system share sheet.',
          EmailDispatchResult.failed =>
            'Could not open the email app or share sheet.',
        }),
        action: SnackBarAction(
          label: 'Feedback',
          onPressed: () => FeedbackScreen.show(context),
        ),
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not prepare the tax pack. Check that this year has records and try again.')),
        );
      }
    } finally {
      if (pack != null) {
        try {
          await pack.directory.delete(recursive: true);
        } on FileSystemException {
          // The operating system may have already removed temporary files.
        }
      }
    }
  }
}
