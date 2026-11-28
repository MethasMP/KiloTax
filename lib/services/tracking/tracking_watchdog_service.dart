import 'package:flutter/foundation.dart';

import '../../data/models/trip.dart';

/// Device OS / OEM profile for tailored background-tracking survival guidance.
enum DevicePlatformKind {
  androidSamsung,
  androidXiaomi,
  androidOppo,
  androidGeneric,
  ios,
  other,
}

/// Overall health of the background trip tracking pipeline.
enum WatchdogHealthStatus {
  healthy,
  permissionDegraded,
  batterySaverRisk,
  staleGapDetected,
}

/// Diagnostic report produced by the Silent-Death Watchdog.
@immutable
class WatchdogReport {
  final WatchdogHealthStatus status;
  final double? hoursSinceLastActivity;
  final bool isStaleGap;
  final bool hasBackgroundPermission;
  final bool isBatteryOptimizationExempt;
  final bool isLowPowerModeActive;
  final bool recoveryReady;
  final String oemGuidanceTitle;
  final List<String> oemGuidanceSteps;
  final String recommendedBannerMessage;

  const WatchdogReport({
    required this.status,
    required this.hoursSinceLastActivity,
    required this.isStaleGap,
    required this.hasBackgroundPermission,
    required this.isBatteryOptimizationExempt,
    required this.isLowPowerModeActive,
    required this.recoveryReady,
    required this.oemGuidanceTitle,
    required this.oemGuidanceSteps,
    required this.recommendedBannerMessage,
  });
}

/// Axis C: Silent-Death Watchdog Service
/// Detects stale tracking gaps, permission/battery-saver regressions, and
/// generates OEM-specific survival steps for Samsung, Xiaomi, OPPO, and iOS.
class TrackingWatchdogService {
  TrackingWatchdogService._();

  static const int defaultStaleGapHours = 48;

  /// Evaluates background tracking health and recovery readiness.
  static WatchdogReport evaluateHealth({
    required DateTime now,
    DateTime? lastHeartbeatAt,
    List<Trip> recentTrips = const [],
    bool hasBackgroundPermission = true,
    bool isBatteryOptimizationExempt = true,
    bool isLowPowerModeActive = false,
    DevicePlatformKind platform = DevicePlatformKind.ios,
    int staleThresholdHours = defaultStaleGapHours,
  }) {
    DateTime? latestActivity = lastHeartbeatAt;
    for (final trip in recentTrips) {
      if (trip.isDeleted) continue;
      final candidate = trip.stoppedAt ?? trip.date;
      if (latestActivity == null || candidate.isAfter(latestActivity)) {
        latestActivity = candidate;
      }
    }

    final hoursSince = latestActivity != null
        ? now.difference(latestActivity).inMinutes / 60.0
        : null;
    final isStale = hoursSince != null && hoursSince >= staleThresholdHours;

    final (title, steps) = _oemGuidance(platform);

    WatchdogHealthStatus status = WatchdogHealthStatus.healthy;
    String banner =
        'Background tracking is healthy and ready for automatic trip capture.';

    if (!hasBackgroundPermission) {
      status = WatchdogHealthStatus.permissionDegraded;
      banner =
          'Location permission is not set to "Always Allow". Background trips will not auto-start.';
    } else if (!isBatteryOptimizationExempt || isLowPowerModeActive) {
      status = WatchdogHealthStatus.batterySaverRisk;
      banner = isLowPowerModeActive
          ? 'Low Power Mode is active — OS may throttle background GPS wakeups.'
          : 'Battery optimization is restricting KiloClaim. Exempt the app to prevent silent tracking death.';
    } else if (isStale) {
      status = WatchdogHealthStatus.staleGapDetected;
      banner =
          'No trips or telemetry recorded for ${hoursSince.round()}h. Use Back-Capture if any drives were missed.';
    }

    final recoveryReady =
        hasBackgroundPermission && isBatteryOptimizationExempt && !isLowPowerModeActive;

    return WatchdogReport(
      status: status,
      hoursSinceLastActivity:
          hoursSince != null ? double.parse(hoursSince.toStringAsFixed(1)) : null,
      isStaleGap: isStale,
      hasBackgroundPermission: hasBackgroundPermission,
      isBatteryOptimizationExempt: isBatteryOptimizationExempt,
      isLowPowerModeActive: isLowPowerModeActive,
      recoveryReady: recoveryReady,
      oemGuidanceTitle: title,
      oemGuidanceSteps: steps,
      recommendedBannerMessage: banner,
    );
  }

  static (String, List<String>) _oemGuidance(DevicePlatformKind platform) {
    switch (platform) {
      case DevicePlatformKind.androidSamsung:
        return (
          'Samsung OneUI Battery Survival',
          const [
            'Settings → Apps → KiloClaim → Battery → select "Unrestricted".',
            'Device Care → Battery → Background usage limits → add KiloClaim to "Never sleeping apps".',
            'Ensure Location permission is "Allow all the time".',
          ],
        );
      case DevicePlatformKind.androidXiaomi:
        return (
          'Xiaomi MIUI / HyperOS Survival',
          const [
            'Settings → Apps → Manage apps → KiloClaim → enable "Autostart".',
            'Battery saver → select "No restrictions".',
            'Lock KiloClaim in the Recent Apps tray so MIUI does not swipe-kill it.',
          ],
        );
      case DevicePlatformKind.androidOppo:
        return (
          'OPPO ColorOS / Realme Survival',
          const [
            'Settings → Battery → More battery settings → Optimize battery use → KiloClaim → "Don\'t optimize".',
            'Enable "Allow background activity" and "Allow auto-launch" in App Info.',
            'Disable App Quick Freeze for KiloClaim.',
          ],
        );
      case DevicePlatformKind.androidGeneric:
        return (
          'Android Background Location Checklist',
          const [
            'Set Location access to "Allow all the time".',
            'Set Battery usage to "Unrestricted" / "Don\'t optimize".',
            'Allow Nearby Devices (Bluetooth) for ute cabin auto-trigger.',
          ],
        );
      case DevicePlatformKind.ios:
        return (
          'iOS Background Survival Checklist',
          const [
            'Settings → KiloClaim → Location → select "Always" with Precise Location ON.',
            'Enable Motion & Fitness + Background App Refresh.',
            'Settings → App Store → disable "Offload Unused Apps" so iOS never removes KiloClaim.',
          ],
        );
      case DevicePlatformKind.other:
        return (
          'Background Tracking Checklist',
          const [
            'Grant persistent background location permission.',
            'Exempt KiloClaim from OS battery saving or sleep lists.',
          ],
        );
    }
  }
}
