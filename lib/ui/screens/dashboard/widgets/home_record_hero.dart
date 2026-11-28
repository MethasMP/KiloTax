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
          color: AppColor.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('FY ${summary.report.financialYear}',
                  style: AppType.eyebrow.copyWith(color: AppColor.inkSubtle)),
              TextButton(
                  onPressed: onViewBasis,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.ink,
                      minimumSize: const Size(48, 48)),
                  child: const Text('View basis ↗')),
            ]),
        const SizedBox(height: 8),
        Text('Estimated deduction',
            style: AppType.secondary.copyWith(color: AppColor.inkSubtle)),
        const SizedBox(height: 8),
        Text(
            amount == null
                ? 'More records needed'
                : Formatters.currency(amount),
            style: (amount == null ? AppType.titleSmall : AppType.metric)
                .copyWith(color: AppColor.ink)),
        const SizedBox(height: 8),
        Text(
            summary.isLogbook && !summary.hasLogbookStart
                ? 'Provisional · set up your logbook'
                : summary.isLogbook && summary.elapsedDays < cap
                    ? 'Provisional · logbook in progress'
                    : 'Provisional · checked details only',
            style: AppType.secondary.copyWith(color: AppColor.inkSubtle)),
        const SizedBox(height: 12),
        Text(
            '${Formatters.distance(summary.reviewed.businessKm)} reviewed work travel · FY',
            style: AppType.secondary.copyWith(color: AppColor.inkSubtle)),
        if (onViewSummary != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onViewSummary,
              style: TextButton.styleFrom(
                foregroundColor: AppColor.ink,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Text('View tax summary →'),
            ),
          ),
        if (summary.isCpk) ...[
          const SizedBox(height: 20),
          const Divider(color: AppColor.hairline, height: 1),
          const SizedBox(height: 16),
          Text(
              '${Formatters.odometer(summary.reviewed.businessKm.clamp(0, summary.taxRule.centsPerKmMaxKm))} / ${Formatters.odometer(summary.taxRule.centsPerKmMaxKm)} km annual limit',
              style: AppType.secondary.copyWith(color: AppColor.inkSubtle)),
        ],
        if (summary.isLogbook) ...[
          const SizedBox(height: 20),
          const Divider(color: AppColor.hairline, height: 1),
          TextButton(
              onPressed: onLogbook,
              style: TextButton.styleFrom(
                  foregroundColor: AppColor.ink,
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
                    backgroundColor: AppColor.hairline)),
        ],
      ]),
    );
  }
}

class HomeWelcomeHero extends StatelessWidget {
  final String vehicleName;
  final TaxMethod? taxMethod;
  final Widget? actions;
  const HomeWelcomeHero(
      {super.key,
      required this.vehicleName,
      required this.taxMethod,
      this.actions});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: homeHeroColor, borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('YOUR VEHICLE EVIDENCE',
              style: AppType.eyebrow.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 16),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Build your record.\nReview what is missing.'
                  : 'Keep your evidence\ntogether.',
              style: AppType.titleSmall.copyWith(color: AppColor.onNavy)),
          const SizedBox(height: 12),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Capture work travel, confirm its purpose, then prepare your accountant pack.'
                  : 'Capture travel and receipts, review missing details, then prepare your accountant pack.',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          if (actions != null) ...[
            const SizedBox(height: 24),
            actions!,
          ],
        ]),
      );
}
