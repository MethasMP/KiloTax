import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../state/app_state.dart';

/// Service responsible for local JSON backup generation and dispatch
/// Allows users (especially Guest/Offline users) to export all logbook & expense
/// records directly into iOS Files, iCloud Drive, or AirDrop.
class LocalBackupService {
  LocalBackupService._();

  /// Compiles a complete audit snapshot of vehicles, trips, expenses, and evidence into JSON.
  static Map<String, dynamic> createBackupPayload(AppState appState) {
    return {
      'format': 'KiloTax_Backup_v1',
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

  /// Exports the backup file and triggers the system share sheet (Files / iCloud Drive / AirDrop).
  static Future<bool> exportBackupFile(
    BuildContext context,
    AppState appState, {
    Rect? sharePositionOrigin,
  }) async {
    HapticFeedback.mediumImpact();

    try {
      final payload = createBackupPayload(appState);
      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'KiloTax_Backup_$dateStr.json';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(jsonString, flush: true);

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
          subject: 'KiloTax Data Backup ($dateStr)',
          text:
              'KiloTax Local Data Backup containing ${appState.trips.length} trips, ${appState.expenses.length} expenses, and ${appState.vehicles.length} vehicle(s).',
          sharePositionOrigin: origin,
        ),
      );

      return true;
    } catch (e, stack) {
      debugPrint('[LocalBackupService] Export failed: $e\n$stack');
      return false;
    }
  }
}
