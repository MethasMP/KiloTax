import '../onboarding/vehicle_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/tax_summary.dart';
import '../../../state/app_state.dart';
import '../../../services/engine/ato_report_service.dart';
import '../expenses/expense_capture_sheet.dart';
import '../trips/trip_review_sheet.dart';
import '../trips/trip_quick_resolve_sheet.dart';
import '../compliance/compliance_center_screen.dart';
import '../migration/migration_screen.dart';
import 'widgets/money_left_on_table_card.dart';

/// COMPLETE EVIDENCE ENGINE DASHBOARD (Layers 1-6):
/// Unifies Trips + Expenses -> Evidence Engine -> Cents/KM vs Logbook -> Tax Summary & ATO Report
class TaxDashboardScreen extends StatelessWidget {
  const TaxDashboardScreen({super.key});

  void _showAddTripDialog(BuildContext context, AppState appState) {
    final distController = TextEditingController(text: '32.5');
    String selectedPurpose = 'Client / Job Site';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(LucideIcons.car, color: AppColors.workBlue, size: 22),
              SizedBox(width: 8),
              Text('Log Drive Trip', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: distController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Distance (KM)',
                  suffixText: 'km',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('What was this trip for? (1-Tap)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Client / Job',
                  'Materials / Bunnings',
                  'Work Site',
                  'Client Meeting',
                  'Personal / Other',
                ].map((p) {
                  final isSel = selectedPurpose == p;
                  return ChoiceChip(
                    label: Text(p, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? Colors.white : AppColors.ink)),
                    selected: isSel,
                    selectedColor: AppColors.workBlue,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSel ? AppColors.workBlue : AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (val) {
                      if (val) setDialogState(() => selectedPurpose = p);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final dist = double.tryParse(distController.text) ?? 25.0;
                final isPersonal = selectedPurpose.contains('Personal');
                final lastOdo = appState.currentOdometer;
                final trip = Trip(
                  id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
                  vehicleId: appState.primaryVehicle?.id ?? 'default_vehicle',
                  distanceKm: dist,
                  date: DateTime.now(),
                  purpose: selectedPurpose,
                  startOdometer: lastOdo,
                  endOdometer: lastOdo + dist,
                  classification: isPersonal ? TripClassification.personal : TripClassification.business,
                );
                appState.recordTrip(trip);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save Trip', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _exportAtoReport(BuildContext context, AppState appState) {
    final engine = appState.createEvidenceEngine();
    final summary = appState.taxSummary;
    final vehicle = appState.primaryVehicle ?? engine.vehicle;
    final isCpk = vehicle.taxMethod == TaxMethod.centsPerKm;
    final csv = AtoReportService.generateMethodAppropriateCsv(
      vehicle: vehicle,
      engine: engine,
      summary: summary,
      taxRule: appState.activeTaxRule,
    );
    final emailText = AtoReportService.generateAccountantEmailText(
      vehicle: vehicle,
      summary: summary,
      tripCount: engine.trips.length,
      expenseCount: engine.expenses.length,
      taxRule: appState.activeTaxRule,
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
                    child: const Icon(LucideIcons.fileText, color: AppColors.emerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCpk ? 'ATO Box D1 (CPK) Tax Pack' : 'ATO TR 97/11 Logbook Audit Pack',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink),
                        ),
                        Text(
                          isCpk ? '1-Page Lodgement Summary & 14-Col Ledger' : 'Full 12-Week Audit Vault & Odometer Ledger',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                labelColor: AppColors.workBlue,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.workBlue,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: [
                  const Tab(text: 'Summary Email'),
                  Tab(text: isCpk ? 'CPK Ledger CSV' : 'TR 97/11 CSV Log'),
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
                    // Tab 2: Method Appropriate CSV
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
                      icon: const Icon(LucideIcons.copy, size: 18),
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
                      icon: const Icon(LucideIcons.share2, size: 18),
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
            icon: const Icon(LucideIcons.shieldCheck, color: AppColors.workBlue),
            tooltip: 'Tax Compliance Readiness',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComplianceCenterScreen(appState: appState),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.arrowLeftRight, color: AppColors.ink),
            tooltip: 'Import Past Records (Driversnote/CSV)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MigrationScreen(appState: appState),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.fileDown, color: AppColors.emerald),
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
                      appState.primaryVehicle?.vehicleType.iconData ?? Icons.directions_car_rounded,
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
                            if (appState.currentOdometer > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${appState.currentOdometer.toStringAsFixed(0)} km',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700),
                              ),
                            ],
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

            // DYNAMIC COMPLIANCE HUD:
            // If vehicle uses Cents/KM -> Show 5,000 km Statutory Cap & Progress Meter
            // If vehicle uses Logbook  -> Show 12-Week Statutory Period & Missing Purpose Tracker
            if (appState.primaryVehicle?.taxMethod == TaxMethod.centsPerKm) ...[
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
                          child: const Icon(LucideIcons.gauge, color: AppColors.workBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ATO CENTS-PER-KM 5,000 KM CAP',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
                              ),
                              Text(
                                '${Formatters.distance(summary.businessKm)} / 5,000 km',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: summary.businessKm >= 5000.0 ? AppColors.crimsonLight : AppColors.emeraldLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            summary.businessKm >= 5000.0
                                ? 'CAP REACHED'
                                : '${(5000.0 - summary.businessKm).clamp(0.0, 5000.0).toStringAsFixed(0)} KM REMAINING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: summary.businessKm >= 5000.0 ? AppColors.crimson : AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (summary.businessKm / 5000.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          summary.businessKm >= 5000.0 ? AppColors.crimson : AppColors.workBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          summary.businessKm >= 5000.0 ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                          size: 13,
                          color: summary.businessKm >= 5000.0 ? AppColors.crimson : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary.businessKm >= 5000.0
                                ? 'ATO maximum limit reached. Any additional business km should use Logbook.'
                                : 'Rate: ${(appState.activeTaxRule.centsPerKmRate * 100).toInt()}c/km. Fuel & repairs included in rate.',
                            style: TextStyle(
                              fontSize: 11,
                              color: summary.businessKm >= 5000.0 ? AppColors.crimson : AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Spec #2: [ Review trips ] CTA
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: () => TripReviewSheet.show(context, appState),
                      icon: const Icon(LucideIcons.search, size: 16, color: AppColors.ink),
                      label: const Text('Review trips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
            ] else ...[
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
                          child: const Icon(LucideIcons.shieldCheck, color: AppColors.workBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ATO 12-WEEK COMPLIANCE TRACKER',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
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

                    // Missing Record Quick-Action Card (Spec #6, #7, #8: 1-Tap Confirmation)
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
                            const Row(
                              children: [
                                Icon(LucideIcons.alertCircle, color: AppColors.amber, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Resolve Trip Purpose to prevent ATO Audit flags:',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.ink),
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
                                    TripQuickResolveSheet.show(
                                      context,
                                      trip: appState.missingComplianceTrips.first,
                                      appState: appState,
                                    );
                                  },
                                  child: const Text('1-Tap Resolve', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.emerald, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Continuous logbook entries preserved. Valid for 5 consecutive tax years.',
                            style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // STRATEGIC DIFFERENTIATION ADVISOR:
            MoneyLeftOnTableCard(appState: appState),

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
                      Text('Estimated Tax Deduction (ATO Form D1)', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, fontWeight: FontWeight.w600)),
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
                  const SizedBox(height: 14),
                  // Spec #17: Tax Season Claim Breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Car deduction', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                            Text(Formatters.currency(summary.highestClaim), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                        Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Other business costs', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                            Text(Formatters.currency(summary.totalDirectDeductions), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                        Text('=', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Tax Claim', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                            Text(
                              Formatters.currency(summary.highestClaim + summary.totalDirectDeductions),
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                    icon: const Icon(LucideIcons.car, size: 18),
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
                    icon: const Icon(LucideIcons.receipt, size: 18),
                    label: const Text('Snap Expense', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // RECENT TRIPS STREAM (Layer 1 Feed)
            Row(
              children: [
                const Icon(LucideIcons.car, size: 16, color: AppColors.workBlue),
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
                        child: Icon(t.isBusiness ? LucideIcons.briefcase : LucideIcons.user, size: 16, color: t.isBusiness ? AppColors.workBlue : AppColors.muted),
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
                const Icon(LucideIcons.receipt, size: 16, color: AppColors.emerald),
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
                        child: const Icon(LucideIcons.fuel, size: 16, color: AppColors.emerald),
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
