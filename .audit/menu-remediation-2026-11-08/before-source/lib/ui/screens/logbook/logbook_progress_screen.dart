import 'widgets/odometer_gap_review_card.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_space.dart';
import 'widgets/logbook_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';
import '../trips/trip_quick_resolve_sheet.dart';
import 'widgets/odometer_camera_capture_sheet.dart';
import 'widgets/gap_bridge_sheet.dart';
import 'widgets/tax_exemption_streak_hero.dart';

/// Implements Screen 14: Logbook Progress from UI.png
/// - Title: "Logbook" + Settings icon
/// - "Week 4 of 12"
/// - Big circular gauge: "68.4% Business use"
/// - Distance stats: "142 km Business / 207 km Total"
/// - This week section:
///   - 3 work trips >
///   - ⚠ Missing purpose: 2 (Orange alert)
/// - Odometer section:
///   - Start 82,421 km
///   - End   83,012 km
class LogbookProgressScreen extends StatelessWidget {
  const LogbookProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final missingCount = appState.missingComplianceTrips.length;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStartMidnight =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final thisWeekWorkTrips = appState.trips
        .where((t) =>
            t.isBusiness && t.date.isAfter(weekStartMidnight) && !t.isDeleted)
        .length;

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: logbookAppBar(context, 'Logbook overview'),
      body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(S.xl),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OdometerGapReviewCard(appState: appState),
                  TaxExemptionStreakHero(appState: appState),
                  const SizedBox(height: S.xxl),
                  const LogbookSection('Review & activity',
                      subtitle: 'Keep the details of your driving up to date.'),
                  LogbookPanel(
                      child: Column(children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(AppIcons.trips,
                              size: AppIconSize.control,
                              color: AppColor.inkMuted),
                          const SizedBox(width: S.md),
                          Expanded(
                              child: Text(
                                  '$thisWeekWorkTrips ${thisWeekWorkTrips == 1 ? 'business trip' : 'business trips'} this week',
                                  style: AppType.bodyStrong)),
                        ]),
                    const Divider(height: S.xxxl, color: AppColor.hairline),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: S.sm,
                        leading:
                            Icon(missingCount > 0 ? AppIcons.attention : AppIcons.confirmed,
                                color: missingCount > 0
                                    ? AppColor.attentionInk
                                    : AppColor.positiveStrong,
                                size: AppIconSize.control),
                        title: Text(
                            missingCount > 0
                                ? '$missingCount ${missingCount == 1 ? 'trip needs' : 'trips need'} a purpose'
                                : 'No missing trip purposes',
                            style: AppType.bodyStrong),
                        subtitle: Text(
                            missingCount > 0
                                ? 'Review the details before reporting.'
                                : 'Your trip purposes are up to date.',
                            style: AppType.secondary),
                        trailing: missingCount > 0
                            ? const Icon(AppIcons.next,
                                color: AppColor.inkMuted,
                                size: AppIconSize.control)
                            : null,
                        onTap: missingCount > 0
                            ? () => TripQuickResolveSheet.show(context,
                                trip: appState.missingComplianceTrips.first,
                                appState: appState)
                            : null),
                  ])),
                  const SizedBox(height: S.xxl),
                  const LogbookSection('Odometer record'),
                  LogbookPanel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        _odometerValue(
                            'Starting reading', appState.startingOdometer),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColor.ink,
                                    minimumSize: const Size(48, 48)),
                                onPressed: () =>
                                    _showEditStartingOdometerDialog(
                                        context, appState),
                                icon: const Icon(AppIcons.edit,
                                    size: AppIconSize.inline),
                                label: const Text('Edit starting reading'))),
                        const Divider(height: S.xxl, color: AppColor.hairline),
                        _odometerValue(
                            'Latest reading', appState.currentOdometer),
                        const SizedBox(height: S.xl),
                        Container(
                            padding: const EdgeInsets.all(S.md),
                            decoration: BoxDecoration(
                                color: appState.isOdometerChainGapless
                                    ? AppColor.surfaceMuted
                                    : AppColor.attentionTintSoft,
                                borderRadius: R.controlR),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      appState.isOdometerChainGapless
                                          ? 'No odometer gaps detected'
                                          : 'An odometer gap needs review',
                                      style: AppType.secondary.copyWith(
                                          color: appState.isOdometerChainGapless
                                              ? AppColor.inkMuted
                                              : AppColor.attentionInk)),
                                  if (!appState.isOdometerChainGapless)
                                    TextButton(
                                        onPressed: () => GapBridgeSheet.show(
                                            context,
                                            appState: appState),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColor.attentionInk,
                                            minimumSize: const Size(48, 48)),
                                        child: const Text('Review gap')),
                                ])),
                      ])),
                  const SizedBox(height: S.xxl),
                  const LogbookSection('Photo evidence',
                      subtitle:
                          'Keep dashboard photos alongside your readings.'),
                  LogbookPanel(
                      child: Column(children: [
                    _buildPhotoProofRow(
                        context: context,
                        label: 'Starting odometer',
                        photoPath:
                            appState.primaryVehicle?.startOdometerPhotoPath,
                        onTap: () => _handleCapturePhoto(context, appState,
                            isStart: true)),
                    const Divider(height: S.xxl, color: AppColor.hairline),
                    _buildPhotoProofRow(
                        context: context,
                        label: 'Finishing odometer',
                        photoPath:
                            appState.primaryVehicle?.endOdometerPhotoPath,
                        onTap: () => _handleCapturePhoto(context, appState,
                            isStart: false)),
                  ])),
                  const SizedBox(height: S.xxl),
                ]),
          )),
    );
  }

  Widget _odometerValue(String label, double value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppType.secondary),
        const SizedBox(height: S.sm),
        Text(value > 0 ? '${Formatters.odometer(value)} km' : 'Not recorded',
            style: AppType.titleSmall.copyWith(fontFeatures: AppType.tabular)),
      ]);

  void _showEditStartingOdometerDialog(
      BuildContext context, AppState appState) {
    final controller = TextEditingController(
      text: appState.startingOdometer.toStringAsFixed(0),
    );
    final maxAllowed = appState.maxAllowedStartingOdometer;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(AppIcons.odometer,
                color: AppColors.workBlue, size: AppIconSize.control),
            SizedBox(width: 8),
            Text('Edit Starting Odometer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update opening odometer for the 12-week logbook period:',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.info,
                      size: AppIconSize.inline, color: AppColors.workBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      maxAllowed != null
                          ? 'ATO Rule: Must not exceed first trip start (${maxAllowed.toStringAsFixed(0)} km).'
                          : 'No trips logged yet: Editable freely.',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.ink),
              decoration: InputDecoration(
                suffixText: 'km',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newOdo =
                  double.tryParse(controller.text.replaceAll(',', '').trim());
              if (newOdo == null) return;

              final (isValid, errorMsg) =
                  appState.validateStartingOdometer(newOdo);
              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.crimson,
                    content: Text(errorMsg ?? 'Invalid starting odometer.'),
                  ),
                );
                return;
              }

              appState.updateStartingOdometer(newOdo);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.emerald,
                  content: Text(
                      '✓ Starting odometer updated to ${newOdo.toStringAsFixed(0)} km'),
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoProofRow({
    required BuildContext context,
    required String label,
    required String? photoPath,
    required VoidCallback onTap,
  }) {
    final isVerified = photoPath != null && photoPath.isNotEmpty;
    return Semantics(
        button: true,
        label:
            '$label, ${isVerified ? 'photo saved, replace photo' : 'add photo'}',
        child: InkWell(
          onTap: onTap,
          borderRadius: R.controlR,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: S.md),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(isVerified ? AppIcons.confirmed : AppIcons.camera,
                    size: AppIconSize.navigation,
                    color: isVerified
                        ? AppColor.positiveStrong
                        : AppColor.inkMuted),
                const SizedBox(width: S.md),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label, style: AppType.bodyStrong),
                      const SizedBox(height: S.xs),
                      Text(
                          isVerified
                              ? 'Photo saved · tap to replace'
                              : 'Tap to add a dashboard photo',
                          style: AppType.secondary),
                    ])),
                const Icon(AppIcons.next,
                    color: AppColor.inkMuted, size: AppIconSize.control),
              ])),
        ));
  }

  void _handleCapturePhoto(BuildContext context, AppState appState,
      {required bool isStart}) {
    OdometerCameraCaptureSheet.show(
      context,
      appState: appState,
      isStart: isStart,
    );
  }
}
