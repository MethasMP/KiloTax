import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip.dart';
import '../../../../services/engine/evidence_review_service.dart';
import '../../../../state/app_state.dart';
import '../../home/widgets/quick_capture_bottom_sheet.dart';
import '../../trips/trip_detail_screen.dart';
import '../../trips/widgets/bulky_tools_badge.dart';

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
        const Text(
            'No trips logged for this vehicle yet. Auto-GPS or manual trips appear here.',
            style: AppType.body),
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
    final needsReview = appState.evidenceReview.items
        .whereType<TripReviewItem>()
        .any((i) => i.tripId == trip.id);
    final isBusiness = trip.classification == TripClassification.business;
    final classificationLabel = isBusiness
        ? 'Work'
        : trip.classification == TripClassification.personal
            ? 'Personal'
            : 'Unclassified';

    // Check for linked expenses (e.g. Bunnings, Fuel)
    final linkedExpenses = appState.expenses
        .where((e) => !e.isDeleted && trip.linkedExpenseIds.contains(e.id))
        .toList();

    final timeStr =
        '${trip.date.hour.toString().padLeft(2, '0')}:${trip.date.minute.toString().padLeft(2, '0')}';
    final dest = _place(trip.destinationAddress,
        trip.purpose.isEmpty ? 'Purpose not added' : trip.purpose);
    final orig = _place(trip.originAddress, 'Start not recorded');

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
            Flexible(
              child: Text(
                classificationLabel,
                style: AppType.secondary.copyWith(
                    color: AppColor.inkMuted, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$orig '),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.arrow_forward,
                    size: 16, color: AppColor.inkMuted, semanticLabel: 'to'),
              ),
              TextSpan(text: ' $dest'),
            ]),
            style: AppType.bodyStrong,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                Formatters.distance(trip.distanceKm),
                style: AppType.secondary,
              ),
              if (trip.endOdometer > 0)
                Text('· Odo ${trip.endOdometer.toInt()}',
                    style: AppType.secondary),
              if (trip.purpose.contains('Bulky Tools') ||
                  trip.purpose.contains('Heavy Tools'))
                BulkyToolsBadge(
                  compact: true,
                  onTap: () => BulkyToolsBadge.showAtoExplanationSheet(context),
                ),
              if (needsReview)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColor.attentionTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Needs review',
                      style: AppType.secondary.copyWith(
                          color: AppColor.attentionInk, fontSize: 11)),
                ),
            ],
          ),
          if (linkedExpenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: linkedExpenses.map((expense) {
                final supplierName =
                    expense.supplier ?? expense.category.displayName;
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
                    Flexible(
                        child: Text(
                      'Attached Receipt: $supplierName ${Formatters.currency(expense.amount)}',
                      style: AppType.secondary
                          .copyWith(color: AppColor.inkMuted, fontSize: 11),
                    )),
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
