import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../models/home_record_summary.dart';

const homeHeroColor = Color(0xFF192C36);

class HomeRecordHero extends StatelessWidget {
  final HomeRecordSummary summary;
  final VoidCallback onViewBasis;
  final VoidCallback onLogbook;

  const HomeRecordHero(
      {super.key,
      required this.summary,
      required this.onViewBasis,
      required this.onLogbook});

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
            style: (amount == null ? AppType.titleSmall : AppType.metric)
                .copyWith(color: AppColor.onNavy)),
        const SizedBox(height: 8),
        Text(
            summary.isLogbook && !summary.hasLogbookStart
                ? 'Provisional · set up your logbook'
                : summary.isLogbook && summary.elapsedDays < cap
                    ? 'Provisional · logbook in progress'
                    : 'Provisional · checked details only',
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final metrics = [
            _metric(Formatters.distance(summary.reviewed.businessKm),
                'Reviewed work travel · FY'),
            _metric(
                summary.isCpk
                    ? '${summary.reviewedTripCount}'
                    : Formatters.percentage(
                        summary.reviewed.businessPercentage),
                summary.isCpk
                    ? 'Reviewed trips · FY'
                    : 'Reviewed work-use share'),
          ];
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [metrics[0], const SizedBox(height: 16), metrics[1]]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: metrics[0]),
            const SizedBox(width: 16),
            Expanded(child: metrics[1]),
          ]);
        }),
        if (summary.isCpk) ...[
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF3D4D56), height: 1),
          const SizedBox(height: 16),
          Text(
              '${Formatters.odometer(summary.reviewed.businessKm.clamp(0, summary.taxRule.centsPerKmMaxKm))} / ${Formatters.odometer(summary.taxRule.centsPerKmMaxKm)} km annual limit',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
        ],
        if (summary.isLogbook) ...[
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF3D4D56), height: 1),
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
                    color: const Color(0xFFF1A36D),
                    backgroundColor: const Color(0xFF3D4D56))),
        ],
      ]),
    );
  }

  Widget _metric(String value, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: AppType.metricSmall.copyWith(color: AppColor.onNavy)),
        const SizedBox(height: 6),
        Text(label,
            style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
      ]);
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
          const SizedBox(height: 24),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Every trip.\nEvery purpose.\nOne clear record.'
                  : 'Every trip.\nEvery receipt.\nOne clear record.',
              style: AppType.title.copyWith(color: AppColor.onNavy)),
          const SizedBox(height: 12),
          Text(
              taxMethod == TaxMethod.centsPerKm
                  ? 'Keep dates, distances and work purposes together.\nReview the details before sharing.'
                  : 'Start with a trip. Scan receipts as you go.\nReview the details before sharing.',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          const SizedBox(height: 20),
          const ExcludeSemantics(
              child: SizedBox(
                  height: 100,
                  child: CustomPaint(painter: _RecordJourneyPainter()))),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFF3D4D56)),
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

class _RecordJourneyPainter extends CustomPainter {
  const _RecordJourneyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 2;
    final route = Path()
      ..moveTo(size.width * .08, 76)
      ..lineTo(size.width * .3, 76)
      ..lineTo(size.width * .38, 23)
      ..lineTo(size.width * .62, 23)
      ..lineTo(size.width * .72, 76)
      ..lineTo(size.width * .88, 76);
    for (final metric in route.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(metric.extractPath(offset, offset + 4),
            line..style = PaintingStyle.stroke);
      }
    }
    canvas.drawCircle(Offset(size.width * .08, 76), 10,
        Paint()..color = const Color(0xFFF1A36D));
    canvas.drawCircle(
        Offset(size.width * .08, 76), 4, Paint()..color = homeHeroColor);
    final receipt = Rect.fromLTWH(size.width * .43, 8, 48, 70);
    canvas.drawRRect(RRect.fromRectAndRadius(receipt, const Radius.circular(3)),
        Paint()..color = const Color(0xFFD8E1E4));
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
          Offset(receipt.left + 10, 25 + i * 11),
          Offset(receipt.right - (i == 3 ? 24 : 10), 25 + i * 11),
          Paint()
            ..color = i == 3 ? const Color(0xFFC2410C) : const Color(0xFF78909C)
            ..strokeWidth = 3);
    }
    final check = Rect.fromCenter(
        center: Offset(size.width * .88, 76), width: 48, height: 40);
    canvas.drawRRect(RRect.fromRectAndRadius(check, const Radius.circular(8)),
        Paint()..color = const Color(0xFF78909C));
    canvas.drawPath(
        Path()
          ..moveTo(check.left + 12, check.top + 21)
          ..lineTo(check.left + 21, check.top + 29)
          ..lineTo(check.left + 36, check.top + 13),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RecordJourneyPainter oldDelegate) => false;
}
