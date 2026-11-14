import '../../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_space.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../state/app_state.dart';

/// Statutory Compliance Stages across the 12-week statutory logbook period (ITAA 1997 s.28-125).
enum UteEvolutionStage {
  stockChassis(
    stageNumber: 1,
    minWeek: 1,
    maxWeek: 2,
    title: 'Telemetry Baseline',
    subtitle: 'Laying the initial 14-day statutory travel foundation.',
    badge: 'Weeks 1–2',
    icon: LucideIcons.fileCheck,
  ),
  steelBullbarAlloyTray(
    stageNumber: 2,
    minWeek: 3,
    maxWeek: 4,
    title: 'Representative Pattern Established',
    subtitle:
        'Keep recording a representative period of business and personal driving.',
    badge: 'Base Locked',
    wallBreakerAlert: 'Week 3 milestone: Representative pattern established',
    icon: LucideIcons.shieldCheck,
  ),
  heavyDutyCanopyBatteries(
    stageNumber: 3,
    minWeek: 5,
    maxWeek: 8,
    title: 'Mid-Period Audit Continuity',
    subtitle:
        'Substantiated travel pattern maintained across regular business operations.',
    badge: 'Weeks 5–8',
    icon: LucideIcons.calendarCheck,
  ),
  fullTouringRig(
    stageNumber: 4,
    minWeek: 9,
    maxWeek: 11,
    title: 'Statutory Sample Maturing',
    subtitle: 'Review the recorded business share as you complete the period.',
    badge: 'Weeks 9–11',
    icon: LucideIcons.trendingUp,
  ),
  goldTaxFortress(
    stageNumber: 5,
    minWeek: 12,
    maxWeek: 12,
    title: 'Logbook period complete',
    subtitle: 'Review your recorded period and evidence with your accountant.',
    badge: 'Period complete',
    icon: LucideIcons.award,
  );

  final int stageNumber;
  final int minWeek;
  final int maxWeek;
  final String title;
  final String subtitle;
  final String badge;
  final String? wallBreakerAlert;
  final IconData icon;

  const UteEvolutionStage({
    required this.stageNumber,
    required this.minWeek,
    required this.maxWeek,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.wallBreakerAlert,
    required this.icon,
  });

  static UteEvolutionStage fromWeek(int week) {
    if (week >= 12) return UteEvolutionStage.goldTaxFortress;
    if (week >= 9) return UteEvolutionStage.fullTouringRig;
    if (week >= 5) return UteEvolutionStage.heavyDutyCanopyBatteries;
    if (week >= 3) return UteEvolutionStage.steelBullbarAlloyTray;
    return UteEvolutionStage.stockChassis;
  }
}

/// The 3 Statutory Continuity Protections under ATO TR 97/11.
enum GraceShieldType {
  rainedOut(
    title: 'Rained Out',
    category: 'Weather Stoppage',
    description:
        'Records that your vehicle was not driven today due to wet site shutdown, maintaining your representative travel continuity.',
    legalNote:
        'Under ATO TR 97/11, seasonal rain or site closures do not break representative travel patterns.',
    icon: LucideIcons.cloudRain,
  ),
  sickDay(
    title: 'Sick Day',
    category: 'Medical / Health',
    description:
        'Records unavoidable physical downtime or injury recovery today without breaking travel pattern continuity.',
    legalNote:
        'Statutory sick days and unavoidable physical downtime are recognized without penalizing logbook continuity.',
    icon: LucideIcons.heartPulse,
  ),
  toolRecovery(
    title: 'Tool Recovery',
    category: 'Workshop / Maintenance',
    description:
        'Records vehicle or equipment maintenance today, keeping your 12-week compliance status intact.',
    legalNote:
        'Time off-tools for mandatory equipment or vehicle repairs maintains your 12-week compliance status.',
    icon: LucideIcons.wrench,
  );

  final String title;
  final String category;
  final String description;
  final String legalNote;
  final IconData icon;

  const GraceShieldType({
    required this.title,
    required this.category,
    required this.description,
    required this.legalNote,
    required this.icon,
  });
}

/// Consolidated, Clean, Crisp-White Hero Card for Australian Logbook (TR 97/11).
///
/// Eliminates the claustrophobic double-black HUDs, strips away nested card-in-card slop,
/// and presents the essential metrics tradies need at a glance with Swiss precision:
/// - Current week & statutory 84-day progress
/// - Business Use percentage & protected tax deduction
/// - Odometer audit integrity baseline
/// - On-demand Grace Shields sheet
class TaxExemptionStreakHero extends StatelessWidget {
  final AppState? appState;
  final int? currentDay;
  final int? currentWeek;
  final double? atRiskAmount;
  final Set<String>? usedGraceShields;
  final ValueChanged<GraceShieldType>? onShieldTap;

  const TaxExemptionStreakHero({
    super.key,
    this.appState,
    this.currentDay,
    this.currentWeek,
    this.atRiskAmount,
    this.usedGraceShields,
    this.onShieldTap,
  });

  int get _week {
    if (currentWeek != null) return currentWeek!.clamp(1, 12);
    if (appState != null) return appState!.currentLogbookWeek;
    return 1;
  }

  double get _totalKm {
    if (appState != null) {
      return appState!.taxSummary.totalKm;
    }
    return 0.0;
  }

  double get _currentOdometer {
    if (appState != null) {
      final odo = appState!.currentOdometer;
      if (odo > 0.0) return odo;
      final start = appState!.startingOdometer;
      if (start > 0.0) return start;
    }
    return 0.0;
  }

  double get _businessPercent {
    if (appState != null) {
      return appState!.taxSummary.businessPercentage;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final start = appState?.primaryVehicle?.logbookStartDate;
    final hasPeriod = start != null || currentWeek != null;
    final day = (currentDay ?? appState?.currentLogbookDay ?? 1).clamp(1, 84);
    final missing = appState?.missingComplianceTrips.length ?? 0;
    final vehicle = appState?.primaryVehicle;
    return Container(
      padding: const EdgeInsets.all(S.xxl),
      decoration:
          BoxDecoration(color: AppColor.surfaceNavy, borderRadius: R.sheetR),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: S.sm,
            runSpacing: S.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColor.navyRaised, borderRadius: R.chipR),
                  child: const Icon(AppIcons.logbook,
                      size: AppIconSize.inline, color: AppColor.brandBright)),
              Text('12-WEEK LOGBOOK',
                  style: AppType.eyebrow.copyWith(color: AppColor.onNavyMuted)),
              if (vehicle != null)
                Text(vehicle.regoPlate,
                    style: AppType.secondary
                        .copyWith(color: AppColor.onNavyMuted)),
            ]),
        const SizedBox(height: S.xxl),
        Text(hasPeriod ? 'Week $_week of 12' : 'Your logbook starts here',
            style: AppType.title.copyWith(color: AppColor.onNavy)),
        const SizedBox(height: S.sm),
        Text(
            start == null
                ? 'Build a clear record of your driving.'
                : '${Formatters.date(start)} – ${Formatters.date(start.add(const Duration(days: 84)))}',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        const SizedBox(height: S.xl),
        Semantics(
            label: hasPeriod ? 'Day $day of 84' : 'Logbook not started',
            child: ClipRRect(
                borderRadius: R.chipR,
                child: LinearProgressIndicator(
                    value: hasPeriod ? day / 84 : 0,
                    minHeight: 6,
                    color: AppColor.brandBright,
                    backgroundColor: AppColor.navyLine))),
        const SizedBox(height: S.sm),
        Text(
            hasPeriod
                ? 'Day $day of 84 · ${84 - day} days remaining'
                : '12 weeks · one driving record',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: S.xl),
            child: Divider(height: 1, color: AppColor.navyLine)),
        LayoutBuilder(builder: (context, constraints) {
          final metrics = [
            _metric(
                'Vehicle Odometer',
                _currentOdometer > 0
                    ? '${Formatters.odometer(_currentOdometer)} km'
                    : 'Not recorded'),
            _metric(
                hasPeriod
                    ? 'Recorded business use'
                    : 'Recorded trips · business share',
                (appState?.pendingOdometerGaps.isNotEmpty ?? false)
                    ? 'Needs review'
                    : _totalKm > 0
                        ? '${_businessPercent.toStringAsFixed(1)}%'
                        : '—'),
          ];
          if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
              constraints.maxWidth < 280) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  metrics[0],
                  const SizedBox(height: S.lg),
                  metrics[1]
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: metrics[0]),
            const SizedBox(width: S.lg),
            Expanded(child: metrics[1])
          ]);
        }),
        const SizedBox(height: S.xl),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(missing > 0 ? AppIcons.attention : AppIcons.info,
              size: AppIconSize.inline, color: AppColor.onNavyMuted),
          const SizedBox(width: S.sm),
          Expanded(
              child: Text(
                  missing > 0
                      ? '$missing ${missing == 1 ? 'trip needs' : 'trips need'} review'
                      : hasPeriod
                          ? 'Keep reviewing trips as you go.'
                          : 'Add your starting odometer to begin.',
                  style:
                      AppType.secondary.copyWith(color: AppColor.onNavyMuted))),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: S.xs),
          Text(value,
              style: AppType.metricSmall.copyWith(color: AppColor.onNavy)),
        ],
      );
}
