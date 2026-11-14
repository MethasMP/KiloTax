import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../../../services/engine/tax_pack_share_helper.dart';
import '../../../state/app_state.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../logbook/logbook_progress_screen.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import '../workflow/workflow_trip_editor.dart';

class EvidenceReviewScreen extends StatefulWidget {
  final AppState appState;
  final String? vehicleId;
  final String financialYear;

  const EvidenceReviewScreen({
    super.key,
    required this.appState,
    required this.vehicleId,
    required this.financialYear,
  });

  static Future<void> show(BuildContext context,
      {required AppState appState, String? vehicleId}) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EvidenceReviewScreen(
        appState: appState,
        vehicleId: vehicleId ?? appState.primaryVehicle?.id,
        financialYear: appState.activeTaxRule.financialYear,
      ),
    ));
  }

  @override
  State<EvidenceReviewScreen> createState() => _EvidenceReviewScreenState();
}

class _EvidenceReviewScreenState extends State<EvidenceReviewScreen> {
  final _service = const EvidenceReviewService();
  Map<String, ReceiptFileInspection> _receiptFiles = const {};
  bool _inspecting = true;
  bool _sharing = false;
  bool _thisWeek = false;
  int _generation = 0;

  Vehicle? get _vehicle {
    for (final vehicle in widget.appState.vehicles) {
      if (vehicle.id == widget.vehicleId) return vehicle;
    }
    return null;
  }

  EvidenceReviewReport get _report => _service.evaluate(
        vehicle: _vehicle,
        financialYear: widget.financialYear,
        trips: widget.appState.trips,
        expenses: widget.appState.expenses,
        receiptFiles: _receiptFiles,
        hasOdometerGaps: widget.vehicleId != null &&
            widget.appState
                .odometerGapsForVehicle(widget.vehicleId!)
                .isNotEmpty,
      );

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
    _inspect();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    _generation++;
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _receiptFiles = const {};
      _inspecting = true;
    });
    _inspect();
  }

  Future<void> _inspect() async {
    final generation = ++_generation;
    final inspections = await _service.inspectReceipts(_report.expenses);
    if (!mounted || generation != _generation) return;
    setState(() {
      _receiptFiles = inspections;
      _inspecting = false;
    });
  }

  Future<void> _openItem(EvidenceReviewItem item) async {
    final appState = widget.appState;
    switch (item) {
      case TripReviewItem():
        final matching = _report.trips.where((trip) => trip.id == item.tripId);
        if (matching.isEmpty) return;
        appState.selectVehicle(widget.vehicleId!);
        await WorkflowTripEditor.show(context,
            trip: matching.first, appState: appState);
      case ExpenseReviewItem():
        final matching =
            _report.expenses.where((expense) => expense.id == item.expenseId);
        if (matching.isEmpty) return;
        appState.selectVehicle(widget.vehicleId!);
        await ExpenseDetailScreen.show(context,
            appState: appState, expense: matching.first);
      case OdometerReviewItem():
        await _openOdometer();
      case SetupReviewItem():
        if (item.reason == SetupReviewReason.openingOdometer) {
          await _openOdometer();
        } else if (item.reason == SetupReviewReason.noRecords &&
            _vehicle != null) {
          appState.selectVehicle(_vehicle!.id);
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _vehicle!.taxMethod == TaxMethod.logbook
                ? LogbookTripEntryScreen(appState: appState)
                : CpkTripEntryScreen(appState: appState),
          ));
        }
    }
    if (mounted) _refresh();
  }

  Future<void> _openOdometer() async {
    if (_vehicle == null) return;
    widget.appState.selectVehicle(_vehicle!.id);
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LogbookProgressScreen()));
  }

  Future<void> _share() async {
    if (_sharing || _vehicle == null) return;
    setState(() => _sharing = true);
    widget.appState.selectVehicle(_vehicle!.id);
    try {
      await TaxPackShareHelper.shareTaxPack(context, widget.appState,
          allowDraftWithGaps: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final visibleItems =
        _thisWeek ? report.itemsForWeek(DateTime.now()) : report.items;
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(title: const Text('Review evidence')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(report.vehicle?.displayName ?? 'Your driving records',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('FY ${report.financialYear}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('All pending'),
                selected: !_thisWeek,
                onSelected: (_) => setState(() => _thisWeek = false)),
            ChoiceChip(
                label: const Text('This week'),
                selected: _thisWeek,
                onSelected: (_) => setState(() => _thisWeek = true)),
          ]),
          if (_thisWeek)
            Text(
                'Week of ${Formatters.dateTime(EvidenceReviewReport.weekStart(DateTime.now()))}. Other pending checks remain under All pending.'),
          const SizedBox(height: 20),
          if (_inspecting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Checking receipt files…'),
          ] else if (_thisWeek && visibleItems.isEmpty && !report.isComplete)
            const Text(
                'No pending trip or receipt checks this week. Check All pending for older records and odometer issues.')
          else if (report.isComplete)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No outstanding record checks. Your records are ready to share for review.'),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                int unclassifiedTrips = 0;
                int missingPurposeTrips = 0;
                int receiptIssues = 0;
                int odometerGaps = 0;

                for (final item in visibleItems) {
                  if (item is TripReviewItem) {
                    if (item.reasons
                        .contains(TripReviewReason.classification)) {
                      unclassifiedTrips++;
                    } else if (item.reasons
                        .contains(TripReviewReason.purpose)) {
                      missingPurposeTrips++;
                    }
                  } else if (item is ExpenseReviewItem) {
                    receiptIssues++;
                  } else if (item is OdometerReviewItem) {
                    odometerGaps++;
                  }
                }

                final digestParts = <String>[];
                if (unclassifiedTrips > 0) {
                  digestParts.add('$unclassifiedTrips unclassified trips');
                }
                if (missingPurposeTrips > 0) {
                  digestParts
                      .add('$missingPurposeTrips trips without a purpose');
                }
                if (receiptIssues > 0) {
                  digestParts.add('$receiptIssues receipts to review');
                }
                if (odometerGaps > 0) {
                  digestParts.add('$odometerGaps unexplained odometer gaps');
                }
                final digestSummary = digestParts.join(' · ');

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceSunken,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.listTodo,
                                size: 18, color: AppColors.amber),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${visibleItems.length} ${visibleItems.length == 1 ? "item needs" : "items need"} attention',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (digestSummary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          digestSummary,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          for (final item in visibleItems) _reviewTile(item, report),
          const SizedBox(height: 20),
          if (report.canExport)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _sharing ||
                      _inspecting ||
                      widget.financialYear !=
                          widget.appState.activeTaxRule.financialYear
                  ? null
                  : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(_sharing
                  ? 'Preparing records…'
                  : report.isComplete
                      ? 'Share records'
                      : 'Share draft records'),
            ),
        ],
      ),
    );
  }

  Widget _reviewTile(EvidenceReviewItem item, EvidenceReviewReport report) {
    String title;
    IconData icon;
    bool enabled = true;
    switch (item) {
      case TripReviewItem():
        final trip = report.trips.firstWhere((trip) => trip.id == item.tripId);
        title = 'Trip · ${Formatters.dateTime(trip.date)}';
        icon = Icons.route;
      case ExpenseReviewItem():
        final expense = report.expenses
            .firstWhere((expense) => expense.id == item.expenseId);
        title =
            '${expense.category.displayName} · ${Formatters.currency(expense.amount)}';
        icon = Icons.receipt_long;
      case OdometerReviewItem():
        title = 'Unexplained odometer travel';
        icon = Icons.speed;
      case SetupReviewItem():
        title = switch (item.reason) {
          SetupReviewReason.vehicle => 'Vehicle setup',
          SetupReviewReason.noRecords => 'Add driving records',
          SetupReviewReason.openingOdometer => 'Starting odometer',
        };
        enabled = item.reason != SetupReviewReason.vehicle;
        icon = Icons.info_outline;
    }
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(item.description),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: enabled ? () => _openItem(item) : null,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
