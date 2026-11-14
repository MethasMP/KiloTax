import '../../../core/theme/app_typography.dart';
import '../../widgets/adaptive_row.dart';
import '../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tax_summary.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../compliance/compliance_center_screen.dart';
import '../trips/trip_detection_screen.dart';
import '../trips/trip_quick_resolve_sheet.dart';
import '../evidence/evidence_review_screen.dart';
import '../workflow/workflow_screen.dart';
import '../../../core/theme/app_color.dart';
import '../dashboard/widgets/tax_readiness_card.dart';
import '../home/widgets/trips_ledger_tab.dart';

/// Professional ATO Tax Summary Desk
/// Designed for compliant record-keeping and senior tax agent review:
/// 1. Single Source of Truth: Total claimable deduction prominently featured without duplicate zeroes.
/// 2. Contextual Arbitrage: Intelligent analysis that stays subtle and truthful when data is still emerging.
/// 3. Genuine Audit-Readiness: Real legal substantiation steps with zero false 100% inflation.
/// 4. 1-Tap Accountant Flywheel: Fast export and sharing designed for both Tradies & Tax Agents.
class TaxSummaryScreen extends StatelessWidget {
  const TaxSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final summary = appState.taxSummary;
    final vehicle = appState.primaryVehicle;
    final isCpk =
        (vehicle?.taxMethod ?? TaxMethod.centsPerKm) == TaxMethod.centsPerKm;
    final totalClaim = isCpk ? summary.centsPerKmClaim : summary.logbookClaim;
    final hasActivity = summary.totalKm > 0 || summary.totalRunningExpenses > 0;
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
          backgroundColor: AppColor.canvas,
          title: const Text('Tax Summary'),
          centerTitle: false),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton.icon(
                onPressed: () =>
                    EvidenceReviewScreen.show(context, appState: appState),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColor.ink,
                    foregroundColor: AppColor.onNavy,
                    minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.ios_share, size: 20),
                label: const Text('Review & share'),
              ))),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text('FY ${appState.activeTaxRule.financialYear}',
                style: AppType.secondary),
            const SizedBox(height: 16),
            _buildCompactTaxClaimStrip(
                appState: appState,
                totalClaim: totalClaim,
                isCpk: isCpk,
                primaryVehicle: vehicle),
            const SizedBox(height: 20),
            TaxReadinessCard(appState: appState),
            const SizedBox(height: 20),
            OutlinedButton.icon(
                onPressed: () => WorkflowScreen.show(context, appState),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Trip → Job → Receipt → Pack')),
            const SizedBox(height: 16),
            const Text('Before sharing', style: AppType.section),
            const SizedBox(height: 8),
            const Text(
                'Review your records and available receipt files. The sharing flow lets you check the pack before sending it.',
                style: AppType.body),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Record checklist', style: AppType.bodyStrong),
              subtitle: const Text(
                  'Vehicle, trip details and supporting records',
                  style: AppType.secondary),
              children: [
                _buildAuditReadinessCard(
                    context: context,
                    appState: appState,
                    score: appState.taxReadinessScore,
                    totalIssues: appState.evidenceReview.items.length,
                    missingTrips: appState.missingComplianceTrips,
                    unclassifiedExpenses: appState.unclassifiedExpenses,
                    isCpk: isCpk)
              ],
            ),
            if (hasActivity)
              _buildArbitrageAdvisorCard(
                  context: context,
                  appState: appState,
                  summary: summary,
                  isCpk: isCpk,
                  hasActivity: hasActivity,
                  logbookHasAdvantage:
                      summary.recommendedMethod == RecommendedMethod.logbook),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Detailed record checks',
                    style: AppType.bodyStrong),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        ComplianceCenterScreen(appState: appState)))),
          ]),
    );
  }

  Widget _buildCompactTaxClaimStrip({
    required AppState appState,
    required double totalClaim,
    required bool isCpk,
    required Vehicle? primaryVehicle,
  }) {
    final rateCents = (appState.activeTaxRule.centsPerKmRate * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border.all(color: AppColor.hairline),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Estimated deduction', style: AppType.bodyStrong),
        const SizedBox(height: 8),
        Text(Formatters.currency(totalClaim), style: AppType.title),
        const SizedBox(height: 8),
        Text(
            isCpk
                ? 'Cents per kilometre · $rateCents¢/km'
                : '${primaryVehicle?.taxMethod.title ?? 'Logbook'} · Recorded expenses',
            style: AppType.secondary),
        if (isCpk) ...[
          const SizedBox(height: 8),
          Text(
              '${Formatters.distance(appState.taxSummary.businessKm)} business recorded · Calculation limited to ${appState.activeTaxRule.centsPerKmMaxKm.toStringAsFixed(0)} km',
              style: AppType.secondary),
          if (appState.taxSummary.businessKm >=
              appState.activeTaxRule.centsPerKmMaxKm)
            Text('Kilometre limit reached for this estimate.',
                style:
                    AppType.secondary.copyWith(color: AppColor.attentionInk)),
        ],
        const SizedBox(height: 8),
        const Text(
            'Based on the records entered so far. This is a deduction estimate, not a tax refund.',
            style: AppType.secondary),
      ]),
    );
  }

  /// 2. Arbitrage Advisor Card: Intelligent, truthful, context-driven
  Widget _buildArbitrageAdvisorCard({
    required BuildContext context,
    required AppState appState,
    required TaxSummary summary,
    required bool isCpk,
    required bool hasActivity,
    required bool logbookHasAdvantage,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Compare method estimates', style: AppType.bodyStrong),
      subtitle: const Text('View amounts and evidence requirements',
          style: AppType.secondary),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cents / km estimate'),
            subtitle: Text(Formatters.currency(summary.centsPerKmClaim),
                style: AppType.cardNumeric)),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Logbook estimate'),
            subtitle: Text(Formatters.currency(summary.logbookClaim),
                style: AppType.cardNumeric)),
        const Text(
            'These estimates use the records available. A different method may require additional evidence. Review the method and records with your accountant before changing.',
            style: AppType.secondary),
      ],
    );
  }

  /// 3. Genuine Audit-Readiness Integrity Card
  Widget _buildAuditReadinessCard({
    required BuildContext context,
    required AppState appState,
    required int score,
    required int totalIssues,
    required List<dynamic> missingTrips,
    required List<dynamic> unclassifiedExpenses,
    required bool isCpk,
  }) {
    final scopedTrips = appState.evidenceReview.trips;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interactive ATO Audit Ledger (Kidlin's Law: Zero Ambiguity, 100% Actionable)
          _buildInteractiveAuditRow(
            context: context,
            icon:
                appState.hasVehicle ? AppIcons.confirmed : AppIcons.unselected,
            statusColor:
                appState.hasVehicle ? AppColors.emerald : AppColors.muted,
            title: 'Vehicle Profile',
            subtitle: appState.primaryVehicle?.displayName ?? 'Not configured',
            actionLabel: appState.hasVehicle ? 'View profile' : 'Set up',
            onTap: () {
              HapticFeedback.lightImpact();
              _showVehicleProfileSheet(context, appState);
            },
          ),
          const SizedBox(height: 10),

          _buildInteractiveAuditRow(
            context: context,
            icon: appState.primaryVehicle != null
                ? AppIcons.confirmed
                : AppIcons.unselected,
            statusColor: appState.primaryVehicle != null
                ? AppColors.emerald
                : AppColors.muted,
            title: 'ATO Tax Method',
            subtitle: isCpk
                ? 'Cents per km (${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}¢/km)'
                : 'Logbook Method (Actual Expenses)',
            actionLabel: 'Active',
            isActionEnabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 10),

          if (isCpk) ...[
            _buildInteractiveAuditRow(
              context: context,
              icon: scopedTrips.isNotEmpty
                  ? AppIcons.confirmed
                  : AppIcons.unselected,
              statusColor:
                  scopedTrips.isNotEmpty ? AppColors.emerald : AppColors.muted,
              title: 'Recorded trip history',
              subtitle: scopedTrips.isNotEmpty
                  ? '${scopedTrips.length} ${scopedTrips.length == 1 ? 'drive' : 'drives'} recorded'
                  : 'No trips recorded',
              actionLabel: scopedTrips.isNotEmpty ? 'View' : 'Log drive',
              onTap: () {
                HapticFeedback.lightImpact();
                if (scopedTrips.isEmpty) {
                  TripDetectionScreen.show(context, appState);
                } else {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TripsLedgerTab(appState: appState)));
                }
              },
            ),
            const SizedBox(height: 10),
            if (scopedTrips.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.unselected,
                statusColor: AppColors.muted,
                title: 'Business trip details',
                subtitle: 'Awaiting drive logs to substantiate',
                actionLabel: 'Awaiting Drives',
                isActionEnabled: false,
                onTap: () {},
              )
            else if (missingTrips.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.confirmed,
                statusColor: AppColors.emerald,
                title: 'Business trip details',
                subtitle:
                    '${scopedTrips.length} ${scopedTrips.length == 1 ? 'drive' : 'drives'} recorded',
                actionLabel: 'Details',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.warning,
                statusColor: AppColors.amberDark,
                title: '${missingTrips.length} Trips Need Work Purpose',
                subtitle: 'ATO requires clear business justification',
                actionLabel: 'Resolve Now →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  TripQuickResolveSheet.show(context,
                      trip: missingTrips.first, appState: appState);
                },
              ),
          ] else ...[
            _buildInteractiveAuditRow(
              context: context,
              icon: (appState.primaryVehicle?.initialOdometer ?? 0) > 0
                  ? AppIcons.confirmed
                  : AppIcons.unselected,
              statusColor: (appState.primaryVehicle?.initialOdometer ?? 0) > 0
                  ? AppColors.emerald
                  : AppColors.muted,
              title: 'Starting Odometer',
              subtitle: (appState.primaryVehicle?.initialOdometer ?? 0) > 0
                  ? '${appState.primaryVehicle!.initialOdometer.toStringAsFixed(0)} km recorded'
                  : 'Opening reading required by ATO',
              actionLabel: (appState.primaryVehicle?.initialOdometer ?? 0) > 0
                  ? 'Edit →'
                  : 'Record →',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ComplianceCenterScreen(appState: appState),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            if (missingTrips.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.confirmed,
                statusColor: AppColors.emerald,
                title: 'Logbook Trips Classified',
                subtitle: 'All trips split by business & personal',
                actionLabel: 'View →',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.warning,
                statusColor: AppColors.amberDark,
                title: '${missingTrips.length} Unclassified Drives',
                subtitle: 'Classify as Business or Personal for %',
                actionLabel: 'Review →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  TripQuickResolveSheet.show(context,
                      trip: missingTrips.first, appState: appState);
                },
              ),
            const SizedBox(height: 10),
            if (unclassifiedExpenses.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.confirmed,
                statusColor: AppColors.emerald,
                title: 'Receipt details confirmed',
                subtitle: 'Receipt files are checked when preparing the pack',
                actionLabel: 'Vault →',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: AppIcons.expenses,
                statusColor: AppColors.amberDark,
                title: '${unclassifiedExpenses.length} Expenses Need Review',
                subtitle: 'Confirm details and attach receipt photos',
                actionLabel: 'Fix →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveAuditRow({
    required BuildContext context,
    required IconData icon,
    required Color statusColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    bool isAlert = false,
    bool isActionEnabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActionEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: AdaptiveRow(
            children: [
              Icon(icon, size: 17, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isAlert ? AppColors.deepNavy : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isAlert ? AppColors.amberDark : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: !isActionEnabled
                      ? AppColor.surfaceMuted
                      : (isAlert ? AppColors.amberLight : AppColors.background),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: !isActionEnabled
                        ? AppColors.border
                        : (isAlert
                            ? AppColors.amberDark.withValues(alpha: 0.3)
                            : AppColors.border),
                  ),
                ),
                child: AdaptiveRow(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel.replaceAll('→', '').trim(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: !isActionEnabled
                            ? AppColors.muted
                            : (isAlert ? AppColors.deepNavy : AppColors.muted),
                      ),
                    ),
                    if (isActionEnabled && actionLabel.contains('→')) ...[
                      const SizedBox(width: 3),
                      Icon(
                        AppIcons.next,
                        size: AppIconSize.inline,
                        color: isAlert ? AppColors.deepNavy : AppColors.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleProfileSheet(BuildContext context, AppState appState) {
    final vehicle = appState.primaryVehicle;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AdaptiveRow(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(AppIcons.vehicle,
                        color: AppColors.emerald, size: AppIconSize.control),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle?.displayName ?? 'Vehicle Profile',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink),
                        ),
                        Text(
                          vehicle != null
                              ? 'Rego: ${vehicle.regoPlate} • Active Rig'
                              : 'No vehicle configured',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    AdaptiveRow(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax Strategy',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                        Text(
                          vehicle?.taxMethod.title ?? 'Cents per KM',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    AdaptiveRow(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ATO Logged Drives',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                        Text(
                          '${appState.trips.length} Trips',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.shieldCheck,
                    size: AppIconSize.inline),
                label: const Text('Open record checks',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Primary Handoff Flywheel: 1-Tap Accountant Pack
}
