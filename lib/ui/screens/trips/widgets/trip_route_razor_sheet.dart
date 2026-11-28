import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/trip.dart';
import '../../../../services/tracking/trip_route_razor.dart';

enum RouteRazorMode { trimTail, splitMixed }

/// Standalone bottom sheet for the Post-Trip Route Razor (Axis A).
/// Lets a user trim a forgotten-stop commute tail or split a mixed trip into
/// Business + Personal legs while conserving odometer continuity and preserving
/// the raw telemetry audit snapshot.
class TripRouteRazorSheet extends StatefulWidget {
  final Trip trip;
  final List<RouteWaypoint> waypoints;
  final RouteRazorMode initialMode;
  final ValueChanged<RouteRazorResult> onApply;
  final String Function()? secondaryIdBuilder;

  const TripRouteRazorSheet({
    super.key,
    required this.trip,
    this.waypoints = const [],
    this.initialMode = RouteRazorMode.trimTail,
    required this.onApply,
    this.secondaryIdBuilder,
  });

  @override
  State<TripRouteRazorSheet> createState() => _TripRouteRazorSheetState();
}

class _TripRouteRazorSheetState extends State<TripRouteRazorSheet> {
  late RouteRazorMode _mode;
  late double _splitKm;
  RouteWaypoint? _selectedWaypoint;

  double get _minSplitKm => 0.1;
  double get _maxSplitKm =>
      (widget.trip.distanceKm - 0.1).clamp(0.1, widget.trip.distanceKm);

  bool get _canRazor => widget.trip.distanceKm > 0.25;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final usableWaypoints = _usableWaypoints();
    if (usableWaypoints.isNotEmpty) {
      _selectedWaypoint = usableWaypoints.first;
      _splitKm = usableWaypoints.first.cumulativeKm!
          .clamp(_minSplitKm, _maxSplitKm);
    } else {
      _splitKm = double.parse(
        (widget.trip.distanceKm * 0.7).clamp(_minSplitKm, _maxSplitKm).toStringAsFixed(1),
      );
    }
  }

  List<RouteWaypoint> _usableWaypoints() {
    return widget.waypoints
        .where((w) =>
            w.cumulativeKm != null &&
            w.cumulativeKm! > 0.05 &&
            w.cumulativeKm! < widget.trip.distanceKm - 0.05)
        .toList();
  }

  RouteRazorResult _buildPreviewResult() {
    final secondaryId = widget.secondaryIdBuilder?.call() ??
        '${widget.trip.id}_razor_${DateTime.now().millisecondsSinceEpoch}';
    if (_mode == RouteRazorMode.trimTail) {
      return TripRouteRazor.trimTailAtDistance(
        original: widget.trip,
        splitDistanceKm: _splitKm,
        secondaryTripId: secondaryId,
        splitWaypoint: _selectedWaypoint,
      );
    }
    return TripRouteRazor.splitMixedTrip(
      original: widget.trip,
      businessKm: _splitKm,
      secondaryTripId: secondaryId,
      splitWaypoint: _selectedWaypoint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usableWaypoints = _usableWaypoints();
    final preview = _canRazor ? _buildPreviewResult() : null;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: R.sheetTopR,
        ),
        padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: R.chipR,
                  ),
                ),
              ),
              const SizedBox(height: S.lg),
              Row(
                children: [
                  const Icon(
                    AppIcons.trips,
                    color: AppColor.brand,
                    size: AppIconSize.navigation,
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text('Route Razor', style: AppType.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close, size: AppIconSize.control),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: S.xs),
              Text(
                'Original trip: ${widget.trip.distanceKm.toStringAsFixed(1)} km • ${widget.trip.purpose}',
                style: AppType.secondary,
              ),
              const SizedBox(height: S.lg),
              if (!_canRazor)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(S.lg),
                  decoration: BoxDecoration(
                    color: AppColor.attentionTintSoft,
                    borderRadius: R.cardR,
                    border: Border.all(color: AppColor.attentionTintStrong),
                  ),
                  child: Text(
                    'This trip is too short (${widget.trip.distanceKm.toStringAsFixed(2)} km) to split or trim.',
                    style: AppType.body,
                  ),
                )
              else ...[
                SegmentedButton<RouteRazorMode>(
                  segments: const [
                    ButtonSegment(
                      value: RouteRazorMode.trimTail,
                      label: Text('Trim Commute Tail'),
                    ),
                    ButtonSegment(
                      value: RouteRazorMode.splitMixed,
                      label: Text('Split Mixed Leg'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    HapticFeedback.selectionClick();
                    setState(() => _mode = selection.first);
                  },
                ),
                if (usableWaypoints.isNotEmpty) ...[
                  const SizedBox(height: S.lg),
                  Text('DETECTED STOP PINS', style: AppType.eyebrow),
                  const SizedBox(height: S.sm),
                  Wrap(
                    spacing: S.sm,
                    runSpacing: S.sm,
                    children: usableWaypoints.map((wp) {
                      final isSelected = _selectedWaypoint == wp;
                      final label = wp.label ??
                          '${wp.cumulativeKm!.toStringAsFixed(1)} km';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedWaypoint = wp;
                            _splitKm = wp.cumulativeKm!
                                .clamp(_minSplitKm, _maxSplitKm);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: S.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BUSINESS CUTOFF', style: AppType.eyebrow),
                    Text(
                      '${_splitKm.toStringAsFixed(1)} km of ${widget.trip.distanceKm.toStringAsFixed(1)} km',
                      style: AppType.cardNumeric,
                    ),
                  ],
                ),
                Slider(
                  value: _splitKm.clamp(_minSplitKm, _maxSplitKm),
                  min: _minSplitKm,
                  max: _maxSplitKm,
                  activeColor: AppColor.brand,
                  onChanged: (value) {
                    setState(() {
                      _selectedWaypoint = null;
                      _splitKm = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
                const SizedBox(height: S.sm),
                if (preview != null) ...[
                  _LegPreviewCard(
                    title: 'Leg 1 · Business',
                    distanceKm: preview.primaryTrip.distanceKm,
                    startOdo: preview.primaryTrip.startOdometer,
                    endOdo: preview.primaryTrip.endOdometer,
                    accent: AppColor.positive,
                    tint: AppColor.positiveTint,
                  ),
                  const SizedBox(height: S.sm),
                  _LegPreviewCard(
                    title: 'Leg 2 · Personal',
                    distanceKm: preview.secondaryTrip.distanceKm,
                    startOdo: preview.secondaryTrip.startOdometer,
                    endOdo: preview.secondaryTrip.endOdometer,
                    accent: AppColor.inkMuted,
                    tint: AppColor.surfaceMuted,
                  ),
                  const SizedBox(height: S.md),
                  Row(
                    children: [
                      const Icon(
                        AppIcons.confirmed,
                        size: AppIconSize.inline,
                        color: AppColor.positive,
                      ),
                      const SizedBox(width: S.xs),
                      Expanded(
                        child: Text(
                          'Odometer conserved & raw telemetry audit snapshot retained.',
                          style: AppType.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: S.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColor.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: S.md),
                      shape: RoundedRectangleBorder(borderRadius: R.controlR),
                    ),
                    onPressed: preview == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            widget.onApply(preview);
                          },
                    child: Text(
                      _mode == RouteRazorMode.trimTail
                          ? 'Trim Tail & Save Legs'
                          : 'Split Mixed Trip',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegPreviewCard extends StatelessWidget {
  final String title;
  final double distanceKm;
  final double startOdo;
  final double endOdo;
  final Color accent;
  final Color tint;

  const _LegPreviewCard({
    required this.title,
    required this.distanceKm,
    required this.startOdo,
    required this.endOdo,
    required this.accent,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final hasOdo = endOdo > startOdo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: R.controlR,
        border: Border.all(color: AppColor.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.bodyStrong.copyWith(color: accent),
                ),
                if (hasOdo)
                  Text(
                    'Odo: ${startOdo.toStringAsFixed(1)} → ${endOdo.toStringAsFixed(1)} km',
                    style: AppType.secondary,
                  ),
              ],
            ),
          ),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: AppType.cardNumeric,
          ),
        ],
      ),
    );
  }
}
