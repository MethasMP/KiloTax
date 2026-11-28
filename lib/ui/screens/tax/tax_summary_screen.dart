import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/engine/accountant_export_scope.dart';
import '../../../services/engine/tax_calculator_service.dart';
import '../../../services/tax/ato_tax_period_engine.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tax_summary.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import '../../../state/app_state.dart';
import '../evidence/evidence_review_screen.dart';
import '../home/widgets/trips_ledger_tab.dart';

class TaxSummaryScreen extends StatefulWidget {
  final EvidenceReviewService evidenceService;
  final String? initialVehicleId;
  final String? initialFinancialYear;
  final int scopeRequest;
  final VoidCallback? onViewTrips;
  final Future<void> Function(BuildContext, AppState)? onSend;

  const TaxSummaryScreen({
    super.key,
    this.initialVehicleId,
    this.initialFinancialYear,
    this.scopeRequest = 0,
    this.evidenceService = const EvidenceReviewService(),
    this.onViewTrips,
    this.onSend,
  });

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  AppState? _appState;
  String? _vehicleId;
  String? _financialYear;
  Map<String, AtoTaxRule> _rules = {};
  String get _year => AccountantExportScope.normalizeYear(
      _financialYear ?? _appState!.activeTaxRule.financialYear);
  Vehicle? get _selectedVehicle => _vehicleId == null
      ? _appState!.primaryVehicle
      : _appState!.vehicles.where((v) => v.id == _vehicleId).firstOrNull;
  AtoTaxRule? get _rule => _year ==
          AccountantExportScope.normalizeYear(
              _appState!.activeTaxRule.financialYear)
      ? _appState!.activeTaxRule
      : _rules[_year];
  Map<String, ReceiptFileInspection> _receiptFiles = const {};
  bool _checking = true;
  bool _checkFailed = false;
  bool _exporting = false;
  int _generation = 0;
  List<VehicleExpense> _inspectedExpenses = const [];
  String? _inspectedVehicleId;
  String? _inspectedFinancialYear;

  EvidenceReviewReport get _report {
    final state = _appState!;
    final vehicle = _selectedVehicle;
    return widget.evidenceService.evaluate(
      vehicle: vehicle,
      financialYear: _year,
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
    _vehicleId = widget.initialVehicleId ?? state.primaryVehicle?.id;
    _financialYear = AccountantExportScope.normalizeYear(
        widget.initialFinancialYear ?? state.activeTaxRule.financialYear);
    _rules = {
      AccountantExportScope.normalizeYear(state.activeTaxRule.financialYear):
          state.activeTaxRule
    };
    state.addListener(_refresh);
    _loadRules(state);
    _inspect();
  }

  @override
  void didUpdateWidget(covariant TaxSummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeRequest != widget.scopeRequest) {
      _vehicleId = widget.initialVehicleId;
      _financialYear = widget.initialFinancialYear;
      _inspect();
    }
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

  Future<void> _loadRules(AppState state) async {
    final rules = await AccountantExportScope.loadRules(state);
    if (mounted && identical(state, _appState)) setState(() => _rules = rules);
  }

  Future<void> _primaryAction(EvidenceReviewReport report) async {
    if (_exporting || !report.canExport || _rule == null) return;
    HapticFeedback.mediumImpact();
    final state = _appState!;
    final vehicleId = report.vehicle!.id;
    final year = report.financialYear;
    setState(() => _exporting = true);
    try {
      if (widget.onSend != null) {
        await widget.onSend!(context, state);
      } else {
        await TaxPackShareHelper.shareTaxPack(context, state,
            vehicleId: vehicleId, financialYear: year);
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
        _inspect();
      }
    }
  }

  void _reviewRecords() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EvidenceReviewScreen(
            appState: _appState!,
            vehicleId: _selectedVehicle?.id,
            financialYear: _year,
            onOpenPack: () => Navigator.of(context).pop()),
      ));

  void _viewRecords() {
    if (_selectedVehicle?.id == _appState!.primaryVehicle?.id &&
        _year ==
            AccountantExportScope.normalizeYear(
                _appState!.activeTaxRule.financialYear) &&
        widget.onViewTrips != null) {
      widget.onViewTrips!();
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TripsLedgerTab(
                appState: _appState!,
                initialVehicleId: _selectedVehicle?.id,
                financialYear: _year,
              )));
    }
  }

  Widget _scopeSelectors() {
    final state = _appState!;
    const periods = AtoTaxPeriodEngine();
    final currentStart =
        int.parse(state.activeTaxRule.financialYear.substring(0, 4));
    final years = <String>{
      _year,
      AccountantExportScope.normalizeYear(
          AtoFinancialYear(currentStart - 1).shortLabel),
      ..._rules.keys,
      ...state.trips.map((t) => AccountantExportScope.normalizeYear(
          periods.forDate(t.date).shortLabel)),
      ...state.expenses.map((e) => AccountantExportScope.normalizeYear(
          periods.forDate(e.date).shortLabel)),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final yearPicker = DropdownButtonFormField<String>(
      key: ValueKey('export-year-$_year'),
      initialValue: _year,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Financial year', border: OutlineInputBorder()),
      items: years
          .map((year) => DropdownMenuItem(
              value: year,
              child: Text('FY $year',
                  maxLines: 1, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: _exporting
          ? null
          : (value) {
              if (value == null || value == _year) return;
              setState(() => _financialYear = value);
              _inspect();
            },
    );
    final vehiclePicker = DropdownButtonFormField<String>(
      key: ValueKey('export-vehicle-${_selectedVehicle?.id}'),
      initialValue: _selectedVehicle?.id,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Vehicle', border: OutlineInputBorder()),
      hint: const Text('No vehicles'),
      items: state.vehicles
          .map((vehicle) => DropdownMenuItem(
              value: vehicle.id,
              child: Text(vehicle.displayName,
                  maxLines: 1, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: _exporting || state.vehicles.isEmpty
          ? null
          : (value) {
              if (value == null || value == _selectedVehicle?.id) return;
              setState(() => _vehicleId = value);
              _inspect();
            },
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
            children: [yearPicker, const SizedBox(height: 16), vehiclePicker]);
      }
      return Row(children: [
        Expanded(child: yearPicker),
        const SizedBox(width: 12),
        Expanded(child: vehiclePicker)
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final vehicle = report.vehicle;
    final rule = _rule;
    final summary = rule == null
        ? null
        : TaxCalculatorService.evaluateSummary(
            trips: report.trips, expenses: report.expenses, taxRule: rule);
    final isCpk =
        (vehicle?.taxMethod ?? TaxMethod.centsPerKm) == TaxMethod.centsPerKm;
    const actionLabel = 'Prepare pack';
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: AppColor.canvas,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Reports & export'),
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
                onPressed: _exporting || !report.canExport || rule == null
                    ? null
                    : () => _primaryAction(report),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColor.brand,
                  foregroundColor: AppColor.onNavy,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AppType.bodyStrong.copyWith(
                    fontFamily:
                        Theme.of(context).textTheme.bodyMedium?.fontFamily,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColor.onNavy,
                        ),
                      )
                    : const Icon(Icons.folder_zip_outlined, size: 22),
                label: Text(_exporting ? 'Preparing pack…' : actionLabel,
                    textAlign: TextAlign.center),
              ),
              if (report.hasRecords && report.vehicle != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Review before sharing.',
                    style: AppType.secondary.copyWith(
                      color: AppColor.inkSubtle,
                      fontSize: 12,
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
          _scopeSelectors(),
          const SizedBox(height: 16),
          if (rule == null) ...[
            const Text(
                'Tax settings are unavailable for this year. Choose another year or try again later.',
                style: AppType.secondary),
            const SizedBox(height: 12),
          ],
          _buildPackOverview(report),
          const SizedBox(height: 20),
          if (report.hasRecords) ...[
            _buildReadiness(report),
            const SizedBox(height: 20),
          ],
          _buildPackContents(hasRecords: report.hasRecords),
          if (report.hasRecords && summary != null && rule != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title:
                  const Text('Estimated deduction', style: AppType.bodyStrong),
              subtitle: const Text('View the estimate and calculation basis',
                  style: AppType.secondary),
              children: [
                _buildCompactTaxClaimStrip(
                  taxRule: rule,
                  businessKm: summary.businessKm,
                  totalClaim:
                      isCpk ? summary.centsPerKmClaim : summary.logbookClaim,
                  isCpk: isCpk,
                  primaryVehicle: vehicle,
                ),
                if (vehicle?.taxMethod != TaxMethod.actualExpenses)
                  _buildArbitrageAdvisorCard(summary: summary),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title:
                  const Text('More report options', style: AppType.bodyStrong),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Detailed record checks',
                      style: AppType.bodyStrong),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _reviewRecords,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackOverview(EvidenceReviewReport report) => Container(
        key: const ValueKey('accountant-pack-overview'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColor.surfaceNavy,
            borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text('YOUR ACCOUNTANT PACK',
                    style:
                        AppType.eyebrow.copyWith(color: AppColor.onNavyMuted))),
            const ExcludeSemantics(
                child: Icon(Icons.folder_copy_outlined,
                    color: AppColor.onNavyMuted, size: 32)),
          ]),
          const SizedBox(height: 20),
          Text(
              report.vehicle == null
                  ? 'Choose a vehicle.'
                  : report.hasRecords
                      ? 'Your vehicle records.\nOne clear handover.'
                      : 'No records in this period.',
              style: AppType.title.copyWith(
                  color: AppColor.onNavy,
                  fontSize: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? 22
                      : 28)),
          const SizedBox(height: 12),
          Text(
              report.vehicle == null
                  ? 'Select a vehicle to prepare its records for your accountant.'
                  : report.hasRecords
                      ? 'Prepare one ZIP with your report, spreadsheet and available receipts.'
                      : 'No records for this vehicle and financial year. Choose another scope or view your records.',
              style: AppType.secondary.copyWith(color: AppColor.onNavyMuted)),
          if (!report.hasRecords) ...[
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _viewRecords,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.onNavy,
                      minimumSize: const Size(48, 48)),
                  child: const Text('View records'),
                )),
          ],
          if (report.hasRecords) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColor.navyLine),
            const SizedBox(height: 16),
            Wrap(spacing: 24, runSpacing: 12, children: [
              Text(
                  '${report.trips.length} ${report.trips.length == 1 ? 'trip' : 'trips'}',
                  style: AppType.bodyStrong.copyWith(color: AppColor.onNavy)),
              Text(
                  '${report.expenses.length} ${report.expenses.length == 1 ? 'expense' : 'expenses'}',
                  style: AppType.bodyStrong.copyWith(color: AppColor.onNavy)),
            ]),
          ],
        ]),
      );

  Widget _buildPackContents({required bool hasRecords}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hasRecords ? 'Inside your pack' : 'Your pack will include',
              style: AppType.section),
          const SizedBox(height: 12),
          Material(
            color: AppColor.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColor.hairline)),
            child: Column(children: [
              _packFile(Icons.picture_as_pdf_outlined, 'Summary report',
                  'PDF · overview and review notes'),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColor.hairline),
              _packFile(Icons.table_chart_outlined, 'Detailed records',
                  'Excel · trips and expenses'),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColor.hairline),
              _packFile(Icons.receipt_long_outlined, 'Receipt files',
                  'Available attachments only'),
            ]),
          ),
        ],
      );

  Widget _packFile(IconData icon, String title, String detail) => ListTile(
        dense: true,
        minVerticalPadding: 8,
        minTileHeight: 64,
        leading: Icon(icon, color: AppColor.brand, size: 24),
        title: Text(title, style: AppType.bodyStrong),
        subtitle: Text(detail, style: AppType.secondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );

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
    final checksComplete = report.hasRecords &&
        !_checking &&
        !_checkFailed &&
        report.items.isEmpty;

    return Material(
      color: AppColor.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: checksComplete
              ? AppColor.positive.withValues(alpha: 0.5)
              : AppColor.hairline,
          width: checksComplete ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Evidence check', style: AppType.secondary),
                if (checksComplete)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppColor.positiveStrong,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Checks complete',
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
                  onPressed: () => _reviewRecords(),
                  child: Text(_checking || _checkFailed
                      ? 'Review records'
                      : report.items.isEmpty
                          ? 'Review records'
                          : 'Review ${report.items.length} ${report.items.length == 1 ? 'item' : 'items'}'),
                ),
              ),
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
                  const SizedBox(height: 16),
                  _statusRow(Icons.route_outlined, 'Trip details', tripCount,
                      'to review'),
                  _statusRow(
                      Icons.receipt_long_outlined,
                      'Receipts',
                      expenseCount,
                      _checking || _checkFailed
                          ? 'awaiting file check'
                          : 'to review',
                      unresolved: _checking || _checkFailed),
                  if (setupCount > 0)
                    _statusRow(Icons.directions_car_outlined,
                        'Vehicle & odometer', setupCount, 'to review'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recorded trip history',
                        style: AppType.bodyStrong),
                    subtitle: Text('${report.trips.length} drives recorded',
                        style: AppType.secondary),
                    trailing: TextButton(
                      onPressed: _viewRecords,
                      child: const Text('View'),
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
                    onTap: report.trips.isEmpty ? null : () => _reviewRecords(),
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
      onTap: () => _reviewRecords(),
    );
  }

  Widget _buildCompactTaxClaimStrip({
    required AtoTaxRule taxRule,
    required double businessKm,
    required double totalClaim,
    required bool isCpk,
    required Vehicle? primaryVehicle,
  }) {
    final rateCents = (taxRule.centsPerKmRate * 100).toInt();
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
              '${Formatters.distance(businessKm)} business recorded · Calculation limited to ${taxRule.centsPerKmMaxKm.toStringAsFixed(0)} km',
              style: AppType.secondary),
          if (businessKm >= taxRule.centsPerKmMaxKm)
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
