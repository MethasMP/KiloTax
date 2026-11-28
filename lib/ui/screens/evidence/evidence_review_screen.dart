import 'package:flutter/foundation.dart';
import '../../../data/models/vehicle_expense.dart';
import '../../../services/tax/ato_tax_period_engine.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../services/engine/evidence_review_service.dart';
import '../tax/tax_summary_screen.dart';
import '../../../data/models/trip.dart';
import '../../../services/evidence/evidence_auto_match_engine.dart';
import '../../../state/app_state.dart';
import '../cpk/cpk_trip_entry_screen.dart';
import '../expenses/expense_detail_screen.dart';
import 'scoped_odometer_review_screen.dart';
import '../logbook/logbook_trip_entry_screen.dart';
import '../workflow/workflow_trip_editor.dart';

class EvidenceReviewScreen extends StatefulWidget {
  final AppState appState;
  final String? vehicleId;
  final String financialYear;
  final VoidCallback? onOpenPack;
  final int allPendingRequest;
  final EvidenceReviewService evidenceService;

  const EvidenceReviewScreen({
    super.key,
    required this.appState,
    required this.vehicleId,
    required this.financialYear,
    this.onOpenPack,
    this.allPendingRequest = 0,
    this.evidenceService = const EvidenceReviewService(),
  });

  static Future<void> show(BuildContext context,
      {required AppState appState, String? vehicleId, String? financialYear}) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EvidenceReviewScreen(
        appState: appState,
        vehicleId: vehicleId ?? appState.primaryVehicle?.id,
        financialYear: financialYear ?? appState.activeTaxRule.financialYear,
      ),
    ));
  }

  @override
  State<EvidenceReviewScreen> createState() => _EvidenceReviewScreenState();
}

class _EvidenceReviewScreenState extends State<EvidenceReviewScreen> {
  Map<String, ReceiptFileInspection> _receiptFiles = const {};
  bool _inspecting = true;
  bool _checkFailed = false;
  bool _thisWeek = false;
  int _generation = 0;
  List<VehicleExpense> _inspectedExpenses = const [];
  String? _inspectedVehicleId;
  String? _inspectedYear;

  Vehicle? get _vehicle {
    for (final vehicle in widget.appState.vehicles) {
      if (vehicle.id == widget.vehicleId) return vehicle;
    }
    return null;
  }

  EvidenceReviewReport get _report => widget.evidenceService.evaluate(
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
  void didUpdateWidget(covariant EvidenceReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allPendingRequest != widget.allPendingRequest) {
      _thisWeek = false;
    }
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_refresh);
      widget.appState.addListener(_refresh);
    }
    if (oldWidget.appState != widget.appState ||
        oldWidget.vehicleId != widget.vehicleId ||
        oldWidget.financialYear != widget.financialYear ||
        oldWidget.evidenceService != widget.evidenceService) {
      _inspect();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    _generation++;
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final report = _report;
    if (_inspectedVehicleId != report.vehicle?.id ||
        _inspectedYear != report.financialYear ||
        !listEquals(_inspectedExpenses, report.expenses)) {
      _inspect();
    } else {
      setState(() {});
    }
  }

  Future<void> _inspect() async {
    final report = _report;
    _inspectedExpenses = List.of(report.expenses);
    _inspectedVehicleId = report.vehicle?.id;
    _inspectedYear = report.financialYear;
    final generation = ++_generation;
    setState(() {
      _receiptFiles = const {};
      _checkFailed = false;
      _inspecting = true;
    });
    try {
      final inspections =
          await widget.evidenceService.inspectReceipts(report.expenses);
      if (!mounted || generation != _generation) return;
      setState(() {
        _receiptFiles = inspections;
        _inspecting = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _checkFailed = true;
        _inspecting = false;
      });
    }
  }

  Future<void> _openItem(EvidenceReviewItem item) async {
    final appState = widget.appState;
    switch (item) {
      case TripReviewItem():
        final matching = _report.trips.where((trip) => trip.id == item.tripId);
        if (matching.isEmpty) return;
        await WorkflowTripEditor.show(context,
            trip: matching.first, appState: appState);
      case ExpenseReviewItem():
        final matching =
            _report.expenses.where((expense) => expense.id == item.expenseId);
        if (matching.isEmpty) return;
        await ExpenseDetailScreen.show(context,
            appState: appState, expense: matching.first);
      case OdometerReviewItem():
        await _openOdometer();
      case SetupReviewItem():
        if (item.reason == SetupReviewReason.openingOdometer) {
          await _openOdometer();
        } else if (item.reason == SetupReviewReason.noRecords &&
            _vehicle != null) {
          final period =
              AtoFinancialYear(int.parse(widget.financialYear.substring(0, 4)));
          final now = DateTime.now();
          final historical = !period.containsExpenseDate(now);
          final initialDate = historical ? period.startDate : now;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _vehicle!.taxMethod == TaxMethod.logbook
                ? LogbookTripEntryScreen(
                    appState: appState,
                    vehicleId: widget.vehicleId,
                    initialDate: initialDate,
                    requireDateConfirmation: historical)
                : CpkTripEntryScreen(
                    appState: appState,
                    vehicleId: widget.vehicleId,
                    initialDate: initialDate,
                    requireDateConfirmation: historical),
          ));
        }
    }
    if (mounted) _refresh();
  }

  Future<void> _openOdometer() async {
    if (_vehicle == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ScopedOdometerReviewScreen(
            appState: widget.appState,
            vehicleId: widget.vehicleId!,
            financialYear: widget.financialYear)));
  }

  void _openPack() {
    if (widget.onOpenPack != null) {
      widget.onOpenPack!();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TaxSummaryScreen(
            initialVehicleId: widget.vehicleId,
            initialFinancialYear: widget.financialYear)));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final visibleItems =
        _thisWeek ? report.itemsForWeek(DateTime.now()) : report.items;
    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(title: const Text('Review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(report.vehicle?.displayName ?? 'Your driving records',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'FY ${report.financialYear} · ${report.vehicle?.taxMethod == TaxMethod.logbook ? "12-Week Logbook" : "Cents per km"}'),
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
          ] else if (_checkFailed) ...[
            const Text(
                'Receipt files could not be checked. Your records are still available.'),
            TextButton(
                onPressed: _inspect, child: const Text('Retry receipt check')),
          ] else if (_thisWeek && visibleItems.isEmpty && !report.isComplete)
            const Text(
                'No pending trip or receipt checks this week. Check All pending for older records and odometer issues.')
          else if (report.isComplete && !_checkFailed)
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
          ..._contextualCards(report, visibleItems),
          if (_thisWeek && report.items.length > visibleItems.length)
            TextButton(
                onPressed: () => setState(() => _thisWeek = false),
                child: const Text('View all pending')),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openPack,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Open accountant pack'),
          ),
        ],
      ),
    );
  }

  List<Widget> _contextualCards(
      EvidenceReviewReport report, List<EvidenceReviewItem> items) {
    final widgets = <Widget>[];
    final grouped = <String>{};
    for (final trip in report.trips) {
      final linked = report.expenses
          .where((e) =>
              !grouped.contains(e.id) &&
              !e.category.isCarExpense &&
              trip.classification != TripClassification.personal &&
              e.linkedTripId == trip.id &&
              trip.linkedExpenseIds.contains(e.id))
          .toList();
      final tripItems = items
          .whereType<TripReviewItem>()
          .where((i) => i.tripId == trip.id)
          .toList();
      final expenseItems = items
          .whereType<ExpenseReviewItem>()
          .where((i) => linked.any((e) => e.id == i.expenseId))
          .toList();
      if (tripItems.isEmpty && expenseItems.isEmpty) continue;
      grouped.addAll(linked.map((e) => e.id));
      widgets.add(Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        trip.jobReference ??
                            trip.destinationAddress ??
                            Formatters.dateTime(trip.date),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${Formatters.dateTime(trip.date)} · ${trip.distanceKm.toStringAsFixed(1)} km'),
                    Text(trip.purpose.isEmpty
                        ? 'Purpose not added'
                        : trip.purpose),
                    for (final item in tripItems) _reviewTile(item, report),
                    for (final expense in linked) ...[
                      const Text('Related receipt'),
                      if (expense.category.isCarExpense)
                        const Text(
                            'Vehicle running cost. A trip link does not establish eligibility.'),
                      if (expenseItems.any((i) => i.expenseId == expense.id))
                        for (final item in expenseItems
                            .where((i) => i.expenseId == expense.id))
                          _reviewTile(item, report)
                      else
                        TextButton(
                            onPressed: () => ExpenseDetailScreen.show(context,
                                appState: widget.appState, expense: expense),
                            child: Text(
                                '${expense.category.displayName} · Open receipt (context)')),
                    ],
                  ]))));
    }
    for (final item in items) {
      if (item is TripReviewItem) continue;
      if (item is ExpenseReviewItem) {
        if (grouped.contains(item.expenseId)) continue;
        final expense =
            report.expenses.where((e) => e.id == item.expenseId).first;
        final suggestion = expense.linkedTripId == null
            ? EvidenceAutoMatchEngine.findBestMatchingTrip(
                expense: expense,
                candidateTrips: report.trips
                    .where((t) =>
                        !t.isDeleted &&
                        t.classification != TripClassification.personal)
                    .toList())
            : null;
        widgets.add(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _reviewTile(item, report),
          if (expense.linkedTripId != null ||
              report.trips
                  .any((trip) => trip.linkedExpenseIds.contains(expense.id)))
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'Existing link needs review. Open the receipt to inspect or unlink it.')),
          if (suggestion != null && suggestion.confidenceScore >= 0.80)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Possible related trip · ${Formatters.dateTime(suggestion.trip.date)}'),
                      Text('Optional suggestion. ${suggestion.matchReason}'),
                      TextButton(
                          onPressed: () => ExpenseDetailScreen.show(context,
                              appState: widget.appState,
                              expense: expense,
                              suggestedTripId: suggestion.trip.id,
                              suggestionReason: suggestion.matchReason),
                          child: const Text('Review match')),
                    ])),
        ]));
      } else {
        widgets.add(_reviewTile(item, report));
      }
    }
    return widgets;
  }

  Widget _reviewTile(EvidenceReviewItem item, EvidenceReviewReport report) {
    String title;
    IconData icon;
    bool enabled = true;
    switch (item) {
      case TripReviewItem():
        final trip =
            report.trips.where((trip) => trip.id == item.tripId).firstOrNull;
        if (trip == null) return const SizedBox.shrink();
        title = 'Trip · ${Formatters.dateTime(trip.date)}';
        icon = LucideIcons.route;
      case ExpenseReviewItem():
        final expense = report.expenses
            .where((expense) => expense.id == item.expenseId)
            .firstOrNull;
        if (expense == null) return const SizedBox.shrink();
        title =
            '${expense.category.displayName} · ${Formatters.currency(expense.amount)}';
        icon = LucideIcons.receipt;
      case OdometerReviewItem():
        title = 'Unexplained odometer travel';
        icon = LucideIcons.gauge;
      case SetupReviewItem():
        title = switch (item.reason) {
          SetupReviewReason.vehicle => 'Vehicle setup',
          SetupReviewReason.noRecords => 'Add driving records',
          SetupReviewReason.openingOdometer => 'Starting odometer',
        };
        enabled = item.reason != SetupReviewReason.vehicle;
        icon = LucideIcons.info;
    }
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(item.description),
        trailing: enabled ? const Icon(LucideIcons.chevronRight) : null,
        onTap: enabled ? () => _openItem(item) : null,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
