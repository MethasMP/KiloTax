import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tax_summary.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import '../../../state/app_state.dart';
import '../compliance/compliance_center_screen.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../evidence/evidence_review_screen.dart';
import '../home/widgets/trips_ledger_tab.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import '../vehicle/vehicle_setup_flow.dart';
import '../workflow/workflow_screen.dart';

class TaxSummaryScreen extends StatefulWidget {
  final EvidenceReviewService evidenceService;
  final VoidCallback? onViewTrips;
  final Future<void> Function(BuildContext, AppState) onSend;

  const TaxSummaryScreen({
    super.key,
    this.evidenceService = const EvidenceReviewService(),
    this.onViewTrips,
    this.onSend = TaxPackShareHelper.shareTaxPack,
  });

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  AppState? _appState;
  Map<String, ReceiptFileInspection> _receiptFiles = const {};
  bool _checking = true;
  bool _checkFailed = false;
  int _generation = 0;
  List<VehicleExpense> _inspectedExpenses = const [];
  String? _inspectedVehicleId;
  String? _inspectedFinancialYear;

  EvidenceReviewReport get _report {
    final state = _appState!;
    final vehicle = state.primaryVehicle;
    return widget.evidenceService.evaluate(
      vehicle: vehicle,
      financialYear: state.activeTaxRule.financialYear,
      trips: state.trips,
      expenses: state.expenses,
      receiptFiles: _receiptFiles,
      hasOdometerGaps: vehicle != null &&
          state.odometerGapsForVehicle(vehicle.id).isNotEmpty,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(state, _appState)) return;
    _appState?.removeListener(_refresh);
    _appState = state;
    state.addListener(_refresh);
    _inspect();
  }

  @override
  void dispose() {
    _generation++;
    _appState?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final report = _report;
    if (_inspectedVehicleId != report.vehicle?.id ||
        _inspectedFinancialYear != report.financialYear ||
        !listEquals(_inspectedExpenses, report.expenses)) {
      _inspect();
    } else {
      setState(() {});
    }
  }

  Future<void> _inspect() async {
    final generation = ++_generation;
    final report = _report;
    _inspectedExpenses = List.of(report.expenses);
    _inspectedVehicleId = report.vehicle?.id;
    _inspectedFinancialYear = report.financialYear;
    setState(() {
      _receiptFiles = const {};
      _checking = true;
      _checkFailed = false;
    });
    try {
      final files =
          await widget.evidenceService.inspectReceipts(report.expenses);
      if (!mounted || generation != _generation) return;
      setState(() {
        _receiptFiles = files;
        _checking = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _checkFailed = true;
      });
    }
  }

  Future<void> _primaryAction(EvidenceReviewReport report) async {
    HapticFeedback.mediumImpact();
    final state = _appState!;
    if (report.vehicle == null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => VehicleSetupFlow(
          onVehicleCreated: (vehicle) async {
            await state.addVehicle(vehicle);
            if (routeContext.mounted) Navigator.of(routeContext).pop();
          },
          onCancel: () => Navigator.of(routeContext).pop(),
        ),
      ));
    } else if (!report.hasRecords) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => report.vehicle!.taxMethod == TaxMethod.centsPerKm
            ? CpkTripEntryScreen(appState: state)
            : LogbookTripEntryScreen(appState: state),
      ));
    } else {
      await widget.onSend(context, state);
    }
    if (mounted) _inspect();
  }

  @override
  Widget build(BuildContext context) {
    final state = _appState!;
    final report = _report;
    final vehicle = report.vehicle;
    final summary = state.taxSummary;
    final isCpk =
        (vehicle?.taxMethod ?? TaxMethod.centsPerKm) == TaxMethod.centsPerKm;
    final actionLabel = vehicle == null
        ? 'Set up vehicle'
        : !report.hasRecords
            ? 'Add your first trip'
            : 'Send to accountant';
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: AppColor.canvas,
        title: const Text('Tax Summary'),
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: AppColor.canvas,
            border: Border(top: BorderSide(color: AppColor.hairline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const ValueKey('tax-primary-action'),
                onPressed: () => _primaryAction(report),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColor.ink,
                  foregroundColor: AppColor.onNavy,
                  elevation: 2,
                  shadowColor: AppColor.ink.withValues(alpha: 0.3),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AppType.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                icon: Icon(
                  !report.hasRecords
                      ? Icons.add
                      : report.vehicle == null
                          ? Icons.directions_car_outlined
                          : Icons.send_rounded,
                  size: 22,
                ),
                label: Text(actionLabel),
              ),
              if (report.hasRecords && report.vehicle != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Pre-flight review & verified ATO export package',
                    style: AppType.eyebrow.copyWith(
                      color: AppColor.inkSubtle,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('FY ${report.financialYear}', style: AppType.secondary),
          if (vehicle != null) ...[
            const SizedBox(height: 4),
            Text(vehicle.displayName, style: AppType.bodyStrong),
          ],
          const SizedBox(height: 16),
          if (report.hasRecords) ...[
            _buildCompactTaxClaimStrip(
              appState: state,
              totalClaim:
                  isCpk ? summary.centsPerKmClaim : summary.logbookClaim,
              isCpk: isCpk,
              primaryVehicle: vehicle,
            ),
            const SizedBox(height: 24),
          ],
          _buildReadiness(report),
          if (report.hasRecords) ...[
            const SizedBox(height: 24),
            const Text('Report details', style: AppType.section),
            const SizedBox(height: 8),
            _buildArbitrageAdvisorCard(summary: summary),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Detailed record checks',
                  style: AppType.bodyStrong),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ComplianceCenterScreen(appState: state),
              )),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trip → Job → Receipt → Pack',
                  style: AppType.bodyStrong),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => WorkflowScreen.show(context, state),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadiness(EvidenceReviewReport report) {
    final tripCount = report.items.whereType<TripReviewItem>().length;
    final expenseCount = report.items.whereType<ExpenseReviewItem>().length;
    final setupCount = report.items
        .where((item) =>
            item is OdometerReviewItem ||
            (item is SetupReviewItem &&
                item.reason != SetupReviewReason.noRecords))
        .length;
    final headline = report.vehicle == null
        ? 'Start with your vehicle'
        : !report.hasRecords
            ? 'Your evidence starts here'
            : _checking
                ? 'Checking your records'
                : _checkFailed
                    ? 'Receipt check needs another try'
                    : report.items.isEmpty
                        ? 'No outstanding record checks'
                        : '${report.items.length} ${report.items.length == 1 ? 'item needs' : 'items need'} attention';
    final isAuditProofReady = report.hasRecords &&
        !_checking &&
        !_checkFailed &&
        report.items.isEmpty;

    return Material(
      color: AppColor.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isAuditProofReady
              ? AppColor.positive.withValues(alpha: 0.5)
              : AppColor.hairline,
          width: isAuditProofReady ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: const Text('Evidence check', style: AppType.secondary),
                ),
                if (isAuditProofReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColor.positiveTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColor.positive.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColor.positiveStrong,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AUDIT-PROOF READY',
                          style: AppType.eyebrow.copyWith(
                            color: AppColor.positiveStrong,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(headline, style: AppType.cardTitle),
            const SizedBox(height: 8),
            Text(
                report.vehicle == null
                    ? 'Add your vehicle to keep trips and reports together.'
                    : !report.hasRecords
                        ? 'Add your first trip. Your deduction estimate will grow from the records you enter.'
                        : 'Review your records and receipt files before sharing with your accountant.',
                style: AppType.body),
            if (_checking && report.hasRecords) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Checking receipt files…', style: AppType.secondary),
            ],
            if (_checkFailed && report.hasRecords) ...[
              const SizedBox(height: 8),
              const Text(
                  'Could not check receipt files. Your records are still available to review.',
                  style: AppType.secondary),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _inspect,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Retry receipt check'),
                ),
              ),
            ],
            if (report.hasRecords) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      EvidenceReviewScreen.show(context, appState: _appState!),
                  child: Text(_checking || _checkFailed
                      ? 'Review records'
                      : report.items.isEmpty
                          ? 'Review records'
                          : 'Review ${report.items.length} ${report.items.length == 1 ? 'item' : 'items'}'),
                ),
              ),
              const SizedBox(height: 16),
              _statusRow(
                  Icons.route_outlined, 'Trip details', tripCount, 'to review'),
              _statusRow(
                  Icons.receipt_long_outlined,
                  'Receipts',
                  expenseCount,
                  _checking || _checkFailed
                      ? 'awaiting file check'
                      : 'to review',
                  unresolved: _checking || _checkFailed),
              if (setupCount > 0)
                _statusRow(Icons.directions_car_outlined, 'Vehicle & odometer',
                    setupCount, 'to review'),
            ],
            if (report.vehicle != null) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title:
                    const Text('Record checklist', style: AppType.bodyStrong),
                subtitle: const Text('View the records behind this summary',
                    style: AppType.secondary),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recorded trip history',
                        style: AppType.bodyStrong),
                    subtitle: Text('${report.trips.length} drives recorded',
                        style: AppType.secondary),
                    trailing: TextButton(
                      onPressed: () {
                        if (report.trips.isEmpty) {
                          _primaryAction(report);
                        } else if (widget.onViewTrips != null) {
                          widget.onViewTrips!();
                        } else {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => TripsLedgerTab(
                              appState: _appState!,
                              initialVehicleId: report.vehicle?.id,
                              financialYear: report.financialYear,
                            ),
                          ));
                        }
                      },
                      child: Text(report.trips.isEmpty ? 'Log drive' : 'View'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Business trip details',
                        style: AppType.bodyStrong),
                    subtitle: Text(
                        report.trips.isEmpty
                            ? 'Awaiting Drives'
                            : '$tripCount trips to review',
                        style: AppType.secondary),
                    onTap: report.trips.isEmpty
                        ? null
                        : () => EvidenceReviewScreen.show(context,
                            appState: _appState!),
                    trailing: report.trips.isEmpty
                        ? null
                        : const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String title, int count, String suffix,
      {bool unresolved = false}) {
    final pending = count > 0 || unresolved;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 20,
      leading: Icon(icon, color: AppColor.inkMuted, size: 20),
      title: Text(title, style: AppType.bodyStrong),
      subtitle: Text(
          unresolved
              ? suffix
              : count > 0
                  ? '$count $suffix'
                  : 'No outstanding checks',
          style: AppType.secondary.copyWith(
              color: pending ? AppColor.attentionInk : AppColor.inkMuted)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => EvidenceReviewScreen.show(context, appState: _appState!),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(Formatters.currency(totalClaim),
              style: AppType.title.copyWith(fontFeatures: AppType.tabular)),
        ),
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

  Widget _buildArbitrageAdvisorCard({
    required TaxSummary summary,
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
}
