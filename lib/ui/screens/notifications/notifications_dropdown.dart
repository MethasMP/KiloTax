import '../../widgets/adaptive_row.dart';
import 'package:provider/provider.dart';
import '../../../state/app_state.dart';
import '../evidence/evidence_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../core/theme/app_color.dart';

class NotificationsDropdown extends StatefulWidget {
  final NotificationService notificationService;
  final VoidCallback? onNotificationAction;

  const NotificationsDropdown({
    super.key,
    required this.notificationService,
    this.onNotificationAction,
  });

  /// Displays the notifications panel as a top-anchored dropdown sliding down smoothly.
  static Future<void> show(
    BuildContext context, {
    required NotificationService notificationService,
    VoidCallback? onNotificationAction,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Align(
          alignment: Alignment.topCenter,
          child: NotificationsDropdown(
            notificationService: notificationService,
            onNotificationAction: onNotificationAction,
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.15),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: FadeTransition(
            opacity: curvedAnim,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown> {
  @override
  Widget build(BuildContext context) {
    final list = widget.notificationService.notifications;
    final topPadding = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(
          top: topPadding + 10,
          left: 14,
          right: 14,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.deepNavy.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                child: AdaptiveRow(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AdaptiveRow(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.workBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            LucideIcons.bell,
                            size: 16,
                            color: AppColors.workBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Activity & Alerts',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.ink,
                          ),
                        ),
                        if (widget.notificationService.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColor.attentionStrong,
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
                    AdaptiveRow(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (list.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await widget.notificationService.markAllAsRead();
                              if (mounted) setState(() {});
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.workBlue,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(LucideIcons.x,
                              size: 18, color: AppColors.muted),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Notification List or Empty State
              if (list.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.bellOff,
                            size: 22, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Trip detections and tax reminders will appear here.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.border,
                      indent: 64,
                    ),
                    itemBuilder: (ctx, idx) {
                      final item = list[idx];
                      return _NotificationTile(
                        notification: item,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await widget.notificationService.markAsRead(item.id);
                          if (mounted) setState(() {});
                          if (context.mounted) {
                            final navigator = Navigator.of(context);
                            final state =
                                item.deepLinkRoute == '/evidence-review'
                                    ? context.read<AppState>()
                                    : null;
                            navigator.pop();
                            final vehicleId = item.data?['vehicleId'];
                            final financialYear = item.data?['financialYear'];
                            if (state != null &&
                                vehicleId is String &&
                                financialYear is String &&
                                state.vehicles.any(
                                    (vehicle) => vehicle.id == vehicleId)) {
                              navigator.push(MaterialPageRoute<void>(
                                  builder: (_) => EvidenceReviewScreen(
                                      appState: state,
                                      vehicleId: vehicleId,
                                      financialYear: financialYear)));
                            }
                            widget.onNotificationAction?.call();
                          }
                        },
                      );
                    },
                  ),
                ),

              // Subtle bottom pull-to-close indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 8),
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final KiloClaimNotification notification;
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
      case KiloClaimNotificationType.tripDetected:
        icon = LucideIcons.car;
        iconBg = AppColor.brandTint;
        iconColor = AppColor.brandBright;
        break;
      case KiloClaimNotificationType.dailySummary:
        icon = LucideIcons.clipboardCheck;
        iconBg = AppColor.positiveTint;
        iconColor = AppColor.positiveStrong;
        break;
      case KiloClaimNotificationType.logbookReminder:
        icon = LucideIcons.calendarDays;
        iconBg = AppColor.brandTint;
        iconColor = AppColor.brand;
        break;
      case KiloClaimNotificationType.complianceAlert:
        icon = LucideIcons.triangleAlert;
        iconBg = AppColor.attentionTintSoft;
        iconColor = AppColor.attention;
        break;
      case KiloClaimNotificationType.eofyAlert:
        icon = LucideIcons.calendarClock;
        iconBg = AppColor.attentionTintSoft;
        iconColor = AppColor.attention;
        break;
    }

    return Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          title: AdaptiveRow(
            children: [
              Expanded(
                child: Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        notification.isRead ? FontWeight.w600 : FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColor.attentionStrong,
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
                fontSize: 12,
                color: notification.isRead
                    ? AppColors.muted
                    : AppColors.ink.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ),
        ));
  }
}
