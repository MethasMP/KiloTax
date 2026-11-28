import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../state/app_state.dart';
import '../receipts/receipt_inbox_service.dart';
import 'receipt_backup_archive.dart';
import 'package:file_picker/file_picker.dart';

/// Creates complete local receipt archives and merges user-selected backups.
/// Allows users (especially Guest/Offline users) to export all logbook & expense
/// records directly into iOS Files, iCloud Drive, or AirDrop.
class LocalBackupService {
  LocalBackupService._();

  /// Compiles a complete audit snapshot of vehicles, trips, expenses, and evidence into JSON.
  static Map<String, dynamic> createBackupPayload(AppState appState) {
    return {
      'format': 'KiloClaim_Backup_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'primaryVehicleId': appState.primaryVehicle?.id,
      'stats': {
        'totalVehicles': appState.vehicles.length,
        'totalTrips': appState.trips.length,
        'totalExpenses': appState.expenses.length,
        'totalEvidence': appState.evidenceList.length,
      },
      'vehicles': appState.vehicles.map((v) => v.toJson()).toList(),
      'trips': appState.trips.map((t) => t.toJson()).toList(),
      'expenses': appState.expenses.map((e) => e.toJson()).toList(),
      'evidence': appState.evidenceList.map((ev) => ev.toJson()).toList(),
    };
  }

  static Future<void> restoreFromFile(
      BuildContext context, AppState appState) async {
    try {
      final selected = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ['zip']);
      final path = selected?.path;
      if (path == null) return;
      final backup = await ReceiptBackupArchive.readArchive(File(path));
      if (!context.mounted) return;
      final account = appState.currentUser?.id ?? 'guest';
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Merge this backup?'),
                content: Text(
                    'This backup contains ${backup.summary}. Existing records with the same ID will be kept. New records will be added. Receipt drafts remain outside your accounting totals.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Merge backup'))
                ],
              ));
      if (confirmed != true) return;
      if ((appState.currentUser?.id ?? 'guest') != account) {
        throw StateError('Account changed. Choose the backup again.');
      }
      final inbox = await ReceiptInboxService.openForVehicles(
          account, appState.vehicles.map((v) => v.id));
      void checkOwner() {
        if ((appState.currentUser?.id ?? 'guest') != account) {
          throw StateError('Account changed. Choose the backup again.');
        }
      }

      checkOwner();
      await ReceiptBackupArchive.restore(
          backup: backup,
          inbox: inbox,
          checkOwner: checkOwner,
          restoreLedger: (payload) =>
              appState.restoreLocalBackup(payload, expectedAccount: account));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Backup merged. Existing records were kept.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Could not complete restore: $e. If saving had begun, your restored records are kept; select the same backup to retry.')));
      }
    }
  }

  /// Exports the backup file and triggers the system share sheet (Files / iCloud Drive / AirDrop).
  static Future<bool> exportBackupFile(
    BuildContext context,
    AppState appState, {
    Rect? sharePositionOrigin,
  }) async {
    HapticFeedback.mediumImpact();

    File? file;
    try {
      final account = appState.currentUser?.id ?? 'guest';
      void checkOwner() {
        if ((appState.currentUser?.id ?? 'guest') != account) {
          throw StateError('Account changed. Prepare the backup again.');
        }
      }

      final payload = createBackupPayload(appState);
      payload['jobSites'] = appState.jobSites.map((j) => j.toJson()).toList();
      payload['annualOdometers'] =
          appState.annualOdometers.map((o) => o.toJson()).toList();
      payload['userProfile'] = appState.userProfile.toJson();
      final inbox = await ReceiptInboxService.openForVehicles(
          account, appState.vehicles.map((v) => v.id));
      checkOwner();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'KiloClaim_Backup_$dateStr.zip';
      file = File('${tempDir.path}/$fileName');

      await ReceiptBackupArchive.createArchive(
          payload: payload, inbox: inbox, output: file);
      checkOwner();

      // Safe anchor origin for iPad
      Rect? origin = sharePositionOrigin;
      if (origin == null && context.mounted) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final size = renderBox.size;
          final offset = renderBox.localToGlobal(Offset.zero);
          origin = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
        } else {
          final mediaQuery = MediaQuery.maybeOf(context);
          if (mediaQuery != null) {
            final screen = mediaQuery.size;
            origin = Rect.fromLTWH(
                screen.width / 2 - 50, screen.height / 2 - 50, 100, 100);
          }
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'KiloClaim Data Backup ($dateStr)',
          text:
              'KiloClaim Local Data Backup containing ${appState.trips.length} trips, ${appState.expenses.length} expenses, and ${appState.vehicles.length} vehicle(s).',
          sharePositionOrigin: origin,
        ),
      );

      return true;
    } catch (e, stack) {
      debugPrint('[LocalBackupService] Export failed: $e\n$stack');
      return false;
    } finally {
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint(
              '[LocalBackupService] Failed to delete temp backup file: $e');
        }
      }
    }
  }
}
