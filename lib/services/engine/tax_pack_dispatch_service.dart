import 'dart:io';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

enum TaxPackShareResult { selected, dismissed, unavailable, failed }

enum TaxPackSaveResult { saved, dismissed, failed }

/// Native iOS/iPadOS activity sheet and Android Sharesheet. No mail-app
/// preference and no interpretation of chooser completion as email delivery.
class TaxPackDispatchService {
  static Future<TaxPackSaveResult> saveCopy(String path) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        return TaxPackSaveResult.failed;
      }
      final destination = await FilePicker.saveFile(
        fileName: file.uri.pathSegments.last,
        bytes: await file.readAsBytes(),
        mimeType: 'application/zip',
        dialogTitle: 'Save accountant pack',
      );
      return destination == null
          ? TaxPackSaveResult.dismissed
          : TaxPackSaveResult.saved;
    } catch (_) {
      return TaxPackSaveResult.failed;
    }
  }

  static Future<TaxPackShareResult> share({
    required String path,
    required String subject,
    required String description,
    Rect? origin,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        return TaxPackShareResult.failed;
      }
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'application/zip')],
        subject: subject,
        text: description,
        title: 'Share accountant pack',
        sharePositionOrigin: origin,
      ));
      return switch (result.status) {
        ShareResultStatus.success => TaxPackShareResult.selected,
        ShareResultStatus.dismissed => TaxPackShareResult.dismissed,
        ShareResultStatus.unavailable => TaxPackShareResult.unavailable,
      };
    } catch (_) {
      return TaxPackShareResult.failed;
    }
  }
}
