import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/notifications/notification_service.dart';
import '../../../../state/app_state.dart';
import '../../notifications/notifications_dropdown.dart';

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

    final fullGreeting = greetingName.isNotEmpty
        ? '$timeGreeting, $greetingName'
        : timeGreeting;

    return FutureBuilder<NotificationService>(
      future: NotificationService.getInstance(),
      builder: (context, snapshot) {
        final notifService = snapshot.data;
        final unreadCount = notifService?.unreadCount ?? 0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Left: Squircle Avatar (Displays Google profile image or initials)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAccountTap();
              },
              child: Container(
                width: 46,
                height: 46,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                      ? Image.network(
                          user.avatarUrl!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitialAvatar(user, greetingName),
                        )
                      : _buildInitialAvatar(user, greetingName),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 2. Center Column: Unified Greeting + Car Icon + Clean Brand Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullGreeting,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.car, size: 13, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          vehicleBrandTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (streak > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '🔥$streak',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // 3. Right: Tactile Notification Bell Card with Unread Badge
            GestureDetector(
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
                width: 44,
                height: 44,
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
                        LucideIcons.bell,
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
                            border: Border.all(color: AppColors.card, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInitialAvatar(dynamic user, String greetingName) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.deepNavy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            user != null && user.displayName != null && user.displayName!.isNotEmpty
                ? user.displayName![0].toUpperCase()
                : (greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'M'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
