import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tax_summary.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import '../../../state/app_state.dart';
import '../compliance/compliance_center_screen.dart';
import '../trips/trip_detection_screen.dart';
import '../trips/trip_quick_resolve_sheet.dart';

/// Frontier World-Class "ATO Tax Agent Desk"
/// Designed with the discipline of Steve Jobs & Senior Tax Agent compliance:
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
    final primaryVehicle = appState.primaryVehicle;
    final isCpk = (primaryVehicle?.taxMethod ?? TaxMethod.centsPerKm) == TaxMethod.centsPerKm;

    final vehicleClaim = isCpk ? summary.centsPerKmClaim : summary.logbookClaim;
    final otherExpenses = summary.totalDirectDeductions;
    final totalClaim = isCpk ? summary.centsPerKmClaim : (vehicleClaim + otherExpenses);

    final score = appState.taxReadinessScore;
    final missingTrips = appState.missingComplianceTrips;
    final unclassifiedExpenses = appState.unclassifiedExpenses;
    final totalIssues = missingTrips.length + (isCpk ? 0 : unclassifiedExpenses.length);

    // Contextual Arbitrage Status
    final hasActivity = summary.totalKm > 0 || summary.totalRunningExpenses > 0;
    final logbookHasAdvantage = summary.recommendedMethod == RecommendedMethod.logbook && summary.taxSavingsDiff > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          children: [
            const Text(
              'Tax Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'FY ${AppConstants.activeTaxRule.financialYear} • ATO Schedule D1',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share Tax Pack (PDF + CSV)',
            icon: const Icon(LucideIcons.share2, size: 19, color: AppColors.deepNavy),
            onPressed: () => TaxPackShareHelper.shareTaxPack(context, appState),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HERO STATEMENT: Single Source of Truth for Deductions
            _buildHeroStatementCard(
              context: context,
              totalClaim: totalClaim,
              vehicleClaim: vehicleClaim,
              otherExpenses: otherExpenses,
              isCpk: isCpk,
              primaryVehicle: primaryVehicle,
            ),
            const SizedBox(height: 16),

            // 2. INTELLIGENT METHOD ARBITRAGE CARD (Steve Jobs context-aware intelligence)
            _buildArbitrageAdvisorCard(
              context: context,
              appState: appState,
              summary: summary,
              isCpk: isCpk,
              hasActivity: hasActivity,
              logbookHasAdvantage: logbookHasAdvantage,
            ),
            const SizedBox(height: 16),

            // 3. ATO AUDIT-READINESS INTEGRITY CARD
            _buildAuditReadinessCard(
              context: context,
              appState: appState,
              score: score,
              totalIssues: totalIssues,
              missingTrips: missingTrips,
              unclassifiedExpenses: unclassifiedExpenses,
              isCpk: isCpk,
            ),
            const SizedBox(height: 16),

            // 4. THE ACCOUNTANT HAND-OFF FLYWHEEL
            _buildAccountantHandoffCard(context, appState, isCpk, totalClaim, score),
          ],
        ),
      ),
    );
  }

  /// 1. Hero Statement: Single, Authoritative, Clear
  Widget _buildHeroStatementCard({
    required BuildContext context,
    required double totalClaim,
    required double vehicleClaim,
    required double otherExpenses,
    required bool isCpk,
    required Vehicle? primaryVehicle,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ESTIMATED DEDUCTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.muted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isCpk ? AppColors.workBlueLight : AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCpk ? LucideIcons.gauge : LucideIcons.bookOpen,
                      size: 11.5,
                      color: isCpk ? AppColors.deepNavy : AppColors.emerald,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCpk ? 'Cents / KM (${(AppConstants.activeTaxRule.centsPerKmRate * 100).toStringAsFixed(0)}¢)' : 'Logbook Method',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCpk ? AppColors.deepNavy : AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hero Number with subtle currency symbol
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Formatters.currency(totalClaim),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AUD',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ATO Compliance Subtitle: Clean Apple Minimalist Standard
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.emerald),
              const SizedBox(width: 5),
              Text(
                primaryVehicle != null && primaryVehicle.regoPlate.isNotEmpty && primaryVehicle.regoPlate != 'No Plate'
                    ? 'ATO Work Deductions • ${primaryVehicle.regoPlate}'
                    : 'ATO Work-Related Car Deductions',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),

          if (!isCpk && (vehicleClaim > 0 || otherExpenses > 0)) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSplitMetric('Vehicle Running Costs', Formatters.currency(vehicleClaim)),
                _buildSplitMetric('Direct Tolls & Parking', Formatters.currency(otherExpenses)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ],
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
    if (!hasActivity) {
      // Quiet Luxury State: No activity yet -> Ambient guidance
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.scale, size: 18, color: AppColors.deepNavy),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATO Method Arbitrage Standing By',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Drive or log expenses. KiloTax will calculate whether CPK or Logbook gives you more tax cash back.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (logbookHasAdvantage && isCpk) {
      // High-Value Arbitrage Opportunity: Logbook offers higher yield!
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2B48), Color(0xFF0B1F33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepNavy.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, size: 11, color: Color(0xFF34D399)),
                      SizedBox(width: 5),
                      Text(
                        'LOGBOOK ADVANTAGE DETECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '+${Formatters.currency(summary.taxSavingsDiff)} extra',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF34D399),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Switching to the Logbook method will unlock an estimated +${Formatters.currency(summary.taxSavingsDiff)} extra deductions from actual fuel, servicing and depreciation.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFE2E8F0),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonPill(
                    label: 'Cents / KM (Current)',
                    amount: Formatters.currency(summary.centsPerKmClaim),
                    isActive: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildComparisonPill(
                    label: 'Logbook (Optimal)',
                    amount: Formatters.currency(summary.logbookClaim),
                    isActive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default Balanced State (CPK is currently optimal or equivalent)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emeraldLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.check, size: 16, color: AppColors.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCpk ? 'Cents per KM is currently optimal' : 'Logbook method active',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  isCpk
                      ? 'Maximum deduction with zero fuel receipt substantiation required.'
                      : 'Tracking actual running expenses multiplied by your business use %.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPill({required String label, required String amount, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFF34D399) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isActive ? const Color(0xFF34D399) : Colors.white,
            ),
          ),
        ],
      ),
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
    final hasNoTrips = appState.trips.isEmpty;
    final readinessTitle = hasNoTrips
        ? 'Setup Complete'
        : (score >= 90 ? 'ATO Audit-Ready' : 'Substantiation in Progress');

    final readinessColor = score >= 90
        ? AppColors.emerald
        : (hasNoTrips
            ? const Color(0xFF2563EB) // Royal Blue: Calm, armed, setup complete
            : (score >= 50 ? AppColors.amberDark : AppColors.crimson));

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUDIT READINESS SCORE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    readinessTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: readinessColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 7,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(readinessColor),
            ),
          ),
          const SizedBox(height: 14),

          // Actionable State / Review Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalIssues == 0
                    ? (hasNoTrips ? 'Awaiting initial drive logs' : 'All logged records substantiated')
                    : '$totalIssues ${totalIssues == 1 ? "item needs" : "items need"} attention',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: totalIssues == 0 ? AppColors.muted : AppColors.amberDark,
                ),
              ),
              if (totalIssues > 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ComplianceCenterScreen(appState: appState),
                      ),
                    );
                  },
                  child: const Text(
                    'Review all →',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),

          // Interactive ATO Audit Ledger (Kidlin's Law: Zero Ambiguity, 100% Actionable)
          _buildInteractiveAuditRow(
            context: context,
            icon: appState.hasVehicle ? LucideIcons.checkCircle2 : LucideIcons.circle,
            statusColor: appState.hasVehicle ? AppColors.emerald : AppColors.muted,
            title: 'Vehicle Profile',
            subtitle: appState.primaryVehicle?.displayName ?? 'Not configured',
            actionLabel: appState.hasVehicle ? 'Edit →' : 'Setup →',
            onTap: () {
              HapticFeedback.lightImpact();
              _showVehicleProfileSheet(context, appState);
            },
          ),
          const SizedBox(height: 10),

          _buildInteractiveAuditRow(
            context: context,
            icon: appState.primaryVehicle != null ? LucideIcons.checkCircle2 : LucideIcons.circle,
            statusColor: appState.primaryVehicle != null ? AppColors.emerald : AppColors.muted,
            title: 'ATO Tax Method',
            subtitle: isCpk ? 'Cents per KM (91¢/km)' : 'Logbook Method (Actual Expenses)',
            actionLabel: 'Active',
            isActionEnabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 10),

          if (isCpk) ...[
            _buildInteractiveAuditRow(
              context: context,
              icon: appState.trips.isNotEmpty ? LucideIcons.checkCircle2 : LucideIcons.circle,
              statusColor: appState.trips.isNotEmpty ? AppColors.emerald : AppColors.muted,
              title: 'Reasonable estimate basis established',
              subtitle: appState.trips.isNotEmpty
                  ? '${appState.trips.length} drives recorded'
                  : 'Awaiting initial drive logs',
              actionLabel: appState.trips.isNotEmpty ? 'View →' : 'Log Drive →',
              onTap: () {
                HapticFeedback.lightImpact();
                TripDetectionScreen.show(context, appState);
              },
            ),
            const SizedBox(height: 10),

            if (appState.trips.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.circle,
                statusColor: AppColors.muted,
                title: 'Business trips substantiated',
                subtitle: 'Awaiting drive logs to substantiate',
                actionLabel: 'Awaiting Drives',
                isActionEnabled: false,
                onTap: () {},
              )
            else if (missingTrips.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.checkCircle2,
                statusColor: AppColors.emerald,
                title: 'Business trips substantiated',
                subtitle: '${appState.trips.length} drives verified & ATO compliant',
                actionLabel: 'Details →',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.alertTriangle,
                statusColor: AppColors.amberDark,
                title: '${missingTrips.length} Trips Need Work Purpose',
                subtitle: 'ATO requires clear business justification',
                actionLabel: 'Resolve Now →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  TripQuickResolveSheet.show(context, trip: missingTrips.first, appState: appState);
                },
              ),
          ] else ...[
            _buildInteractiveAuditRow(
              context: context,
              icon: (appState.primaryVehicle?.initialOdometer ?? 0) > 0 ? LucideIcons.checkCircle2 : LucideIcons.circle,
              statusColor: (appState.primaryVehicle?.initialOdometer ?? 0) > 0 ? AppColors.emerald : AppColors.muted,
              title: 'Starting Odometer',
              subtitle: (appState.primaryVehicle?.initialOdometer ?? 0) > 0
                  ? '${appState.primaryVehicle!.initialOdometer.toStringAsFixed(0)} km recorded'
                  : 'Opening reading required by ATO',
              actionLabel: (appState.primaryVehicle?.initialOdometer ?? 0) > 0 ? 'Edit →' : 'Record →',
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
                icon: LucideIcons.checkCircle2,
                statusColor: AppColors.emerald,
                title: 'Logbook Trips Classified',
                subtitle: 'All trips split by business & personal',
                actionLabel: 'View →',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.alertTriangle,
                statusColor: AppColors.amberDark,
                title: '${missingTrips.length} Unclassified Drives',
                subtitle: 'Classify as Business or Personal for %',
                actionLabel: 'Review →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  TripQuickResolveSheet.show(context, trip: missingTrips.first, appState: appState);
                },
              ),
            const SizedBox(height: 10),

            if (unclassifiedExpenses.isEmpty)
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.checkCircle2,
                statusColor: AppColors.emerald,
                title: 'Receipts Backed Up',
                subtitle: 'Fuel, rego and service receipts in vault',
                actionLabel: 'Vault →',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
              )
            else
              _buildInteractiveAuditRow(
                context: context,
                icon: LucideIcons.receipt,
                statusColor: AppColors.amberDark,
                title: '${unclassifiedExpenses.length} Receipts Need Category',
                subtitle: 'Add expense type and receipt photo',
                actionLabel: 'Fix →',
                isAlert: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplianceCenterScreen(appState: appState),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
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
                      ? const Color(0xFFF1F5F9)
                      : (isAlert ? AppColors.amberLight : AppColors.background),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: !isActionEnabled
                        ? AppColors.border
                        : (isAlert ? AppColors.amberDark.withValues(alpha: 0.3) : AppColors.border),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: !isActionEnabled
                        ? AppColors.muted
                        : (isAlert ? AppColors.deepNavy : AppColors.muted),
                  ),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.car, color: AppColors.emerald, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle?.displayName ?? 'Vehicle Profile',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        Text(
                          vehicle != null ? 'Rego: ${vehicle.regoPlate} • Active Rig' : 'No vehicle configured',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax Strategy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
                        Text(
                          vehicle?.taxMethod.title ?? 'Cents per KM',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ATO Logged Drives', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
                        Text(
                          '${appState.trips.length} Trips',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
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
                      builder: (_) => ComplianceCenterScreen(appState: appState),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.shieldCheck, size: 16),
                label: const Text('View Full Compliance Audit', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  Widget _buildAccountantHandoffCard(
    BuildContext context,
    AppState appState,
    bool isCpk,
    double totalClaim,
    int score,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.userCheck, color: AppColors.deepNavy, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accountant Hand-off',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Email ATO Tax Pack (PDF + CSV) in 1 tap',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.mail, size: 16),
            label: const Text(
              'Share with Accountant',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => TaxPackShareHelper.shareTaxPack(context, appState),
          ),
        ],
      ),
    );
  }
}

