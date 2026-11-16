import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../models/home_record_summary.dart';

const homeHeroColor = AppColor.surfaceNavy;

class HomeRecordHero extends StatelessWidget {
  final HomeRecordSummary summary;
  final VoidCallback onViewBasis;
  final VoidCallback onLogbook;
  final VoidCallback? onViewSummary;

  const HomeRecordHero(
      {super.key,
      required this.summary,
      required this.onViewBasis,
      required this.onLogbook,
      this.onViewSummary});

  @override
  Widget build(BuildContext context) {
    final amount = summary.deduction;
    final cap = AppConstants.statutoryLogbookDays;
    return Container(
      key: const ValueKey('home-record-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: homeHeroColor, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('FY ${summary.report.financialYear}',
                  style: AppType.eyebrow.copyWith(color: AppColor.onNavyMuted)),
              TextButton(
                  onPressed: onViewBasis,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.onNavy,
                      minimumSize: const Size(48, 48)),
                  child: const Text('View basis ↗')),
            ]),
        const SizedBox(height: 8),
        Text('Estimated deduction',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        const SizedBox(height: 6),
        Text(
            amount == null
                ? 'More records needed'
                : Formatters.currency(amount),
            style: (amount == null ? AppType.titleSmall : AppType.metricSmall)
                .copyWith(color: AppColor.onNavy)),
        const SizedBox(height: 8),
        Text(
            summary.isLogbook && !summary.hasLogbookStart
                ? 'Provisional · set up your logbook'
                : summary.isLogbook && summary.elapsedDays < cap
                    ? 'Provisional · logbook in progress'
                    : 'Provisional · checked details only',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        const SizedBox(height: 12),
        Text(
            '${Formatters.distance(summary.reviewed.businessKm)} reviewed work travel · FY',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        if (onViewSummary != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onViewSummary,
              style: TextButton.styleFrom(
                foregroundColor: AppColor.onNavy,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Text('View tax summary →'),
            ),
          ),
        if (summary.isCpk) ...[
          const SizedBox(height: 20),
          const Divider(color: AppColor.navyLine, height: 1),
          const SizedBox(height: 16),
          Text(
              '${Formatters.odometer(summary.reviewed.businessKm.clamp(0, summary.taxRule.centsPerKmMaxKm))} / ${Formatters.odometer(summary.taxRule.centsPerKmMaxKm)} km annual limit',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        ],
        if (summary.isLogbook) ...[
          const SizedBox(height: 20),
          const Divider(color: AppColor.navyLine, height: 1),
          TextButton(
              onPressed: onLogbook,
              style: TextButton.styleFrom(
                  foregroundColor: AppColor.onNavy,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  alignment: Alignment.centerLeft),
              child: Text(summary.hasLogbookStart
                  ? 'Logbook · ${summary.elapsedDays} / $cap days elapsed ›'
                  : 'Set up your logbook ›')),
          if (summary.hasLogbookStart)
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: summary.elapsedDays / cap,
                    minHeight: 4,
                    color: AppColor.brandBright,
                    backgroundColor: AppColor.navyLine)),
        ],
      ]),
    );
  }
}

class HomeWelcomeHero extends StatelessWidget {
  final String vehicleName;
  final TaxMethod? taxMethod;
  const HomeWelcomeHero(
      {super.key, required this.vehicleName, required this.taxMethod});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: homeHeroColor, borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('YOUR DRIVING RECORDS',
              style: AppType.eyebrow.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 16),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Every trip.\nEvery purpose.\nOne clear record.'
                  : 'Every trip.\nEvery receipt.\nOne clear record.',
              style: AppType.titleSmall.copyWith(color: AppColor.onNavy)),
          const SizedBox(height: 12),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Keep dates, distances and work purposes together.\nReview the details before sharing.'
                  : 'Start with a trip. Scan receipts as you go.\nReview the details before sharing.',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColor.navyLine),
          const SizedBox(height: 16),
          Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(vehicleName,
                    style: AppType.secondary
                        .copyWith(color: AppColor.onNavyMuted)),
                Text(taxMethod?.title ?? 'Driving records',
                    style: AppType.secondary.copyWith(color: AppColor.onNavy)),
              ]),
        ]),
      );
}
