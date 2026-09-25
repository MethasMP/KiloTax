import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/notifications/notification_service.dart';

class NotificationsSheet extends StatefulWidget {
  final NotificationService notificationService;
  final VoidCallback? onNotificationAction;

  const NotificationsSheet({
    super.key,
    required this.notificationService,
    this.onNotificationAction,
  });

  static Future<void> show(
    BuildContext context, {
    required NotificationService notificationService,
    VoidCallback? onNotificationAction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(
        notificationService: notificationService,
        onNotificationAction: onNotificationAction,
      ),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  @override
  Widget build(BuildContext context) {
    final list = widget.notificationService.notifications;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Activity & Alerts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.ink,
                        ),
                      ),
                      if (widget.notificationService.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.notificationService.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (list.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await widget.notificationService.markAllAsRead();
                        setState(() {});
                      },
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.workBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Notification List
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.bellOff, size: 24, color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'All caught up!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Trip detections and tax reminders will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border, indent: 64),
                  itemBuilder: (ctx, idx) {
                    final item = list[idx];
                    return _NotificationTile(
                      notification: item,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await widget.notificationService.markAsRead(item.id);
                        setState(() {});
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          widget.onNotificationAction?.call();
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final KiloTaxNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconBg;
    final Color iconColor;

    switch (notification.type) {
      case KiloTaxNotificationType.tripDetected:
        icon = LucideIcons.car;
        iconBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        break;
      case KiloTaxNotificationType.dailySummary:
        icon = LucideIcons.clipboardCheck;
        iconBg = const Color(0xFFF0FDF4);
        iconColor = const Color(0xFF16A34A);
        break;
      case KiloTaxNotificationType.logbookReminder:
        icon = LucideIcons.calendarDays;
        iconBg = const Color(0xFFFAF5FF);
        iconColor = const Color(0xFF9333EA);
        break;
      case KiloTaxNotificationType.complianceAlert:
        icon = LucideIcons.triangleAlert;
        iconBg = const Color(0xFFFFF7ED);
        iconColor = const Color(0xFFEA580C);
        break;
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              notification.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFF97316),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          notification.body,
          style: TextStyle(
            fontSize: 12.5,
            color: notification.isRead ? AppColors.muted : AppColors.ink.withValues(alpha: 0.8),
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
