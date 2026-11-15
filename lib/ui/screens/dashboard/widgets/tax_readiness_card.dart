import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../state/app_state.dart';
import '../../../../services/engine/tax_pack_share_helper.dart';
import '../../evidence/evidence_review_screen.dart';

class TaxReadinessCard extends StatelessWidget {
  final AppState appState;
  final bool embedded;
  final bool showAction;

  const TaxReadinessCard(
      {super.key,
      required this.appState,
      this.embedded = false,
      this.showAction = true});

  @override
  Widget build(BuildContext context) {
    final report = appState.evidenceReview;
    if (report.vehicle == null) return const SizedBox.shrink();

    final missingTrips = appState.missingComplianceTrips;
    final missingExpenses = appState.unclassifiedExpenses;
    final count = report.items.length;
    final needsReview = count > 0;
    final String headline;
    if (!report.hasRecords) {
      headline = 'Your evidence starts here';
    } else if (!needsReview) {
      headline = 'Review before sharing';
    } else if (count == missingTrips.length + missingExpenses.length &&
        missingTrips.isEmpty &&
        missingExpenses.isNotEmpty) {
      headline =
          '${missingExpenses.length} ${missingExpenses.length == 1 ? "expense needs" : "expenses need"} review';
    } else {
      headline = '$count ${count == 1 ? "item needs" : "items need"} attention';
    }

    final detail = !report.hasRecords
        ? 'Add your trips and receipts. We’ll help you check the details.'
        : needsReview
            ? 'These details stay visible in your accountant pack for review.'
            : 'Your summary, spreadsheet and available receipts are prepared together.';

    return Container(
      padding: EdgeInsets.all(embedded ? 0 : 16),
      decoration: embedded
          ? null
          : BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColor.hairline),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                  needsReview
                      ? LucideIcons.clipboardList
                      : LucideIcons.folderCheck,
                  color: needsReview
                      ? AppColor.attentionStrong
                      : AppColor.inkMuted,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Evidence check',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: AppColor.inkMuted)),
                    const SizedBox(height: 6),
                    Text(headline,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColor.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(detail,
              style: const TextStyle(
                  fontSize: 14, height: 1.45, color: AppColor.inkMuted)),
          if (showAction) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColor.brand,
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () => needsReview || !report.hasRecords
                    ? EvidenceReviewScreen.show(context, appState: appState)
                    : TaxPackShareHelper.shareTaxPack(context, appState),
                child: Text(needsReview
                    ? 'Review missing details'
                    : report.hasRecords
                        ? 'Send to accountant'
                        : 'Open evidence checklist'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
