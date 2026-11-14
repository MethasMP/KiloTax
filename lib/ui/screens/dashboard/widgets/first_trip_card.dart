import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../state/app_state.dart';
import '../../../../core/theme/app_color.dart';
import '../../home/widgets/quick_capture_bottom_sheet.dart';
import '../../tracking/tracking_setup_screen.dart';

class FirstTripCard extends StatelessWidget {
  final AppState appState;
  final bool showActions;
  const FirstTripCard(
      {super.key, required this.appState, this.showActions = true});

  @override
  Widget build(BuildContext context) {
    final hasTrips = appState.trips.isNotEmpty;
    if (hasTrips) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColor.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColor.hairline)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Start with your first trip',
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(
                'Add a past trip without location access, or choose GPS to record a drive as you go.',
                style: AppTextStyles.secondaryMedium),
            const SizedBox(height: 16),
            if (showActions) ...[
              FilledButton(
                  onPressed: () =>
                      QuickCaptureBottomSheet.showTripCaptureModeSheet(
                          context, appState),
                  child: const Text('Record your first trip')),
              TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const TrackingSetupScreen())),
                  child: const Text('Set up automatic recording')),
            ],
          ]),
        ),
      ),
    );
  }
}
