import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/notifications/notification_service.dart';
import '../../../../state/app_state.dart';
import '../../notifications/notifications_dropdown.dart';
import '../../../../core/theme/app_color.dart';

class HomeHeaderBar extends StatelessWidget {
  final AppState appState;
  final VoidCallback onAccountTap;

  const HomeHeaderBar({
    super.key,
    required this.appState,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    final streak = appState.evidenceStreakDays;
    final user = appState.currentUser;
    final String greetingName;
    if (user != null) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        greetingName = user.displayName!.trim().split(' ').first;
      } else if (user.email.isNotEmpty) {
        greetingName = user.email.split('@').first;
      } else {
        greetingName = '';
      }
    } else {
      greetingName = '';
    }

    final hour = DateTime.now().hour;
    final String timeGreeting;
    if (hour >= 4 && hour < 7) {
      timeGreeting = 'Early start';
    } else if (hour >= 7 && hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeGreeting = 'Good evening';
    } else {
      timeGreeting = 'Working late';
    }

    final vehicle = appState.primaryVehicle;
    // Keep it clean & punchy: Just Brand + Model (e.g., 'Tesla Model Y' or 'Toyota Hilux')
    final String vehicleBrandTitle;
    if (vehicle != null) {
      final make = vehicle.make.trim();
      final model = vehicle.model.trim();
      // If model already starts with make (e.g. 'Tesla Model Y'), avoid repeating make
      final cleanName = model.toLowerCase().startsWith(make.toLowerCase())
          ? model.split(' ').take(3).join(' ')
          : '$make ${model.split(' ').first}';
      vehicleBrandTitle = cleanName;
    } else {
      vehicleBrandTitle = 'FY${appState.activeTaxRule.financialYear} Vehicle';
    }

    final fullGreeting =
        greetingName.isNotEmpty ? '$timeGreeting, $greetingName' : timeGreeting;

    return FutureBuilder<NotificationService>(
      future: NotificationService.getInstance(),
      builder: (context, snapshot) {
        final notifService = snapshot.data;
        final unreadCount = notifService?.unreadCount ?? 0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: appState.isAuthenticated
                  ? 'Account and settings'
                  : 'Local mode, tap to link cloud backup',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAccountTap();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: appState.isAuthenticated
                          ? AppColors.border
                          : AppColor.line,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepNavy.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: appState.isAuthenticated
                        ? (user?.avatarUrl != null &&
                                user!.avatarUrl!.isNotEmpty
                            ? Image.network(
                                user.avatarUrl!,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildInitialAvatar(user, greetingName),
                              )
                            : _buildInitialAvatar(user, greetingName))
                        : _buildGuestAvatar(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appState.isAuthenticated ? fullGreeting : timeGreeting,
                    style: AppType.cardTitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: S.labelGap),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: S.sm, vertical: S.xs),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: R.chipR,
                          border: Border.all(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              vehicle?.effectiveVehicleType.iconData ??
                                  AppIcons.vehicle,
                              size: AppIconSize.inline,
                              color: AppColors.ink,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                vehicleBrandTitle,
                                style: AppType.secondary.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                  letterSpacing: 0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: S.sm, vertical: S.xs),
                          decoration: BoxDecoration(
                            color: AppColor.attention.withValues(alpha: 0.1),
                            borderRadius: R.chipR,
                            border: Border.all(
                              color: AppColor.attention.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🔥 $streak d',
                                style: AppType.eyebrow.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.attention,
                                  fontFeatures: AppType.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: unreadCount > 0
                  ? 'Notifications, $unreadCount unread'
                  : 'Notifications',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (notifService != null) {
                    NotificationsDropdown.show(
                      context,
                      notificationService: notifService,
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepNavy.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(
                          AppIcons.notifications,
                          size: 19,
                          color: AppColors.ink,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 9,
                          right: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.card, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInitialAvatar(dynamic user, String greetingName) {
    final initial = user != null &&
            user.displayName != null &&
            user.displayName!.trim().isNotEmpty
        ? user.displayName!.trim()[0].toUpperCase()
        : (greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'T');

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.deepNavy,
          borderRadius: R.controlR,
        ),
        child: Center(
          child: Text(
            initial,
            style: AppType.bodyStrong.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestAvatar() {
    return Container(
      width: 48,
      height: 48,
      color: AppColor.surfaceMuted,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            AppIcons.personal,
            size: AppIconSize.control,
            color: AppColors.ink,
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColor.line,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
