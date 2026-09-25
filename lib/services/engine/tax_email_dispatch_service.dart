import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

enum EmailDispatchResult {
  sentViaMailApp,
  fallbackToShareSheet,
  failed,
}

/// Dispatches ATO Tax Pack emails directly into the user's native email client
/// (e.g. Apple Mail, Gmail, Outlook) with binary attachments attached.
/// 
/// If native email dispatch is unsupported (e.g. iOS Simulator, or no mail account
/// configured on device), it seamlessly and gracefully falls back to the system Share Sheet
/// with iPad popover anchor protection.
class TaxEmailDispatchService {
  TaxEmailDispatchService._();

  /// Attempts to open the native mail composer with attachments.
  /// If it fails due to platform unavailability or lack of mail accounts,
  /// it delegates to [SharePlus] as an automatic fallback.
  static Future<EmailDispatchResult> dispatchTaxPackEmail({
    required List<String> attachmentPaths,
    required String subject,
    required String body,
    List<String> recipients = const [],
    List<String> cc = const [],
    List<String> bcc = const [],
    bool isHTML = false,
    Rect? sharePositionOrigin,
  }) async {
    // 1. Validate attachments exist on disk
    final validAttachmentPaths = <String>[];
    for (final path in attachmentPaths) {
      if (File(path).existsSync()) {
        validAttachmentPaths.add(path);
      }
    }

    // 2. Try Tier 1: Native Mail Composer (MFMailComposeViewController / Android Intent)
    try {
      final email = Email(
        body: body,
        subject: subject,
        recipients: recipients,
        cc: cc,
        bcc: bcc,
        attachmentPaths: validAttachmentPaths,
        isHTML: isHTML,
      );

      await FlutterEmailSender.send(email);
      debugPrint('[TaxEmailDispatchService] Dispatched via native email composer.');
      return EmailDispatchResult.sentViaMailApp;
    } on PlatformException catch (e) {
      debugPrint('[TaxEmailDispatchService] Native mail unavailable: ${e.code} - ${e.message}. Triggering Tier 2 Fallback.');
      // Common codes:
      // 'not_available' -> Mail client not set up / iOS Simulator
    } catch (e) {
      debugPrint('[TaxEmailDispatchService] Unexpected error on native email sender: $e');
    }

    // 3. Tier 2 Fallback: System Share Sheet via SharePlus (with iPad safe origin)
    try {
      final xFiles = validAttachmentPaths.map((p) => XFile(p)).toList();
      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          subject: subject,
          text: body,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return EmailDispatchResult.fallbackToShareSheet;
    } catch (fallbackError) {
      debugPrint('[TaxEmailDispatchService] Fallback Share Sheet failed: $fallbackError');
      return EmailDispatchResult.failed;
    }
  }
}
