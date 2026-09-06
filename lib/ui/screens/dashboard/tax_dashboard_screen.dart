import '../onboarding/vehicle_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/tax_summary.dart';
import '../../../state/app_state.dart';
import '../../../services/engine/ato_report_service.dart';
import '../expenses/expense_capture_sheet.dart';

/// COMPLETE EVIDENCE ENGINE DASHBOARD (Layers 1-6):
/// Unifies Trips + Expenses -> Evidence Engine -> Cents/KM vs Logbook -> Tax Summary & ATO Report
class TaxDashboardScreen extends StatelessWidget {
  const TaxDashboardScreen({super.key});

  void _showAddTripDialog(BuildContext context, AppState appState) {
    final distController = TextEditingController(text: '45.0');
    final purposeController = TextEditingController(text: 'Client site electrical service');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Simulate Drive Trip', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: distController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Distance (KM)'),
            ),
            TextField(
              controller: purposeController,
              decoration: const InputDecoration(labelText: 'Trip Purpose'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.workBlue, foregroundColor: Colors.white),
            onPressed: () {
              final dist = double.tryParse(distController.text) ?? 25.0;
              final trip = Trip(
                id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
                vehicleId: appState.primaryVehicle?.id ?? 'default_vehicle',
                distanceKm: dist,
                date: DateTime.now(),
                purpose: purposeController.text.trim(),
                startOdometer: 10000.0,
                endOdometer: 10000.0 + dist,
                classification: TripClassification.business,
              );
              appState.recordTrip(trip);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Business Trip'),
          ),
        ],
      ),
    );
  }

  void _exportAtoReport(BuildContext context, AppState appState) {
    final engine = appState.createEvidenceEngine();
    final summary = appState.taxSummary;
    final vehicle = appState.primaryVehicle ?? engine.vehicle;
    final csv = AtoReportService.generateAtoAuditCsv(
      vehicle: vehicle,
      engine: engine,
      summary: summary,
    );
    final emailText = AtoReportService.generateAccountantEmailText(
      vehicle: vehicle,
      summary: summary,
      tripCount: engine.trips.length,
      expenseCount: engine.expenses.length,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(PhosphorIconsFill.fileText, color: AppColors.emerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Accountant-Ready Pack', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink)),
                        Text('ATO TR 97/11 Schedule D1 & Evidence Graph', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const TabBar(
                labelColor: AppColors.workBlue,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.workBlue,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: [
                  Tab(text: 'Summary Email'),
                  Tab(text: 'TR 97/11 CSV Log'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Direct 1-Click Accountant Email
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          emailText,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.ink, height: 1.4),
                        ),
                      ),
                    ),
                    // Tab 2: Full Audit CSV Schedule
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          csv,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: AppColors.ink, height: 1.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: emailText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Accountant summary copied to clipboard!')),
                        );
                      },
                      icon: const Icon(PhosphorIconsBold.copy, size: 18),
                      label: const Text('Copy Email', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Audit Pack sent! Your accountant will love you.'),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      },
                      icon: const Icon(PhosphorIconsBold.shareNetwork, size: 18),
                      label: const Text('Send Pack', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final summary = appState.taxSummary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('KiloTax Evidence Engine', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.fileArrowDown, color: AppColors.emerald),
            tooltip: 'Export ATO Report',
            onPressed: () => _exportAtoReport(context, appState),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MULTI-VEHICLE SWITCHER & + ADD VEHICLE (User Journey Aligned)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      color: AppColors.workBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      (appState.primaryVehicle?.vehicleType == VehicleType.ute)
                          ? PhosphorIconsFill.truck
                          : ((appState.primaryVehicle?.vehicleType == VehicleType.van)
                              ? PhosphorIconsFill.van
                              : PhosphorIconsFill.carProfile),
                      color: AppColors.workBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.primaryVehicle != null
                              ? '${appState.primaryVehicle!.make} ${appState.primaryVehicle!.model}'
                              : 'No Vehicle Configured',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              appState.primaryVehicle?.regoPlate ?? '',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                appState.primaryVehicle?.taxMethod.shortBadge ?? '91c/km',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.emerald),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Add Vehicle Button (Fast flow, no need to reset entire app)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.workBlue,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: AppColors.workBlue.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => VehicleOnboardingScreen(
                            isDismissible: true,
                            onCompleted: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('+ Add Vehicle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),

            // 12-WEEK STATUTORY COMPLIANCE TRACKER & COMPLIANCE STATE
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.workBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(PhosphorIconsFill.shieldCheck, color: AppColors.workBlue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATO 12-WEEK COMPLIANCE TRACKER',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
                            ),
                            Text(
                              'Week ${appState.currentLogbookWeek} of 12 (${(appState.logbookProgressPercentage * 100).toInt()}%)',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: appState.missingComplianceTrips.isEmpty ? AppColors.emeraldLight : AppColors.amberLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              appState.missingComplianceTrips.isEmpty ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              size: 13,
                              color: appState.missingComplianceTrips.isEmpty ? AppColors.emerald : AppColors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appState.missingComplianceTrips.isEmpty
                                  ? '100% CLAIM-READY'
                                  : '${appState.missingComplianceTrips.length} MISSING RECORDS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: appState.missingComplianceTrips.isEmpty ? AppColors.emerald : AppColors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 12-Week Linear Progress Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: appState.logbookProgressPercentage,
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.workBlue),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Missing Record Quick-Action Card (if any)
                  if (appState.missingComplianceTrips.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amberLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(PhosphorIconsBold.warningCircle, color: AppColors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Resolve Trip Purpose to prevent ATO Audit flags:',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '🚗 ${appState.missingComplianceTrips.first.distanceKm} km trip missing work reason',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.amber,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  appState.resolveTripPurpose(
                                    appState.missingComplianceTrips.first.id,
                                    'Client Job Site Service & Installation',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Trip marked as Client Job Site (100% Deductible).')),
                                  );
                                },
                                child: const Text('Mark as Job Site', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppColors.emerald, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Continuous logbook entries preserved. Valid for 5 consecutive tax years.',
                          style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // TAX SUMMARY: Optimal Comparison Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.ink, Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          summary.recommendedMethod == RecommendedMethod.logbook ? 'LOGBOOK METHOD OPTIMAL' : 'CENTS/KM METHOD OPTIMAL',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.greenAccent),
                        ),
                      ),
                      const Spacer(),
                      Text('ATO Box D1', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Formatters.currency(summary.highestClaim),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Higher by ${Formatters.currency(summary.taxSavingsDiff)} vs alternative method',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DUAL METHOD COMPARISON TIERS
            Row(
              children: [
                Expanded(
                  child: _buildComparisonCard(
                    title: 'Cents / KM Method',
                    claim: summary.centsPerKmClaim,
                    metric: '${Formatters.distance(summary.businessKm)} @ 91c',
                    isRecommended: summary.recommendedMethod == RecommendedMethod.centsPerKm,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildComparisonCard(
                    title: 'Logbook Method',
                    claim: summary.logbookClaim,
                    metric: '${Formatters.percentage(summary.businessPercentage)} of ${Formatters.currency(summary.totalRunningExpenses)}',
                    isRecommended: summary.recommendedMethod == RecommendedMethod.logbook,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // USER ACTIVITY RECORDING ACTIONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.workBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddTripDialog(context, appState),
                    icon: const Icon(PhosphorIconsBold.steeringWheel, size: 18),
                    label: const Text('Log Trip', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => ExpenseCaptureSheet.show(context, appState),
                    icon: const Icon(PhosphorIconsBold.receipt, size: 18),
                    label: const Text('Snap Expense', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            const SizedBox(height: 24),

            // RECENT TRIPS STREAM (Layer 1 Feed)
            Row(
              children: [
                const Icon(PhosphorIconsFill.steeringWheel, size: 16, color: AppColors.workBlue),
                const SizedBox(width: 6),
                const Text('RECENT TRIPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                const Spacer(),
                Text('${appState.trips.length} recorded', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            if (appState.trips.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: const Center(child: Text('No trips recorded yet. Tap "Log Trip" to start.', style: TextStyle(fontSize: 12, color: AppColors.muted))),
              )
            else
              ...appState.trips.reversed.take(3).map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: t.isBusiness ? AppColors.workBlueLight : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Icon(t.isBusiness ? PhosphorIconsBold.briefcase : PhosphorIconsBold.user, size: 16, color: t.isBusiness ? AppColors.workBlue : AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.purpose, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                            Text('${t.startOdometer.toStringAsFixed(0)} -> ${t.endOdometer.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Text(Formatters.distance(t.distanceKm), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink)),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),

            // RECENT EXPENSES LEDGER (Layer 2 Feed)
            Row(
              children: [
                const Icon(PhosphorIconsFill.receipt, size: 16, color: AppColors.emerald),
                const SizedBox(width: 6),
                const Text('SUBSTANTIATED EXPENSES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                const Spacer(),
                Text('${appState.expenses.length} receipts', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            if (appState.expenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: const Center(child: Text('No expenses recorded yet. Tap "Snap Expense" to attach receipt.', style: TextStyle(fontSize: 12, color: AppColors.muted))),
              )
            else
              ...appState.expenses.reversed.take(3).map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.emeraldLight, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(PhosphorIconsBold.gasPump, size: 16, color: AppColors.emerald),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.category.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                            Text(e.receiptPath != null ? '✓ Receipt Attached' : 'Manual Entry', style: TextStyle(fontSize: 11, color: e.receiptPath != null ? AppColors.emerald : AppColors.muted)),
                          ],
                        ),
                      ),
                      Text(Formatters.currency(e.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required double claim,
    required String metric,
    required bool isRecommended,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? AppColors.emerald : AppColors.border,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(Formatters.currency(claim), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(metric, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
