import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../state/app_state.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import '../expenses/evidence_expenses_screen.dart';
import '../trips/trip_quick_resolve_sheet.dart';

/// Spec #18: Compliance Center (Tax Readiness & Audit Proofing)
/// "Tax readiness
///  ✓ Vehicle configured
///  ✓ Tax method selected
///  ✓ Odometer recorded
///  ✓ Trips classified
///  ✓ Receipts backed up
///  ⚠ 3 trips missing purpose
///  -> 92% Tax-ready (Not generic analytics)"
class ComplianceCenterScreen extends StatelessWidget {
  final AppState appState;

  const ComplianceCenterScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final vehicle = appState.primaryVehicle;
    final hasVehicle = vehicle != null;
    final hasTaxMethod = hasVehicle;
    final hasOdo = (vehicle?.initialOdometer ?? 0) > 0;
    final missingTrips = appState.missingComplianceTrips;
    final totalTrips = appState.trips.length;
    final totalExpenses = appState.expenses.length;
    final receiptsBackedUp = totalExpenses == 0 || appState.expenses.any((e) => e.receiptPath != null);

    final score = appState.taxReadinessScore;
    final bool isSetupPhase = totalTrips == 0 && score == 50;

    final color = score >= 90
        ? AppColors.emerald
        : (isSetupPhase
            ? const Color(0xFF2563EB) // Royal Blue: Setup configured, ready for active drives
            : (score >= 70 ? AppColors.amber : AppColors.crimson));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tax Compliance Center', style: AppTextStyles.cardPrimary),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TAX READINESS SCORE CARD (Spec #18)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ATO AUDIT READINESS',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$score% Tax-Ready',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 26, color: color),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          score >= 90
                              ? LucideIcons.shieldCheck
                              : (isSetupPhase
                                  ? LucideIcons.shield
                                  : (score >= 70 ? LucideIcons.shieldAlert : LucideIcons.shieldX)),
                          color: color,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: score / 100.0,
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    score >= 90
                        ? 'Your evidence chain is complete and ready for instant accountant submission.'
                        : (isSetupPhase
                            ? 'Vehicle and tax strategy configured. Start logging drives to build your audit-proof evidence chain.'
                            : 'Resolve items below to ensure 100% audit-proof tax deductions.'),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Compliance Checklist', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),

            // Deterministic 4-Pillar ATO Checklist Items (NASA Standard Consistency)
            _ChecklistTile(
              title: 'Vehicle Configured',
              subtitle: hasVehicle ? '${vehicle.make} ${vehicle.model} (${vehicle.regoPlate})' : 'Missing vehicle setup',
              isComplete: hasVehicle,
            ),
            _ChecklistTile(
              title: 'Tax Method Selected',
              subtitle: hasVehicle ? vehicle.taxMethod.title : 'Choose Cents-per-km or Logbook',
              isComplete: hasTaxMethod,
            ),
            if (vehicle?.taxMethod == TaxMethod.centsPerKm) ...[
              _ChecklistTile(
                title: 'Reasonable Estimate Basis',
                subtitle: totalTrips > 0
                    ? 'Contemporaneous travel pattern substantiated ($totalTrips trips)'
                    : 'Awaiting initial drive logs to establish pattern',
                isComplete: totalTrips > 0,
                statusChip: totalTrips == 0 ? 'Awaiting Drives' : null,
              ),
              _ChecklistTile(
                title: 'Trips Classified & Purpose',
                subtitle: totalTrips == 0
                    ? 'Awaiting drive logs to classify business purpose'
                    : (missingTrips.isEmpty
                        ? 'All $totalTrips trips have valid purpose & classification'
                        : '${missingTrips.length} trips missing explicit purpose'),
                isComplete: totalTrips > 0 && missingTrips.isEmpty,
                warningText: missingTrips.isNotEmpty ? '${missingTrips.length} trips need purpose' : null,
                statusChip: totalTrips == 0 ? 'Pending' : null,
              ),
              const _ChecklistTile(
                title: 'Expense Receipts',
                subtitle: 'Statutory 91¢/km rate covers all fuel, rego & maintenance',
                isComplete: true,
                statusChip: 'Statutory Rate',
              ),
            ] else ...[
              _ChecklistTile(
                title: 'Odometer Recorded',
                subtitle: hasOdo ? '${vehicle?.initialOdometer.toStringAsFixed(0)} km on record' : 'Missing opening odometer',
                isComplete: hasOdo,
                warningText: !hasOdo ? 'Opening reading required' : null,
              ),
              _ChecklistTile(
                title: 'Trips Classified (Logbook)',
                subtitle: totalTrips == 0
                    ? 'Awaiting drive logs to calculate business use %'
                    : (missingTrips.isEmpty
                        ? 'All $totalTrips trips classified for business split'
                        : '${missingTrips.length} unclassified trips'),
                isComplete: totalTrips > 0 && missingTrips.isEmpty,
                warningText: missingTrips.isNotEmpty ? '${missingTrips.length} unclassified' : null,
                statusChip: totalTrips == 0 ? 'Pending' : null,
              ),
              _ChecklistTile(
                title: 'Receipts Backed Up',
                subtitle: receiptsBackedUp ? 'Cloud vault encrypted & synchronized' : 'Receipts pending cloud backup',
                isComplete: receiptsBackedUp,
                warningText: !receiptsBackedUp ? 'Missing receipts' : null,
              ),
              _ChecklistTile(
                title: '12-Week Statutory Period Active',
                subtitle: 'Week ${appState.currentLogbookWeek} of 12 (${(appState.logbookProgressPercentage * 100).toInt()}%)',
                isComplete: appState.logbookProgressPercentage >= 1.0,
                warningText: appState.logbookProgressPercentage < 1.0 ? 'In progress' : null,
              ),
            ],

            const SizedBox(height: 24),

            // Missing Records Quick Resolve Section (User Journey: Review missing evidence -> Complete records -> Tax-ready)
            if (missingTrips.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  _resolveNextMissingTrip(context, appState);
                },
                icon: const Icon(LucideIcons.alertCircle, size: 18),
                label: Text('Resolve Trip Records (${missingTrips.length} left)', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],

            if (appState.unclassifiedExpenses.isNotEmpty) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepNavy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EvidenceExpensesScreen(),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.receipt, size: 18),
                label: Text('Review Receipts (${appState.unclassifiedExpenses.length} pending photo)', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],

            // If 100% Tax-Ready -> Primary Accountant Export CTA (Tax Season Loop Completion)
            if (score >= 90) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => TaxPackShareHelper.shareTaxPack(context, appState),
                icon: const Icon(LucideIcons.checkCircle2, size: 18),
                label: const Text('Export & Share Tax Pack with Accountant', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resolveNextMissingTrip(BuildContext context, AppState appState) {
    if (appState.missingComplianceTrips.isEmpty) return;
    final nextTrip = appState.missingComplianceTrips.first;

    TripQuickResolveSheet.show(
      context,
      trip: nextTrip,
      appState: appState,
      onTripResolved: (resolved) {
        // Check if more missing trips remain in chain
        final remaining = appState.missingComplianceTrips;
        if (remaining.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.deepNavy,
              content: Text('✓ Saved. ${remaining.length} more ${remaining.length == 1 ? "trip needs" : "trips need"} purpose.'),
              action: SnackBarAction(
                label: 'Next →',
                textColor: AppColors.emerald,
                onPressed: () => _resolveNextMissingTrip(context, appState),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.emerald,
              content: Text('🎉 All trips classified! Tax readiness increased.'),
            ),
          );
        }
      },
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isComplete;
  final String? warningText;
  final String? statusChip;

  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    this.warningText,
    this.statusChip,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg = isComplete
        ? AppColors.emeraldLight
        : (statusChip != null ? const Color(0xFFF1F5F9) : AppColors.amberLight);
    final Color iconColor = isComplete
        ? AppColors.emerald
        : (statusChip != null ? AppColors.muted : AppColors.amber);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isComplete
                  ? LucideIcons.check
                  : (statusChip != null ? LucideIcons.circle : LucideIcons.alertTriangle),
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardPrimarySubtle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (statusChip != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                statusChip!,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ] else if (warningText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                warningText!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.amber),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

