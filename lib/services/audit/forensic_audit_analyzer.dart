import '../../data/models/trip.dart';
import '../../data/models/vehicle_expense.dart';

enum AuditRiskStatus {
  auditProof,
  caution,
  incompletePeriod,
  highAuditRisk,
}

class OdometerGap {
  final Trip previousTrip;
  final Trip nextTrip;
  final double gapKm;

  OdometerGap({
    required this.previousTrip,
    required this.nextTrip,
    required this.gapKm,
  });
}

class ForensicAuditReport {
  final AuditRiskStatus auditStatus;
  final double auditRiskScore; // 0 (Perfect/Audit-Proof) to 100 (Extremely Risky)
  final List<OdometerGap> odometerGaps;
  final List<VehicleExpense> unlinkedExpenses;
  final List<VehicleExpense> missingReceiptExpenses;
  final double totalSubstantiatedExpenseDeduction;
  final double atRiskExpenseAmount;
  final double estimatedMissedTaxDeductionDollars;
  final bool isAto12WeekPeriodComplete;
  final int completedConsecutiveWeeks;
  final List<String> recommendations;

  ForensicAuditReport({
    required this.auditStatus,
    required this.auditRiskScore,
    required this.odometerGaps,
    required this.unlinkedExpenses,
    required this.missingReceiptExpenses,
    required this.totalSubstantiatedExpenseDeduction,
    required this.atRiskExpenseAmount,
    required this.estimatedMissedTaxDeductionDollars,
    required this.isAto12WeekPeriodComplete,
    required this.completedConsecutiveWeeks,
    required this.recommendations,
  });
}

/// ForensicAuditAnalyzer:
/// The "102 Value Engine" that scans imported or existing vehicle logs against
/// strict ATO Subdivision 28-G ITAA 1997 audit requirements, quantifying gaps and lost dollars.
class ForensicAuditAnalyzer {
  static const double gapThresholdKm = 5.0;
  static const double defaultCentsPerKmRate = 0.88; // FY24-25/26 ATO CPK rate

  ForensicAuditReport analyze({
    required List<Trip> trips,
    required List<VehicleExpense> expenses,
  }) {
    final sortedTrips = List<Trip>.from(trips)..sort((a, b) => a.date.compareTo(b.date));
    final List<OdometerGap> gaps = [];
    final List<String> recs = [];

    // 1. Odometer Continuity Audit
    for (int i = 0; i < sortedTrips.length - 1; i++) {
      final current = sortedTrips[i];
      final next = sortedTrips[i + 1];

      if (next.startOdometer > current.endOdometer + gapThresholdKm) {
        final gap = next.startOdometer - current.endOdometer;
        gaps.add(OdometerGap(
          previousTrip: current,
          nextTrip: next,
          gapKm: gap,
        ));
        recs.add('Unevidenced odometer gap of ${gap.toStringAsFixed(1)} km detected between trips on ${current.date.toIso8601String().substring(0, 10)} and ${next.date.toIso8601String().substring(0, 10)}.');
      }
    }

    // 2. Expense Substantiation & Linking Audit
    final missingReceipts = expenses.where((e) => e.receiptPath == null || e.receiptPath!.isEmpty).toList();
    final unlinkedExpenses = expenses.where((e) {
      return !sortedTrips.any((t) => t.linkedExpenseIds.contains(e.id));
    }).toList();

    double substantiatedExpense = 0.0;
    double atRiskExpense = 0.0;

    for (final exp in expenses) {
      if (exp.receiptPath != null && exp.receiptPath!.isNotEmpty) {
        substantiatedExpense += exp.amount;
      } else {
        atRiskExpense += exp.amount;
      }
    }

    // 3. ATO 12-Week Logbook Duration Audit
    int completedWeeks = 0;
    bool is12WeeksComplete = false;
    if (sortedTrips.isNotEmpty) {
      final start = sortedTrips.first.date;
      final end = sortedTrips.last.date;
      final diffDays = end.difference(start).inDays;
      completedWeeks = (diffDays / 7).floor();
      is12WeeksComplete = completedWeeks >= 12;
    }

    // 4. Calculate Risk Score & Lost Arbitrage
    double riskScore = 0.0;
    if (gaps.isNotEmpty) {
      riskScore += (gaps.length * 15.0).clamp(0.0, 50.0);
    }
    if (missingReceipts.isNotEmpty) {
      riskScore += (missingReceipts.length * 10.0).clamp(0.0, 30.0);
    }
    if (!is12WeeksComplete) {
      riskScore += 20.0;
      recs.add('Current logbook covers only $completedWeeks weeks. ATO requires 12 continuous weeks for a 5-year logbook exemption.');
    }

    AuditRiskStatus status = AuditRiskStatus.auditProof;
    if (riskScore >= 50.0) {
      status = AuditRiskStatus.highAuditRisk;
    } else if (!is12WeeksComplete) {
      status = AuditRiskStatus.incompletePeriod;
    } else if (riskScore > 0.0) {
      status = AuditRiskStatus.caution;
    }

    final double missedDeductions = atRiskExpense + (gaps.fold(0.0, (acc, g) => acc + g.gapKm) * defaultCentsPerKmRate * 0.30);

    return ForensicAuditReport(
      auditStatus: status,
      auditRiskScore: riskScore.clamp(0.0, 100.0),
      odometerGaps: gaps,
      unlinkedExpenses: unlinkedExpenses,
      missingReceiptExpenses: missingReceipts,
      totalSubstantiatedExpenseDeduction: substantiatedExpense,
      atRiskExpenseAmount: atRiskExpense,
      estimatedMissedTaxDeductionDollars: missedDeductions,
      isAto12WeekPeriodComplete: is12WeeksComplete,
      completedConsecutiveWeeks: completedWeeks,
      recommendations: recs,
    );
  }
}
