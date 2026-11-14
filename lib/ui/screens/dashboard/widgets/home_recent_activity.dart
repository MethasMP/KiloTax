import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../state/app_state.dart';
import '../../home/widgets/quick_capture_bottom_sheet.dart';
import '../../trips/trip_detail_screen.dart';

/// Recent records support the next task; amounts belong in Tax.
class HomeRecentActivity extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onViewAll;
  final VoidCallback? onLogDrive;
  const HomeRecentActivity(
      {super.key, required this.appState, this.onViewAll, this.onLogDrive});

  String _place(String? value, String fallback) =>
      value == null || value.trim().isEmpty
          ? fallback
          : value.split(',').first.trim();

  @override
  Widget build(BuildContext context) {
    final trips = appState.evidenceReview.trips.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('Recent trips', style: AppType.section)),
        if (onViewAll != null && trips.isNotEmpty)
          TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('View all')),
      ]),
      const SizedBox(height: 8),
      if (trips.isEmpty) ...[
        const Text('No trips recorded yet.', style: AppType.body),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onLogDrive ??
                  () => QuickCaptureBottomSheet.showTripCaptureModeSheet(
                      context, appState),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Add a trip'),
            )),
      ] else
        Material(
            color: AppColor.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColor.hairline)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < trips.take(3).length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColor.hairline),
                _row(context, trips[i]),
              ],
            ])),
    ]);
  }

  Widget _row(BuildContext context, Trip trip) {
    final needsReview =
        appState.missingComplianceTrips.any((t) => t.id == trip.id);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
          _place(trip.destinationAddress,
              trip.purpose.isEmpty ? 'Trip details' : trip.purpose),
          style: AppType.bodyStrong),
      subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'from ${_place(trip.originAddress, 'Starting location not recorded')}',
                style: AppType.secondary),
            Text(
                '${Formatters.date(trip.date)} · ${Formatters.distance(trip.distanceKm)}',
                style: AppType.secondary),
            if (needsReview)
              Text('Needs review',
                  style:
                      AppType.secondary.copyWith(color: AppColor.attentionInk)),
          ])),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TripDetailScreen(trip: trip, appState: appState))),
    );
  }
}
