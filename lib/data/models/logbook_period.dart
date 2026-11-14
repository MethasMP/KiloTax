/// Represents the statutory status of a continuous 12-week (84-day) logbook period
/// under Australian Tax Law (ITAA 1997 s 28-G).
enum LogbookStatus {
  notStarted,
  inProgress,
  completedPendingReview,
  certifiedValid,
  invalidated,
  expired5Years;

  String get displayName {
    switch (this) {
      case LogbookStatus.notStarted:
        return 'Not Started';
      case LogbookStatus.inProgress:
        return 'In Progress (12 Weeks)';
      case LogbookStatus.completedPendingReview:
        return 'Pending Review';
      case LogbookStatus.certifiedValid:
        return 'Certified Valid (5-Year Window)';
      case LogbookStatus.invalidated:
        return 'Invalidated';
      case LogbookStatus.expired5Years:
        return 'Expired (5-Year Limit)';
    }
  }
}

/// Statutory representative pattern risk assessment under ITAA 1997 s 28-G.
enum LogbookPatternRisk {
  /// Regular, representative pattern maintained with no unlogged gaps exceeding 14 days.
  representative,

  /// Inactive or unlogged gap > 14 consecutive days during the active 84-day period.
  /// Puts ATO substantiation at risk of being challenged as unrepresentative.
  substantiationGapWarning;

  String get displayName {
    switch (this) {
      case LogbookPatternRisk.representative:
        return 'Representative Travel Pattern';
      case LogbookPatternRisk.substantiationGapWarning:
        return 'Substantiation Gap Warning (> 14 Days Inactive)';
    }
  }
}

/// Detailed evaluation of travel continuity and unlogged gaps during the 12-week logbook period.
class LogbookGapEvaluation {
  final bool hasWarning;
  final int maxConsecutiveInactiveDays;
  final LogbookPatternRisk risk;
  final String? warningMessage;

  const LogbookGapEvaluation({
    required this.hasWarning,
    required this.maxConsecutiveInactiveDays,
    required this.risk,
    this.warningMessage,
  });
}

/// A continuous statutory logbook period established under ITAA 1997 rules.
/// Must be maintained for a continuous minimum period of 12 weeks (84 days)
/// to establish an audit-proof business use percentage.
class LogbookPeriod {
  final String id;
  final String vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final double startOdometer;
  final double? endOdometer;
  final LogbookStatus status;
  final double? certifiedBusinessPercentage;
  final String establishedFinancialYear;
  final String validUntilFinancialYear;
  final String? digitalSignatureHash;
  final DateTime? certifiedAt;

  const LogbookPeriod({
    required this.id,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.startOdometer,
    this.endOdometer,
    this.status = LogbookStatus.notStarted,
    this.certifiedBusinessPercentage,
    required this.establishedFinancialYear,
    required this.validUntilFinancialYear,
    this.digitalSignatureHash,
    this.certifiedAt,
  });

  /// True when the statutory requirement of at least 84 consecutive days (12 weeks) is satisfied.
  bool get isStatutoryDurationMet => endDate.difference(startDate).inDays >= 84;

  /// Evaluates whether there is an inactive/unlogged gap > 14 consecutive days during
  /// the active 84-day period under Australian Tax Law (ITAA 1997 s 28-G).
  bool hasSubstantiationGapWarning(List<DateTime> tripDates,
      {DateTime? asOfDate}) {
    return evaluateSubstantiationPattern(tripDates, asOfDate: asOfDate)
        .hasWarning;
  }

  /// Calculates the maximum consecutive inactive days between logged trips or period boundaries.
  int maxConsecutiveInactiveDays(List<DateTime> tripDates,
      {DateTime? asOfDate}) {
    return evaluateSubstantiationPattern(tripDates, asOfDate: asOfDate)
        .maxConsecutiveInactiveDays;
  }

  /// Evaluates whether travel during the 12-week period satisfies the statutory "representative pattern"
  /// test, flagging an audit risk if an inactive/unlogged gap > 14 consecutive days is detected.
  LogbookGapEvaluation evaluateSubstantiationPattern(
    List<DateTime> tripDates, {
    DateTime? asOfDate,
  }) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final statutoryEnd = startDay.add(const Duration(days: 84));
    final scheduledEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final effectiveEnd =
        scheduledEnd.isAfter(statutoryEnd) ? scheduledEnd : statutoryEnd;

    // Determine the active evaluation boundary
    final evalLimit = asOfDate != null
        ? DateTime(asOfDate.year, asOfDate.month, asOfDate.day)
        : (DateTime.now().isAfter(startDay) &&
                DateTime.now().isBefore(effectiveEnd)
            ? DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day)
            : effectiveEnd);

    final evalEnd = evalLimit.isBefore(effectiveEnd) ? evalLimit : effectiveEnd;

    // Filter and normalize trip dates within [startDay, evalEnd]
    final validDates = tripDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .where((d) => !d.isBefore(startDay) && !d.isAfter(evalEnd))
        .toSet()
        .toList()
      ..sort();

    int maxGap = 0;

    if (validDates.isEmpty) {
      maxGap = evalEnd.difference(startDay).inDays;
    } else {
      // Gap 1: from start of period to first trip
      final firstTripGap = validDates.first.difference(startDay).inDays;
      if (firstTripGap > maxGap) {
        maxGap = firstTripGap;
      }

      // Gap 2: between consecutive trips
      for (int i = 0; i < validDates.length - 1; i++) {
        final gap = validDates[i + 1].difference(validDates[i]).inDays;
        if (gap > maxGap) {
          maxGap = gap;
        }
      }

      // Gap 3: from last trip to the evaluation boundary
      final tailGap = evalEnd.difference(validDates.last).inDays;
      if (tailGap > maxGap) {
        maxGap = tailGap;
      }
    }

    final hasWarning = maxGap > 14;
    final risk = hasWarning
        ? LogbookPatternRisk.substantiationGapWarning
        : LogbookPatternRisk.representative;

    final warningMessage = hasWarning
        ? 'Substantiation Risk: Detected an unlogged gap of $maxGap consecutive days (> 14 days threshold). '
            'The ATO may deem this 12-week logbook unrepresentative of typical business travel under ITAA 1997 s 28-G.'
        : null;

    return LogbookGapEvaluation(
      hasWarning: hasWarning,
      maxConsecutiveInactiveDays: maxGap,
      risk: risk,
      warningMessage: warningMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'startOdometer': startOdometer,
      'endOdometer': endOdometer,
      'status': status.name,
      'certifiedBusinessPercentage': certifiedBusinessPercentage,
      'establishedFinancialYear': establishedFinancialYear,
      'validUntilFinancialYear': validUntilFinancialYear,
      'digitalSignatureHash': digitalSignatureHash,
      'certifiedAt': certifiedAt?.toIso8601String(),
    };
  }

  factory LogbookPeriod.fromJson(Map<String, dynamic> json) {
    return LogbookPeriod(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      startOdometer: (json['startOdometer'] as num).toDouble(),
      endOdometer: (json['endOdometer'] as num?)?.toDouble(),
      status: LogbookStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LogbookStatus.notStarted,
      ),
      certifiedBusinessPercentage:
          (json['certifiedBusinessPercentage'] as num?)?.toDouble(),
      establishedFinancialYear: json['establishedFinancialYear'] as String,
      validUntilFinancialYear: json['validUntilFinancialYear'] as String,
      digitalSignatureHash: json['digitalSignatureHash'] as String?,
      certifiedAt: json['certifiedAt'] != null
          ? DateTime.parse(json['certifiedAt'] as String)
          : null,
    );
  }

  LogbookPeriod copyWith({
    String? id,
    String? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
    double? startOdometer,
    double? endOdometer,
    LogbookStatus? status,
    double? certifiedBusinessPercentage,
    String? establishedFinancialYear,
    String? validUntilFinancialYear,
    String? digitalSignatureHash,
    DateTime? certifiedAt,
  }) {
    return LogbookPeriod(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      status: status ?? this.status,
      certifiedBusinessPercentage:
          certifiedBusinessPercentage ?? this.certifiedBusinessPercentage,
      establishedFinancialYear:
          establishedFinancialYear ?? this.establishedFinancialYear,
      validUntilFinancialYear:
          validUntilFinancialYear ?? this.validUntilFinancialYear,
      digitalSignatureHash: digitalSignatureHash ?? this.digitalSignatureHash,
      certifiedAt: certifiedAt ?? this.certifiedAt,
    );
  }
}
