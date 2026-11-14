import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../state/app_state.dart';
import '../../trips/trip_detection_screen.dart';
import '../../trips/trip_live_tracking_screen.dart';

class DrivingLiveTicker extends StatelessWidget {
  final AppState appState;

  const DrivingLiveTicker({super.key, required this.appState});

  void _onCapsuleTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripLiveTrackingScreen(appState: appState),
      ),
    );
  }

  void _onStopDrive(BuildContext context) {
    HapticFeedback.heavyImpact();
    final trip = appState.finishLiveDriveForReview();
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No distance recorded yet. Continue tracking or open tracking to discard this drive.'),
      ));
      return;
    }
    TripDetectionScreen.show(context, appState, trip: trip);
  }

  @override
  Widget build(BuildContext context) {
    final started = appState.activeDriveStartedAt;
    final startedLabel = started == null
        ? ''
        : 'Started ${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')} · ';
    return Container(
      key: const ValueKey('home-active-drive'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF192C36),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          _EqualizerBars(),
          SizedBox(width: 8),
          Expanded(
              child: Text('RECORDING YOUR DRIVE',
                  style: TextStyle(
                      color: AppColor.onNavyMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 18),
        Text('${appState.activeDriveDistanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
                color: AppColor.onNavy,
                fontSize: 40,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${startedLabel}GPS distance estimate',
            style: const TextStyle(color: AppColor.onNavyMuted, fontSize: 13)),
        const SizedBox(height: 8),
        const Text(
            'Review the trip purpose when you finish. Your deduction is calculated after review.',
            style: TextStyle(
                color: AppColor.onNavyMuted, fontSize: 13, height: 1.4)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _StopDriveButton(onStop: () => _onStopDrive(context)),
          OutlinedButton.icon(
            onPressed: () => _onCapsuleTap(context),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColor.onNavy,
                side: const BorderSide(color: AppColor.onNavyMuted),
                minimumSize: const Size(48, 48)),
            icon: const Icon(LucideIcons.maximize2, size: 18),
            label: const Text('Open tracking'),
          ),
        ]),
      ]),
    );
  }
}

/// Minimal Live Telemetry Status Jewel (Subtle breathing pulse instead of audio equalizer bars)
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.10 + (t * 0.08)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StopDriveButton extends StatelessWidget {
  final VoidCallback onStop;
  const _StopDriveButton({required this.onStop});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onStop,
        style: FilledButton.styleFrom(
            backgroundColor: AppColor.brand,
            foregroundColor: AppColor.onNavy,
            minimumSize: const Size(48, 48)),
        icon: const Icon(LucideIcons.square, size: 16),
        label: const Text('Finish & review'),
      );
}
