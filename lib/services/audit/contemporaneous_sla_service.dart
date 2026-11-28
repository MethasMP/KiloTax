import 'package:flutter/foundation.dart';

import '../../data/models/logbook_period.dart';
import '../../data/models/trip.dart';

/// Urgency level for ATO CR 2026/71 para 14 7-day contemporaneous purpose rule.
enum SlaUrgency {
  /// Purpose confirmed within 7 days of capture.
  compliant,

  /// Unconfirmed, 4–6 days elapsed (due soon).
  dueSoon,

  /// Unconfirmed, on day 7 (final day before breach).
  atRisk,

  /// > 7 days elapsed without a descriptive business purpose.
  breached,
}

/// Per-trip contemporaneous SLA status under CR 2026/71 para 14.
@immutable
class TripSlaStatus {
  final String tripId;
  final DateTime capturedAt;
  final DateTime? purposeConfirmedAt;
  final int daysElapsed;
  final int daysRemaining;
  final SlaUrgency urgency;
  final String badgeText;

  const TripSlaStatus({
    required this.tripId,
    required this.capturedAt,
    required this.purposeConfirmedAt,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.urgency,
    required this.badgeText,
  });
}

/// Aggregate ATO Contemporaneous Integrity Score report for the logbook.
@immutable
class ContemporaneousScoreReport {
  final int totalEvaluatedTrips;
  final int confirmedWithin7DaysCount;
  final int pendingWithin7DaysCount;
  final int breachedCount;
  final double integrityScorePercent;
  final List<TripSlaStatus> tripStatuses;

  const ContemporaneousScoreReport({
    required this.totalEvaluatedTrips,
    required this.confirmedWithin7DaysCount,
    required this.pendingWithin7DaysCount,
    required this.breachedCount,
    required this.integrityScorePercent,
    required this.tripStatuses,
  });

  List<TripSlaStatus> get atRiskOrBreached => tripStatuses
      .where((s) =>
          s.urgency == SlaUrgency.atRisk || s.urgency == SlaUrgency.breached)
      .toList();
}

/// Evaluation of 12-week representative window stability and >15% pattern shift.
@immutable
class RepresentativeWindowReport {
  final String logbookPeriodId;
  final double? baselineBusinessPercent;
  final double? recent12WeekBusinessPercent;
  final double? patternShiftPercent;
  final bool hasPatternShiftAlert;
  final int maxInactiveGapDays;
  final bool hasInactivityGapAlert;
  final String advisoryMessage;

  const RepresentativeWindowReport({
    required this.logbookPeriodId,
    this.baselineBusinessPercent,
    this.recent12WeekBusinessPercent,
    this.patternShiftPercent,
    required this.hasPatternShiftAlert,
    required this.maxInactiveGapDays,
    required this.hasInactivityGapAlert,
    required this.advisoryMessage,
  });
}

/// Axis C: ATO CR 2026/71 para 14 7-Day Contemporaneous SLA Tracker &
/// 12-Week Representative Window Stability / Pattern-Shift Detector.
class ContemporaneousSlaService {
  ContemporaneousSlaService._();

  static const int maxContemporaneousDays = 7;
  static const double patternShiftThresholdPercent = 15.0;

  /// Evaluates all non-deleted business and unclassified trips against the
  /// 7-day contemporaneous purpose rule (CR 2026/71 para 14).
  static ContemporaneousScoreReport evaluateSla(
    List<Trip> trips, {
    DateTime? now,
  }) {
    final evalNow = now ?? DateTime.now();
    final targets = trips
        .where((t) =>
            !t.isDeleted && t.classification != TripClassification.personal)
        .toList();

    if (targets.isEmpty) {
      return const ContemporaneousScoreReport(
        totalEvaluatedTrips: 0,
        confirmedWithin7DaysCount: 0,
        pendingWithin7DaysCount: 0,
        breachedCount: 0,
        integrityScorePercent: 100.0,
        tripStatuses: [],
      );
    }

    final statuses = <TripSlaStatus>[];
    int confirmedInTime = 0;
    int pendingInTime = 0;
    int breached = 0;

    for (final trip in targets) {
      final capturedAt = _parseDate(trip.review['capturedAt']) ?? trip.date;
      final hasDescriptivePurpose = _hasDescriptivePurpose(trip);
      final confirmedAt = _parseDate(trip.review['purposeConfirmedAt']) ??
          (hasDescriptivePurpose &&
                  trip.classification == TripClassification.business
              ? trip.date
              : null);

      if (confirmedAt != null && hasDescriptivePurpose) {
        final daysToConfirm = confirmedAt.difference(capturedAt).inDays.clamp(0, 9999);
        if (daysToConfirm <= maxContemporaneousDays) {
          confirmedInTime++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: confirmedAt,
              daysElapsed: daysToConfirm,
              daysRemaining: maxContemporaneousDays - daysToConfirm,
              urgency: SlaUrgency.compliant,
              badgeText: 'Confirmed in ${daysToConfirm}d (CR 2026/71)',
            ),
          );
        } else {
          breached++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: confirmedAt,
              daysElapsed: daysToConfirm,
              daysRemaining: 0,
              urgency: SlaUrgency.breached,
              badgeText: 'Confirmed after ${daysToConfirm}d (>7d SLA)',
            ),
          );
        }
      } else {
        final elapsed = evalNow.difference(capturedAt).inDays.clamp(0, 9999);
        final remaining = (maxContemporaneousDays - elapsed).clamp(0, 7);

        if (elapsed > maxContemporaneousDays) {
          breached++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: null,
              daysElapsed: elapsed,
              daysRemaining: 0,
              urgency: SlaUrgency.breached,
              badgeText: 'Overdue (${elapsed}d) — >7d CR 2026/71 risk',
            ),
          );
        } else if (elapsed == maxContemporaneousDays) {
          pendingInTime++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: null,
              daysElapsed: elapsed,
              daysRemaining: 0,
              urgency: SlaUrgency.atRisk,
              badgeText: 'Confirm today (Day 7 SLA)',
            ),
          );
        } else if (elapsed >= 4) {
          pendingInTime++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: null,
              daysElapsed: elapsed,
              daysRemaining: remaining,
              urgency: SlaUrgency.dueSoon,
              badgeText: 'Confirm within $remaining days for ATO compliance',
            ),
          );
        } else {
          pendingInTime++;
          statuses.add(
            TripSlaStatus(
              tripId: trip.id,
              capturedAt: capturedAt,
              purposeConfirmedAt: null,
              daysElapsed: elapsed,
              daysRemaining: remaining,
              urgency: SlaUrgency.compliant,
              badgeText: '$remaining days left to confirm',
            ),
          );
        }
      }
    }

    final score = double.parse(
      ((confirmedInTime / targets.length) * 100.0).toStringAsFixed(1),
    );

    return ContemporaneousScoreReport(
      totalEvaluatedTrips: targets.length,
      confirmedWithin7DaysCount: confirmedInTime,
      pendingWithin7DaysCount: pendingInTime,
      breachedCount: breached,
      integrityScorePercent: score,
      tripStatuses: List.unmodifiable(statuses),
    );
  }

  /// Evaluates 12-week representative window stability and detects >15%
  /// business-use pattern shifts against the active [LogbookPeriod].
  static RepresentativeWindowReport evaluateRepresentativeWindow({
    required LogbookPeriod period,
    required List<Trip> allTrips,
    DateTime? now,
  }) {
    final evalNow = now ?? DateTime.now();
    final vehicleTrips = allTrips
        .where((t) => t.vehicleId == period.vehicleId && !t.isDeleted)
        .toList();

    final gapEval = period.evaluateSubstantiationPattern(
      vehicleTrips.map((t) => t.date).toList(),
      asOfDate: evalNow,
    );

    // Baseline business %: either certified percentage or computed from period trips.
    double? baselinePct = period.certifiedBusinessPercentage;
    if (baselinePct == null) {
      final periodTrips = vehicleTrips
          .where((t) =>
              !t.date.isBefore(period.startDate) &&
              !t.date.isAfter(period.endDate))
          .toList();
      final totalPeriodKm =
          periodTrips.fold<double>(0.0, (s, t) => s + t.distanceKm);
      final bizPeriodKm =
          periodTrips.fold<double>(0.0, (s, t) => s + t.businessDistanceKm);
      if (totalPeriodKm > 0) {
        baselinePct = (bizPeriodKm / totalPeriodKm) * 100.0;
      }
    }

    // Recent rolling 12-week (84-day) window.
    final windowStart = evalNow.subtract(const Duration(days: 84));
    final recentTrips = vehicleTrips
        .where((t) => !t.date.isBefore(windowStart) && !t.date.isAfter(evalNow))
        .toList();
    final totalRecentKm =
        recentTrips.fold<double>(0.0, (s, t) => s + t.distanceKm);
    final bizRecentKm =
        recentTrips.fold<double>(0.0, (s, t) => s + t.businessDistanceKm);

    final double? recentPct =
        totalRecentKm > 0 ? (bizRecentKm / totalRecentKm) * 100.0 : null;

    double? shiftPct;
    bool hasShiftAlert = false;
    if (baselinePct != null && recentPct != null) {
      shiftPct =
          double.parse((recentPct - baselinePct).abs().toStringAsFixed(1));
      hasShiftAlert = shiftPct > patternShiftThresholdPercent;
    }

    String msg;
    if (hasShiftAlert && gapEval.hasWarning) {
      msg =
          'Pattern shift (${shiftPct!.toStringAsFixed(1)}% > 15%) and ${gapEval.maxConsecutiveInactiveDays}d gap detected — consider starting a fresh 12-week logbook.';
    } else if (hasShiftAlert) {
      msg =
          'Business travel pattern shifted by ${shiftPct!.toStringAsFixed(1)}% (>15% threshold) vs logbook baseline. A new 12-week logbook may be required.';
    } else if (gapEval.hasWarning) {
      msg = gapEval.warningMessage!;
    } else {
      msg =
          '12-week logbook pattern is stable and representative (no >15% shift or >14d gap).';
    }

    return RepresentativeWindowReport(
      logbookPeriodId: period.id,
      baselineBusinessPercent: baselinePct != null
          ? double.parse(baselinePct.toStringAsFixed(1))
          : null,
      recent12WeekBusinessPercent: recentPct != null
          ? double.parse(recentPct.toStringAsFixed(1))
          : null,
      patternShiftPercent: shiftPct,
      hasPatternShiftAlert: hasShiftAlert,
      maxInactiveGapDays: gapEval.maxConsecutiveInactiveDays,
      hasInactivityGapAlert: gapEval.hasWarning,
      advisoryMessage: msg,
    );
  }

  static bool _hasDescriptivePurpose(Trip trip) {
    final p = trip.purpose.trim().toLowerCase();
    return p.isNotEmpty && p != 'unclassified' && p != 'unknown';
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
