import 'package:flutter/material.dart';
import '../../../services/notifications/notification_service.dart';
import 'notifications_dropdown.dart';

/// Compatibility entry point using the same notification panel and routes.
class NotificationsSheet extends StatelessWidget {
  final NotificationService notificationService;
  final VoidCallback? onNotificationAction;
  const NotificationsSheet(
      {super.key,
      required this.notificationService,
      this.onNotificationAction});

  static Future<void> show(
    BuildContext context, {
    required NotificationService notificationService,
    VoidCallback? onNotificationAction,
  }) =>
      NotificationsDropdown.show(context,
          notificationService: notificationService,
          onNotificationAction: onNotificationAction);

  @override
  Widget build(BuildContext context) => NotificationsDropdown(
      notificationService: notificationService,
      onNotificationAction: onNotificationAction);
}
