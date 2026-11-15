import '../../tracking/tracking_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/engine/tax_pack_share_helper.dart';
import '../../../../services/storage/local_backup_service.dart';
import '../../../../state/app_state.dart';
import '../../../widgets/legal_document_sheet.dart';
import '../../feedback/feedback_screen.dart';
import '../../../../core/theme/app_color.dart';

class AccountSettingsSheet {
  static void show(BuildContext context, AppState appState) {
    HapticFeedback.mediumImpact();
    // Warm DNS/TLS socket to Supabase Auth in background before user taps OAuth buttons
    appState.prewarmAuthConnection();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sCtx) {
        String section = 'Settings';
        bool isSyncing = false;
        bool isExporting = false;
        bool isSigningIn = false;

        return ListenableBuilder(
          listenable: appState,
          builder: (_, __) => StatefulBuilder(
            builder: (sheetCtx, setSheetState) {
              final user = appState.currentUser;
              if (appState.isAuthenticated && section == 'Sign in') {
                section = 'Account & sync';
              }

              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.88),
                  child: SingleChildScrollView(
                    key: ValueKey(section),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: AppColor.line,
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (section != 'Settings')
                            IconButton(
                              tooltip: 'Back to Settings',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              onPressed: isSigningIn || isSyncing || isExporting
                                  ? null
                                  : () =>
                                      setSheetState(() => section = 'Settings'),
                              icon:
                                  const Icon(LucideIcons.chevronLeft, size: 24),
                            ),
                          Expanded(
                              child: Text(section,
                                  style: AppTextStyles.sectionTitle)),
                          IconButton(
                            tooltip: 'Close settings',
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(LucideIcons.x, size: 20),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        if (section == 'Settings') ...[
                          if (!appState.isAuthenticated) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColor.ink,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.all(16),
                              ),
                              onPressed: () =>
                                  setSheetState(() => section = 'Sign in'),
                              icon: const Icon(LucideIcons.logIn, size: 20),
                              label: const Text('Sign in'),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _sectionLabel('Recording'),
                          _settingsRow(
                            icon: LucideIcons.navigation,
                            title: 'Automatic trip recording',
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const TrackingSetupScreen()));
                            },
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Data'),
                          if (appState.isAuthenticated) ...[
                            _settingsRow(
                              icon: LucideIcons.cloud,
                              title: 'Account & sync',
                              subtitle: _syncSubtitle(appState, false),
                              onTap: () => setSheetState(
                                  () => section = 'Account & sync'),
                            ),
                            const Divider(
                                height: 1, indent: 48, color: AppColor.line),
                          ],
                          _settingsRow(
                            icon: LucideIcons.database,
                            title: 'Manage data',
                            onTap: () =>
                                setSheetState(() => section = 'Manage data'),
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Support'),
                          _settingsRow(
                            icon: LucideIcons.messageSquare,
                            title: 'Send feedback',
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              FeedbackScreen.show(context);
                            },
                          ),
                          const Divider(
                              height: 1, indent: 48, color: AppColor.line),
                          _settingsRow(
                            icon: LucideIcons.shield,
                            title: 'Privacy & terms',
                            onTap: () => LegalDocumentSheet.show(sheetCtx),
                          ),
                        ] else if (section == 'Sign in') ...[
                          _buildCloudSyncCard(
                              sheetCtx,
                              appState,
                              setSheetState,
                              isSyncing,
                              isSigningIn,
                              (val) => isSyncing = val,
                              (val) => isSigningIn = val),
                        ] else if (section == 'Account & sync') ...[
                          if (appState.isAuthenticated) ...[
                            Text(user?.displayName ?? 'Your account',
                                style: AppTextStyles.cardPrimary),
                            if (user != null)
                              Text(user.email, style: AppTextStyles.caption),
                            const SizedBox(height: 20),
                          ],
                          _buildCloudSyncCard(
                              sheetCtx,
                              appState,
                              setSheetState,
                              isSyncing,
                              isSigningIn,
                              (val) => isSyncing = val,
                              (val) => isSigningIn = val),
                        ] else ...[
                          const Text(
                              'Manage the records stored on this device.',
                              style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColor.inkMuted)),
                          const SizedBox(height: 20),
                          // Sign Out with Clean System Neutral Styling (Meta & Apple HIG standard) - Only when Authenticated
                          if (appState.isAuthenticated) ...[
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                backgroundColor: AppColor.surfaceMuted,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(LucideIcons.logOut,
                                  size: 17, color: AppColors.ink),
                              label: const Text('Sign Out',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: -0.1)),
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
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(28)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColor.scrimMedium,
                                          blurRadius: 30,
                                          offset: Offset(0, -4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Capsule Drag Handle
                                        Center(
                                          child: Container(
                                            width: 36,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: AppColor.line,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),

                                        // Clean Header
                                        Row(
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: AppColor.surfaceMuted,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                LucideIcons.logOut,
                                                color: AppColors.ink,
                                                size: 19,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Sign Out',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                      fontWeight:
                                                          FontWeight.w400,
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: AppColors.amberLight,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                  color: AppColors.amber
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(LucideIcons.cloudOff,
                                                    color: AppColors.amberDark,
                                                    size: 18),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Unsynced logs found. Keeping offline data ensures no tax evidence is lost.',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          AppColors.amberDark,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],

                                        // Unified Grouped Settings List
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColor.surfaceSunken,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                                color: AppColors.border,
                                                width: 1),
                                          ),
                                          child: Column(
                                            children: [
                                              // Row 1: Keep on this iPhone (Safe & Recommended)
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () async {
                                                    HapticFeedback
                                                        .mediumImpact();
                                                    Navigator.of(dCtx).pop();
                                                    await appState.signOut(
                                                        wipeLocalData: false);
                                                  },
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              18)),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .border
                                                                  .withValues(
                                                                      alpha:
                                                                          0.8),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: const Icon(
                                                              LucideIcons
                                                                  .smartphone,
                                                              color: AppColors
                                                                  .deepNavy,
                                                              size: 19),
                                                        ),
                                                        const SizedBox(
                                                            width: 14),
                                                        const Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Keep on this iPhone',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      AppColors
                                                                          .ink,
                                                                  letterSpacing:
                                                                      -0.25,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                'Fast resume next time you sign in',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      12.5,
                                                                  color:
                                                                      AppColors
                                                                          .muted,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  height: 1.25,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const Icon(
                                                            LucideIcons
                                                                .chevronRight,
                                                            size: 16,
                                                            color:
                                                                AppColor.line),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Mathematically Snapped Divider: 16 (pad) + 40 (box) + 14 (gap) = 70
                                              const Divider(
                                                  height: 1,
                                                  indent: 70,
                                                  endIndent: 16,
                                                  color: AppColors.border),

                                              // Row 2: Remove from this iPhone (Destructive / Loaner)
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () async {
                                                    HapticFeedback
                                                        .heavyImpact();
                                                    // This wiped the device with no
                                                    // confirmation while the subtitle played
                                                    // it down as safe. The account-deletion
                                                    // flow below was already guarded.
                                                    final confirmed =
                                                        await _confirmWipeLocalData(
                                                            context);
                                                    if (confirmed != true) {
                                                      return;
                                                    }
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    final messenger =
                                                        ScaffoldMessenger.of(
                                                            context);
                                                    Navigator.of(dCtx).pop();
                                                    messenger.showSnackBar(
                                                      const SnackBar(
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        backgroundColor:
                                                            AppColors.ink,
                                                        content: Text(
                                                            'Syncing cloud vault & securely clearing device...'),
                                                      ),
                                                    );
                                                    await appState.signOut(
                                                        wipeLocalData: true);
                                                  },
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          bottom:
                                                              Radius.circular(
                                                                  18)),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColor
                                                                .surfaceMuted,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: const Icon(
                                                              LucideIcons
                                                                  .smartphoneNfc,
                                                              color: AppColors
                                                                  .muted,
                                                              size: 19),
                                                        ),
                                                        const SizedBox(
                                                            width: 14),
                                                        const Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Remove from this iPhone',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      AppColors
                                                                          .ink,
                                                                  letterSpacing:
                                                                      -0.25,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                'Safe for borrowed or shared devices',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      12.5,
                                                                  color:
                                                                      AppColors
                                                                          .muted,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  height: 1.25,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const Icon(
                                                            LucideIcons
                                                                .chevronRight,
                                                            size: 16,
                                                            color:
                                                                AppColor.line),
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
                                              backgroundColor:
                                                  AppColors.background,
                                              foregroundColor: AppColors.ink,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14)),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(),
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
                            const SizedBox(height: 12),
                          ],

                          _buildLocalBackupTile(
                              sheetCtx,
                              appState,
                              setSheetState,
                              isExporting,
                              (val) => isExporting = val),
                          _settingsRow(
                            icon: LucideIcons.upload,
                            title: 'Restore backup file',
                            subtitle:
                                'Merge records, receipt images and pending drafts',
                            onTap: () => LocalBackupService.restoreFromFile(
                                sheetCtx, appState),
                          ),
                          const Divider(
                              height: 1, indent: 40, color: AppColor.line),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            minVerticalPadding: 16,
                            leading: const Icon(LucideIcons.trash2,
                                size: 22, color: AppColors.crimson),
                            title: Text(
                                appState.isAuthenticated
                                    ? 'Delete Account & All Data'
                                    : 'Reset Local Data',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.crimson)),
                            subtitle: Text(
                                appState.isAuthenticated
                                    ? 'Permanently erase your account and records.'
                                    : 'Erase the records saved on this device.',
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: AppColor.inkMuted)),
                            trailing: const Icon(LucideIcons.chevronRight,
                                size: 18, color: AppColor.inkSubtle),
                            onTap: () {
                              Navigator.of(sCtx).pop();
                              if (appState.isAuthenticated) {
                                _showDeleteAccountConfirmation(
                                    context, appState);
                              } else {
                                _showResetLocalDataConfirmation(
                                    context, appState);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColor.inkMuted)),
      );

  static Widget _settingsRow(
          {required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback? onTap}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        minLeadingWidth: 24,
        minVerticalPadding: 12,
        minTileHeight: 56,
        horizontalTitleGap: 16,
        leading: Icon(icon, size: 22, color: AppColor.ink),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColor.ink)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: AppColor.inkMuted)),
        trailing: const Icon(LucideIcons.chevronRight,
            size: 18, color: AppColor.inkSubtle),
        onTap: onTap,
      );

  static String _syncSubtitle(AppState appState, bool isSyncing) {
    if (appState.syncStatus == SyncStatus.error) return 'Sync needs attention';
    if (appState.syncStatus == SyncStatus.syncing || isSyncing) {
      return 'Syncing…';
    }
    final lastSync = appState.lastSyncedAt;
    if (lastSync == null) return 'Not synced yet';
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }

  static void _showDeleteAccountConfirmation(
      BuildContext context, AppState appState) {
    showAdaptiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog.adaptive(
        title: const Text(
          'Delete Account?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'All cloud backups, trips, and receipts will be permanently removed. This action cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.35, color: AppColor.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: AppColor.brand),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.crimson,
                  content: Text('Permanently deleting account and all data...'),
                ),
              );
              final deleted = await appState.deleteAccount();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(deleted
                      ? 'Account deleted.'
                      : 'Could not delete your account. Your local records are kept. Please try again.'),
                ));
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.crimson),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _confirmWipeLocalData(BuildContext context) {
    return showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog.adaptive(
        title: const Text(
          'Remove from this iPhone?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Any trips not backed up to the cloud will be erased from this device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.35, color: AppColor.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Cancel',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: AppColor.brand),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'Remove & Erase',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.crimson),
            ),
          ),
        ],
      ),
    );
  }

  static void _showResetLocalDataConfirmation(
      BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogCtx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(dialogCtx).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColor.scrimMedium,
              blurRadius: 30,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColor.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Icon
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.crimsonLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.crimson,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title & Direct Explanation
            const Text(
              'Reset all local data?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColor.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'All vehicle profiles, trip logs, and receipt photos on this phone will be permanently erased.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColor.inkSubtle,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Priority 1 (RECOMMENDED): Solid Safe CTA with badge
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  TaxPackShareHelper.shareTaxPack(context, appState);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.fileSpreadsheet, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Send to accountant',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(Recommended)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Priority 2: Safe Dismissal (Outlined)
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColor.ink,
                  side: const BorderSide(color: AppColor.line, width: 1.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'Keep Data & Cancel',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Priority 3: Destructive Action (Lowest Visual Weight, Text Button)
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.crimson,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.crimson,
                      content: Text('All local data cleared from this device.'),
                    ),
                  );
                  await appState.resetLocalData();
                },
                child: const Text(
                  'Erase Everything Anyway',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.crimson,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCloudSyncCard(
    BuildContext context,
    AppState appState,
    StateSetter setSheetState,
    bool isSyncing,
    bool isSigningIn,
    Function(bool) setSyncing,
    Function(bool) setSigningIn,
  ) {
    if (appState.isAuthenticated) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Cloud sync', style: AppTextStyles.cardPrimary),
        const SizedBox(height: 8),
        Text(_syncSubtitle(appState, isSyncing),
            style: const TextStyle(fontSize: 14, color: AppColor.inkMuted)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(LucideIcons.refreshCw, size: 20),
          label: Text(isSyncing ? 'Syncing…' : 'Sync now'),
          onPressed: isSyncing
              ? null
              : () async {
                  setSheetState(() => setSyncing(true));
                  final result = await appState.triggerSyncToCloud();
                  if (!context.mounted) return;
                  setSheetState(() => setSyncing(false));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result.success
                          ? 'Records synced.'
                          : (result.errorMessage ??
                              'Sync failed. Please try again.'))));
                },
        ),
      ]);
    }
    Future<void> signIn(bool apple) async {
      HapticFeedback.lightImpact();
      setSheetState(() => setSigningIn(true));
      final result = apple
          ? await appState.signInWithApple()
          : await appState.signInWithGoogle();
      if (!context.mounted) return;
      setSheetState(() => setSigningIn(false));
      final error = result.errorMessage;
      if (!result.success &&
          error != null &&
          !RegExp('cancel|dismiss|closed|1001', caseSensitive: false)
              .hasMatch(error)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Back up across devices', style: AppTextStyles.cardPrimary),
      const SizedBox(height: 8),
      const Text(
          'Your records are saved on this device. Sign in to connect cloud backup.',
          style:
              TextStyle(fontSize: 14, height: 1.4, color: AppColor.inkMuted)),
      const SizedBox(height: 20),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: AppColor.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.all(16)),
        onPressed: isSigningIn ? null : () => signIn(true),
        icon: SvgPicture.asset('apple.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        label: const Text('Continue with Apple', textAlign: TextAlign.center),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColor.ink,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.all(16)),
        onPressed: isSigningIn ? null : () => signIn(false),
        icon: SvgPicture.asset('google.svg', width: 18, height: 18),
        label: const Text('Continue with Google', textAlign: TextAlign.center),
      ),
      if (isSigningIn)
        const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)))),
    ]);
  }

  static Widget _buildLocalBackupTile(
      BuildContext context,
      AppState appState,
      StateSetter setSheetState,
      bool isExporting,
      Function(bool) setExporting) {
    return _settingsRow(
      icon: LucideIcons.download,
      title: isExporting ? 'Preparing backup…' : 'Export backup file',
      subtitle: 'Include receipt images and pending drafts',
      onTap: isExporting
          ? null
          : () async {
              HapticFeedback.lightImpact();
              setSheetState(() => setExporting(true));
              final success =
                  await LocalBackupService.exportBackupFile(context, appState);
              if (!context.mounted) return;
              setSheetState(() => setExporting(false));
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Backup file ready in share sheet.')));
              }
            },
    );
  }
}
