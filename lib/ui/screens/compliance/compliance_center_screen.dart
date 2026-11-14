import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../state/app_state.dart';
import '../dashboard/widgets/tax_readiness_card.dart';
import '../evidence/evidence_review_screen.dart';

/// A summary of recorded details. Final receipt-file checks happen in review.
class ComplianceCenterScreen extends StatelessWidget {
  final AppState appState;
  const ComplianceCenterScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (context, _) => _buildChecks(context),
      );

  Widget _buildChecks(BuildContext context) {
    final report = appState.evidenceReview;
    final vehicle = report.vehicle;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Record checks')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('FY ${report.financialYear}',
              style: AppTextStyles.secondaryMedium),
          const SizedBox(height: 12),
          TaxReadinessCard(appState: appState),
          const SizedBox(height: 24),
          const Text('Recorded details', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          _detail('Vehicle', vehicle?.displayName ?? 'Not configured'),
          _detail('Tax method', vehicle?.taxMethod.title ?? 'Not configured'),
          _detail('Trips recorded', '${report.trips.length}'),
          _detail('Expenses recorded', '${report.expenses.length}'),
          _detail('Items to review', '${report.items.length}'),
          const SizedBox(height: 20),
          const Text(
              'These checks help organise your records. Your accountant can review eligibility and any missing evidence.',
              style: AppTextStyles.secondaryMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: () =>
                  EvidenceReviewScreen.show(context, appState: appState),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review records and files')),
        ]),
      ),
    );
  }

  Widget _detail(String title, String value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.cardPrimary)
          ])));
}
