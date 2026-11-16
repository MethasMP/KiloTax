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
        bool isSyncing = false;
        bool isExporting = false;
        bool isSigningIn = false;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final user = appState.currentUser;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88,
                ),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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

              // Profile / Account State Card
              if (appState.isAuthenticated) ...[
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
                        child: user?.avatarUrl != null &&
                                user!.avatarUrl!.isNotEmpty
                            ? Image.network(
                                user.avatarUrl!,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackInitial(user),
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
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.email ?? 'Cloud Account',
                                  style: AppTextStyles.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.cloudCheck,
                                        size: 11, color: AppColors.emerald),
                                    SizedBox(width: 4),
                                    Text(
                                      'Synced',
                                      style: TextStyle(
                                        color: AppColors.emerald,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
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
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColor.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColor.line, width: 1.2),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.hardDrive,
                          size: 22,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Mode',
                            style: AppTextStyles.cardPrimary,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Trips and receipts saved on this phone',
                                  style: AppTextStyles.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 18),

              // Cloud Sync Card (Supabase Vault / 1-Tap Link)
              _buildCloudSyncCard(
                context,
                appState,
                setSheetState,
                isSyncing,
                isSigningIn,
                (val) => isSyncing = val,
                (val) => isSigningIn = val,
              ),

              const SizedBox(height: 12),

              // Local File Backup Tile (iCloud Drive / Files)
              _buildLocalBackupTile(
                context,
                appState,
                setSheetState,
                isExporting,
                (val) => isExporting = val,
              ),

              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Sign Out with Clean System Neutral Styling (Meta & Apple HIG standard) - Only when Authenticated
              if (appState.isAuthenticated) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    backgroundColor: AppColor.surfaceMuted,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.logOut, size: 17, color: AppColors.ink),
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
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
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
                            // Capsule Drag Handle
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
                            const SizedBox(height: 18),

                            // Clean Header
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColor.surfaceMuted,
                                    borderRadius: BorderRadius.circular(12),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.amberLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          AppColors.amber.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(LucideIcons.cloudOff,
                                        color: AppColors.amberDark, size: 18),
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

                            // Unified Grouped Settings List
                            Container(
                              decoration: BoxDecoration(
                                color: AppColor.surfaceSunken,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: AppColors.border, width: 1),
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
                                        await appState.signOut(
                                            wipeLocalData: false);
                                      },
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(18)),
                                      child: Padding(
                                       padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppColors.border
                                                      .withValues(alpha: 0.8),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                  LucideIcons.smartphone,
                                                  color: AppColors.deepNavy,
                                                  size: 19),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
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
                                            const Icon(LucideIcons.chevronRight,
                                                size: 16,
                                                color: AppColor.line),
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
                                        HapticFeedback.heavyImpact();
                                        // This wiped the device with no
                                        // confirmation while the subtitle played
                                        // it down as safe. The account-deletion
                                        // flow below was already guarded.
                                        final confirmed =
                                            await _confirmWipeLocalData(context);
                                        if (confirmed != true) return;
                                        if (!context.mounted) return;
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        Navigator.of(dCtx).pop();
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: AppColors.ink,
                                            content: Text(
                                                'Syncing cloud vault & securely clearing device...'),
                                          ),
                                        );
                                        await appState.signOut(
                                            wipeLocalData: true);
                                      },
                                      borderRadius: const BorderRadius.vertical(
                                          bottom: Radius.circular(18)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: AppColor.surfaceMuted,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                  LucideIcons.smartphoneNfc,
                                                  color: AppColors.muted,
                                                  size: 19),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Remove from this iPhone',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.ink,
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
                                            const Icon(LucideIcons.chevronRight,
                                                size: 16,
                                                color: AppColor.line),
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
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
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
                const SizedBox(height: 12),
              ],

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.messageSquare, color: AppColors.deepNavy),
                title: const Text('Product feedback'),
                subtitle: const Text('Save a note or preview it before sharing'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sCtx).pop();
                  FeedbackScreen.show(context);
                },
              ),
              const SizedBox(height: 8),

              // Delete Account & All Data / Reset Local Data (Quiet secondary link per iOS HIG)
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  onPressed: () {
                    Navigator.of(sCtx).pop();
                    if (appState.isAuthenticated) {
                      _showDeleteAccountConfirmation(context, appState);
                    } else {
                      _showResetLocalDataConfirmation(context, appState);
                    }
                  },
                  child: Text(
                    appState.isAuthenticated
                        ? 'Delete Account & All Data'
                        : 'Reset Local Data',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Legal Terms & Privacy Policy Links
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => LegalDocumentSheet.show(
                        context,
                        initialTab: LegalTab.privacy,
                      ),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('•',
                          style: TextStyle(
                              color: AppColor.line, fontSize: 12)),
                    ),
                    GestureDetector(
                      onTap: () => LegalDocumentSheet.show(
                        context,
                        initialTab: LegalTab.terms,
                      ),
                      child: const Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.brand),
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
              await appState.deleteAccount();
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
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.brand),
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
                      'Export Tax Pack First',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      final lastSync = appState.lastSyncedAt;
      String syncSubtitle = 'Continuous 5-Year ATO Backup';
      if (appState.syncStatus == SyncStatus.syncing || isSyncing) {
        syncSubtitle = 'Syncing cloud vault...';
      } else if (lastSync != null) {
        final diff = DateTime.now().difference(lastSync);
        if (diff.inMinutes < 1) {
          syncSubtitle = 'Synced just now';
        } else if (diff.inMinutes < 60) {
          syncSubtitle = 'Synced ${diff.inMinutes}m ago';
        } else {
          syncSubtitle = 'Synced ${diff.inHours}h ago';
        }
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColor.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.emeraldLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.cloudCheck,
                  size: 20, color: AppColors.emerald),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Cloud Vault',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '• 5-Year Shield',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    syncSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: AppColors.border, width: 1.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isSyncing
                    ? null
                    : () async {
                        HapticFeedback.lightImpact();
                        setSheetState(() => setSyncing(true));
                        final res = await appState.triggerSyncToCloud();
                        if (context.mounted) {
                          setSheetState(() => setSyncing(false));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: res.success
                                  ? AppColors.emerald
                                  : AppColors.crimson,
                              content: Text(
                                res.success
                                    ? 'Cloud Vault synced successfully.'
                                    : (res.errorMessage ?? 'Sync failed.'),
                              ),
                            ),
                          );
                        }
                      },
                child: isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.refreshCw,
                              size: 13, color: AppColors.ink),
                          SizedBox(width: 5),
                          Text(
                            'Sync',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
    }

    // Guest Mode: Card with 1-Tap Connect
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.surfaceSunken,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.line, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColor.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColor.line, width: 0.8),
                ),
                child: const Icon(LucideIcons.cloudUpload,
                    size: 18, color: AppColor.brand),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Backup',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColor.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Keep your trip logs and tax deductions safe',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColor.inkSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isSigningIn)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColor.brand,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        setSheetState(() => setSigningIn(true));
                        await appState.signInWithApple(
                          onLocalSuccess: (_) {
                            if (context.mounted) {
                              setSheetState(() => setSigningIn(false));
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.emerald,
                                  content: Text('Connected to Apple. Backup is active.'),
                                ),
                              );
                            }
                          },
                        );
                        if (context.mounted) {
                          setSheetState(() => setSigningIn(false));
                        }
                      },
                      icon: SvgPicture.asset(
                        'apple.svg',
                        width: 15,
                        height: 15,
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
                      ),
                      label: const Text(
                        'Apple ID',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColor.ink,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        side: const BorderSide(
                            color: AppColor.line, width: 1.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        setSheetState(() => setSigningIn(true));
                        await appState.signInWithGoogle(
                          onLocalSuccess: (_) {
                            if (context.mounted) {
                              setSheetState(() => setSigningIn(false));
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.emerald,
                                  content: Text('Connected to Google. Backup is active.'),
                                ),
                              );
                            }
                          },
                        );
                        if (context.mounted) {
                          setSheetState(() => setSigningIn(false));
                        }
                      },
                      icon: SvgPicture.asset(
                        'google.svg',
                        width: 15,
                        height: 15,
                      ),
                      label: const Text(
                        'Google',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColor.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _buildLocalBackupTile(
    BuildContext context,
    AppState appState,
    StateSetter setSheetState,
    bool isExporting,
    Function(bool) setExporting,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.line, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isExporting
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  setSheetState(() => setExporting(true));
                  final success = await LocalBackupService.exportBackupFile(
                      context, appState);
                  if (context.mounted) {
                    setSheetState(() => setExporting(false));
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.ink,
                          content: Text('Backup file ready in share sheet.'),
                        ),
                      );
                    }
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColor.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColor.line, width: 0.8),
                  ),
                  child: const Icon(
                    LucideIcons.download,
                    size: 18,
                    color: AppColor.ink,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Backup File',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColor.ink,
                          letterSpacing: -0.15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Save a copy to Files or iCloud Drive',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColor.inkSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isExporting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.ink,
                    ),
                  )
                else
                  const Icon(
                    LucideIcons.share2,
                    size: 16,
                    color: AppColors.muted,
                  ),
              ],
            ),
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
          user != null &&
                  user.displayName != null &&
                  user.displayName!.isNotEmpty
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
