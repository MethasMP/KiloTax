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
    final isBusiness = trip.classification == TripClassification.business;
    final rate = appState.activeTaxRule.centsPerKmRate;
    final claimValue = trip.distanceKm * rate;

    // Check for linked expenses (e.g. Bunnings, Fuel)
    final linkedExpenses = appState.expenses
        .where((e) => trip.linkedExpenseIds.contains(e.id))
        .toList();

    final timeStr =
        '${trip.date.hour.toString().padLeft(2, '0')}:${trip.date.minute.toString().padLeft(2, '0')}';
    final dest = _place(trip.destinationAddress,
        trip.purpose.isEmpty ? 'Job Site' : trip.purpose);
    final orig = _place(trip.originAddress, 'Origin');

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TripDetailScreen(trip: trip, appState: appState))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.directions_car_outlined,
                size: 16, color: AppColor.inkMuted),
            const SizedBox(width: 6),
            Text(timeStr, style: AppType.secondary),
            const SizedBox(width: 8),
            const Spacer(),
            if (isBusiness)
              Flexible(
                child: Text(
                  '+${Formatters.currency(claimValue)} claim',
                  style: AppType.secondary.copyWith(
                      color: AppColor.positiveStrong,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('$orig ➔ $dest', style: AppType.bodyStrong),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${Formatters.distance(trip.distanceKm)} business',
                style: AppType.secondary,
              ),
              if (trip.endOdometer > 0)
                Text('· Odo ${trip.endOdometer.toInt()}',
                    style: AppType.secondary),
              if (needsReview)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColor.attentionTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Needs review',
                      style: AppType.secondary
                          .copyWith(color: AppColor.attentionInk, fontSize: 11)),
                ),
            ],
          ),
          if (linkedExpenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: linkedExpenses.map((expense) {
                final supplierName = expense.supplier ?? expense.category.displayName;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColor.line),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 13, color: AppColor.inkSubtle),
                    const SizedBox(width: 4),
                    Text(
                      'Attached Receipt: $supplierName ${Formatters.currency(expense.amount)}',
                      style: AppType.secondary
                          .copyWith(color: AppColor.inkMuted, fontSize: 11),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ],
        ]),
      ),
    );
  }
}
