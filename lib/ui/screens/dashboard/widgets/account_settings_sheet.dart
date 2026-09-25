import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../state/app_state.dart';

class AccountSettingsSheet {
  static void show(BuildContext context, AppState appState) {
    HapticFeedback.mediumImpact();
    final user = appState.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Profile Card
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepNavy.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? Image.network(
                              user.avatarUrl!,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackInitial(user),
                            )
                          : _buildFallbackInitial(user),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'KiloTax Tradie',
                          style: AppTextStyles.cardPrimary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'Logged In with Google',
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Compliance & Security Badges
              Row(
                children: [
                  const Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.emerald),
                  const SizedBox(width: 10),
                  const Text('Device-Bound Cloud Vault', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sign Out with Safe Confirmation
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.crimson,
                  side: BorderSide(color: AppColors.crimson.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.of(sCtx).pop();
                  final hasUnsynced = appState.hasUnsyncedChanges;

                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (dCtx) => Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        MediaQuery.of(dCtx).padding.bottom + 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 30,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Capsule Drag Handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Apple Human Header
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.crimsonLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.crimson.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.logOut,
                                  color: AppColors.crimson,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sign Out',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                        letterSpacing: -0.45,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Choose what happens to data on this device',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w400,
                                        height: 1.3,
                                        letterSpacing: -0.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Offline warning banner if needed
                          if (hasUnsynced) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.amberLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(LucideIcons.cloudOff, color: AppColors.amberDark, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Unsynced logs found. Keeping offline data ensures no tax evidence is lost.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.amberDark,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Unified Apple-Grade Grouped List
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Column(
                              children: [
                                // Row 1: Keep on this iPhone (Safe & Recommended)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      Navigator.of(dCtx).pop();
                                      await appState.signOut(wipeLocalData: false);
                                    },
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.border.withValues(alpha: 0.8),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(LucideIcons.smartphone, color: AppColors.deepNavy, size: 19),
                                          ),
                                          const SizedBox(width: 14),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Keep on this iPhone',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.ink,
                                                    letterSpacing: -0.25,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Fast resume next time you sign in',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: AppColors.muted,
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Mathematically Snapped Divider: 16 (pad) + 40 (box) + 14 (gap) = 70
                                const Divider(height: 1, indent: 70, endIndent: 16, color: AppColors.border),

                                // Row 2: Remove from this iPhone (Destructive / Loaner)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.heavyImpact();
                                      Navigator.of(dCtx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: AppColors.ink,
                                          content: Text('Syncing cloud vault & securely clearing device...'),
                                        ),
                                      );
                                      await appState.signOut(wipeLocalData: true);
                                    },
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.crimsonLight,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.crimson.withValues(alpha: 0.15),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(LucideIcons.trash2, color: AppColors.crimson, size: 19),
                                          ),
                                          const SizedBox(width: 14),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Remove from this iPhone',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.crimson,
                                                    letterSpacing: -0.25,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Safe for borrowed or shared devices',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: AppColors.muted,
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(LucideIcons.chevronRight, size: 16, color: AppColors.crimson.withValues(alpha: 0.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cancel Button (Apple iOS Style Filled Secondary)
                          SizedBox(
                            height: 50,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.background,
                                foregroundColor: AppColors.ink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => Navigator.of(dCtx).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFallbackInitial(dynamic user) {
    return Container(
      color: AppColors.deepNavy,
      child: Center(
        child: Text(
          user != null && user.displayName != null && user.displayName!.isNotEmpty
              ? user.displayName![0].toUpperCase()
              : 'K',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
