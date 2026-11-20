import 'package:flutter/material.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../data/models/trip.dart';
import '../../../../state/app_state.dart';
import '../../workflow/workflow_screen.dart';

/// Amber badge displayed on trips that lack evidence links.
/// Conforms to:
/// - Evidence Graph invariant: unlinked trips show amber "Needs evidence" badge.
/// - Touch ergonomics: minimum 48x48dp interactive touch target.
/// - Navigation: tapping navigates to WorkflowScreen for that trip.
class TripEvidenceBadge extends StatelessWidget {
  final Trip trip;
  final AppState? appState;
  final VoidCallback? onTap;

  const TripEvidenceBadge(
    this.trip, {
    super.key,
    this.appState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If the trip already has evidence attached, render nothing
    if (trip.evidenceLinks.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          final state = appState ?? AppState();
          WorkflowScreen.show(context, state);
        },
        borderRadius: BorderRadius.circular(8.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48.0,
            minHeight: 48.0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppColor.attentionTint,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: AppColor.attentionStrong.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16.0,
                  color: AppColor.attentionInk,
                ),
                const SizedBox(width: 6.0),
                const Text(
                  'Needs evidence',
                  style: TextStyle(
                    color: AppColor.attentionInk,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
