import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../services/tracking/odometer_gap_reconciler.dart';
import '../../../../state/app_state.dart';
import '../logbook_trip_entry_screen.dart';

class GapBridgeSheet extends StatelessWidget {
  final OdometerGap gap;
  const GapBridgeSheet({super.key, required this.gap});

  static Future<bool?> show(BuildContext context,
      {required AppState appState}) async {
    final gap = appState.findFirstOdometerGap();
    if (gap == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No unrecorded odometer gaps to review.')));
      return false;
    }
    final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColor.surface,
        shape: RoundedRectangleBorder(borderRadius: R.sheetTopR),
        builder: (_) => GapBridgeSheet(gap: gap));
    if (proceed != true || !context.mounted) return false;
    if (appState.primaryVehicle?.id != gap.vehicleId ||
        !appState.isUnrecordedOdometerSpan(
            vehicleId: gap.vehicleId,
            startOdo: gap.startOdo,
            endOdo: gap.endOdo,
            legacyTripId: gap.legacyTripId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'This gap has changed. Open the latest odometer record to review it.')));
      return false;
    }
    final legacy = appState.trips.where((t) => t.id == gap.legacyTripId);
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LogbookTripEntryScreen(
            appState: appState,
            odometerGap: gap,
            detectedTrip: legacy.isEmpty ? null : legacy.first)));
    return true;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(S.xxl),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(
                    child: Text('Review missing travel',
                        style: AppType.titleSmall)),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon:
                        const Icon(AppIcons.close, size: AppIconSize.control)),
              ]),
              const SizedBox(height: S.sm),
              Text('${Formatters.distance(gap.distance)} needs your review',
                  style: AppType.cardTitle),
              const SizedBox(height: S.lg),
              Container(
                  padding: S.cardPad,
                  decoration: BoxDecoration(
                      color: AppColor.surfaceMuted, borderRadius: R.cardR),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('READINGS TO RECONCILE',
                            style: AppType.eyebrow),
                        const SizedBox(height: S.md),
                        Text(
                            '${Formatters.odometer(gap.startOdo)} → ${Formatters.odometer(gap.endOdo)} km',
                            style: AppType.metricSmall),
                        const SizedBox(height: S.sm),
                        Text(
                            gap.legacyTripId == null
                                ? 'There is travel between these readings that has not been recorded.'
                                : 'An older version filled this difference automatically. Its date and travel type still need your confirmation.',
                            style: AppType.body),
                      ])),
              const SizedBox(height: S.lg),
              const Text(
                  'The readings do not tell us when or why you travelled. Add only the trips you can confirm.',
                  style: AppType.body),
              const SizedBox(height: S.sm),
              Text(
                  gap.legacyTripId == null
                      ? 'More than one trip? Add one at a time and adjust the distance. The remaining difference will stay visible.'
                      : 'Review the existing entry before relying on it in your logbook.',
                  style: AppType.secondary),
              const SizedBox(height: S.xxl),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColor.surfaceNavy,
                      foregroundColor: AppColor.onNavy,
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.all(S.lg),
                      shape: RoundedRectangleBorder(borderRadius: R.controlR)),
                  child: Text(
                      gap.legacyTripId == null
                          ? 'Add missing trip'
                          : 'Review existing entry',
                      textAlign: TextAlign.center)),
              const SizedBox(height: S.sm),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.ink,
                      minimumSize: const Size(48, 48)),
                  child: const Text('Leave unresolved for now')),
            ]),
      ));
}
